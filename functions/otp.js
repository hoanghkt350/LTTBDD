'use strict';

const { createHmac, randomInt, randomBytes, timingSafeEqual } = require('node:crypto');

const CODE_TTL_MS = 10 * 60 * 1000;
const RESEND_MS = 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const MAX_ATTEMPTS = 5;

class VerificationError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

// All reads and counters are server-side. No code is returned to the app or logged.
function createVerificationService({ db, auth, sendMail, hashKey,
  now = Date.now, makeCode = () => String(randomInt(0, 1000000)).padStart(6, '0'),
  makeNonce = () => randomBytes(24).toString('hex') }) {
  if (typeof hashKey !== 'string' || hashKey.length < 32) throw new Error('Invalid OTP hash key.');
  const hash = value => createHmac('sha256', hashKey).update(value).digest('hex');
  const digest = (uid, email, nonce, code) => hash(JSON.stringify([uid, email, nonce, code]));
  async function account(uid) {
    if (!uid) throw new VerificationError('unauthenticated', 'Bạn cần đăng nhập lại.');
    const user = await auth.getUser(uid);
    if (user.disabled || !user.email) {
      throw new VerificationError('permission-denied', 'Tài khoản không hợp lệ.');
    }
    return user;
  }
  const receipt = data => ({ expiresAt: data.expiresAt, resendAt: data.resendAt });

  async function requestCode(uid, ip) {
    const user = await account(uid);
    if (user.emailVerified) return { verified: true };
    const email = user.email.toLowerCase();
    const time = now(), code = makeCode(), nonce = makeNonce();
    const ref = db.collection('emailVerificationChallenges').doc(uid);
    // The email budget survives account deletion/recreation. IPs are stored as HMACs.
    const limits = [
      { ref: db.collection('emailVerificationRateLimits').doc('email-' + hash(email)), max: 5 },
      { ref: db.collection('emailVerificationRateLimits').doc('ip-' + hash(ip || 'unknown')), max: 20 },
    ];
    const challenge = { email, nonce, codeHash: digest(uid, email, nonce, code),
      expiresAt: time + CODE_TTL_MS, resendAt: time + RESEND_MS,
      attempts: 0, status: 'sending' };
    await db.runTransaction(async tx => {
      const current = (await tx.get(ref)).data();
      const snapshots = await Promise.all(limits.map(limit => tx.get(limit.ref)));
      if (current && current.resendAt > time) {
        throw new VerificationError('resource-exhausted', 'Vui lòng chờ trước khi gửi lại mã.', receipt(current));
      }
      const budgets = snapshots.map(snapshot => {
        const data = snapshot.data();
        return data && data.windowEndsAt > time ? data : { count: 0, windowEndsAt: time + HOUR_MS };
      });
      for (let i = 0; i < limits.length; i++) {
        if (budgets[i].count >= limits[i].max) {
          throw new VerificationError('resource-exhausted', 'Đã đạt giới hạn gửi mã. Vui lòng thử lại sau.',
            { resendAt: budgets[i].windowEndsAt });
        }
      }
      tx.set(ref, challenge);
      limits.forEach((limit, i) => tx.set(limit.ref, { ...budgets[i], count: budgets[i].count + 1 }));
    });
    try {
      // Recipient comes only from Firebase Auth, never from client input.
      await sendMail({ to: user.email, code });
    } catch (_) {
      await db.runTransaction(async tx => {
        const saved = (await tx.get(ref)).data();
        if (saved?.nonce === nonce) tx.set(ref, { ...saved, codeHash: '', status: 'failed' });
      });
      throw new VerificationError('unavailable', 'Chưa gửi được email. Vui lòng thử lại sau một phút.', receipt(challenge));
    }
    await db.runTransaction(async tx => {
      const saved = (await tx.get(ref)).data();
      if (saved?.nonce === nonce) tx.set(ref, { ...saved, status: 'ready' });
    });
    return receipt(challenge);
  }

  async function verifyCode(uid, code) {
    const user = await account(uid);
    if (user.emailVerified) return { verified: true };
    if (typeof code !== 'string' || !/^\d{6}$/.test(code)) {
      throw new VerificationError('invalid-argument', 'Mã xác nhận gồm 6 chữ số.');
    }
    const ref = db.collection('emailVerificationChallenges').doc(uid);
    const email = user.email.toLowerCase();
    const result = await db.runTransaction(async tx => {
      const data = (await tx.get(ref)).data();
      if (!data || data.email !== email || data.expiresAt <= now()) {
        return { error: 'Mã đã hết hạn. Vui lòng gửi mã mới.' };
      }
      if (data.attempts >= MAX_ATTEMPTS) return { error: 'Bạn đã nhập sai 5 lần. Vui lòng gửi mã mới.' };
      if (data.status !== 'ready') return { error: 'Mã chưa sẵn sàng hoặc đã sử dụng. Vui lòng gửi mã mới.' };
      const actual = Buffer.from(digest(uid, email, data.nonce, code), 'hex');
      const expected = Buffer.from(data.codeHash, 'hex');
      if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
        // Return the error AFTER committing; throwing here would roll back the counter.
        const attempts = data.attempts + 1;
        tx.set(ref, { ...data, attempts });
        return { error: attempts >= MAX_ATTEMPTS
          ? 'Bạn đã nhập sai 5 lần. Vui lòng gửi mã mới.'
          : `Mã không đúng. Bạn còn ${MAX_ATTEMPTS - attempts} lần thử.` };
      }
      tx.set(ref, { ...data, status: 'consumed' });
      return { nonce: data.nonce };
    });
    if (result.error) throw new VerificationError('failed-precondition', result.error);
    try {
      // Recheck the primary email immediately before changing verification status.
      const current = await account(uid);
      if (current.email.toLowerCase() !== email) {
        throw new VerificationError('failed-precondition', 'Email đã thay đổi. Vui lòng gửi mã mới.');
      }
      // Set the verified email atomically with its flag, so a concurrent email
      // change cannot attach this code's proof to a different address.
      await auth.updateUser(uid, { email: current.email, emailVerified: true });
    } catch (error) {
      await db.runTransaction(async tx => {
        const saved = (await tx.get(ref)).data();
        if (saved?.nonce === result.nonce && saved.status === 'consumed') {
          tx.set(ref, { ...saved, status: 'ready' });
        }
      });
      throw error;
    }
    await db.runTransaction(async tx => {
      const saved = (await tx.get(ref)).data();
      if (saved?.nonce === result.nonce) tx.set(ref, { ...saved, codeHash: '', status: 'consumed' });
    });
    return { verified: true };
  }
  return { requestCode, verifyCode };
}

module.exports = { createVerificationService, VerificationError };
