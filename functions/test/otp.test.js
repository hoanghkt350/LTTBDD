'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createVerificationService } = require('../otp');

// Serialize transactions and commit only on success, like Firestore.
class MemoryStore {
  data = new Map();
  queue = Promise.resolve();
  collection(name) { return { doc: id => ({ path: `${name}/${id}` }) }; }
  runTransaction(action) {
    const pending = this.queue.then(async () => {
      const data = structuredClone(this.data);
      const result = await action({
        get: async ref => ({ data: () => structuredClone(data.get(ref.path)) }),
        set: (ref, value) => data.set(ref.path, structuredClone(value)),
      });
      this.data = data;
      return result;
    });
    this.queue = pending.catch(() => {});
    return pending;
  }
}
function fixture() {
  let clock = 1000000, codeNumber = 123456;
  const db = new MemoryStore(), messages = [], updates = [];
  const users = new Map(['alice', 'bob'].map(uid => [uid, { uid, email: uid + '@gmail.com', emailVerified: false }]));
  let mailFails = false, authFails = false;
  const auth = {
    getUser: async uid => structuredClone(users.get(uid)),
    updateUser: async (uid, change) => {
      if (authFails) throw new Error('Auth temporarily unavailable');
      updates.push({ uid, ...change });
      users.set(uid, { ...users.get(uid), ...change });
    },
  };
  const otp = createVerificationService({ db, auth, hashKey: 'test-key-must-be-at-least-32-characters-long',
    now: () => clock, makeCode: () => String(codeNumber++),
    sendMail: async message => {
      if (mailFails) throw new Error('SMTP credentials must not escape');
      messages.push(message);
    },
  });
  return { db, otp, messages, updates, users,
    advance: ms => { clock += ms; },
    failMail: () => { mailFails = true; },
    failAuth: value => { authFails = value; },
  };
}
const rejectsCode = (promise, code) => assert.rejects(promise, error => error.code === code);

test('sends to the Auth email, stores only an HMAC and returns no code', async () => {
  const f = fixture();
  const delivery = await f.otp.requestCode('alice', '127.0.0.1');
  assert.deepEqual(f.messages, [{ to:'alice@gmail.com', code:'123456' }]);
  assert.deepEqual(Object.keys(delivery).sort(), ['expiresAt', 'resendAt']);
  const challenge = f.db.data.get('emailVerificationChallenges/alice');
  assert.match(challenge.codeHash, /^[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(challenge).includes('123456'), false);
  assert.equal(challenge.status, 'ready');
  await f.otp.verifyCode('alice', '123456');
  assert.deepEqual(f.updates, [{ uid:'alice', email:'alice@gmail.com', emailVerified:true }]);
  assert.equal(f.db.data.get('emailVerificationChallenges/alice').codeHash, '');
  await f.otp.verifyCode('alice', '123456'); // Successful retries are idempotent.
  assert.equal(f.updates.length, 1);
});
test('requires a signed-in, enabled account', async () => {
  const f = fixture();
  await rejectsCode(f.otp.requestCode(null, 'ip'), 'unauthenticated');
  f.users.get('alice').disabled = true;
  await rejectsCode(f.otp.requestCode('alice', 'ip'), 'permission-denied');
  assert.equal(f.messages.length, 0);
});
test('concurrent sends allow one email and enforce the server cooldown', async () => {
  const f = fixture();
  const results = await Promise.allSettled(Array.from({length:5}, () => f.otp.requestCode('alice', 'ip')));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(f.messages.length, 1);
  f.advance(59999);
  await rejectsCode(f.otp.requestCode('alice', 'ip'), 'resource-exhausted');
  f.advance(1);
  await f.otp.requestCode('alice', 'ip');
  assert.equal(f.messages.length, 2);
});
test('five wrong codes commit five attempts and reject even the correct code', async () => {
  const f = fixture();
  await f.otp.requestCode('alice', 'ip');
  for (let i = 0; i < 5; i++) await rejectsCode(f.otp.verifyCode('alice', '000000'), 'failed-precondition');
  assert.equal(f.db.data.get('emailVerificationChallenges/alice').attempts, 5);
  await rejectsCode(f.otp.verifyCode('alice', '123456'), 'failed-precondition');
  assert.equal(f.updates.length, 0);
});
test('concurrent incorrect submissions cannot lose attempt increments', async () => {
  const f = fixture();
  await f.otp.requestCode('alice', 'ip');
  await Promise.allSettled(Array.from({length:12}, () => f.otp.verifyCode('alice', '000000')));
  assert.equal(f.db.data.get('emailVerificationChallenges/alice').attempts, 5);
  await rejectsCode(f.otp.verifyCode('alice', '123456'), 'failed-precondition');
});
test('expired codes and codes from another account are rejected', async () => {
  const f = fixture();
  await f.otp.requestCode('alice', 'ip');
  await rejectsCode(f.otp.verifyCode('bob', '123456'), 'failed-precondition');
  f.advance(600000);
  await rejectsCode(f.otp.verifyCode('alice', '123456'), 'failed-precondition');
  assert.equal(f.updates.length, 0);
});
test('resending invalidates the previous code', async () => {
  const f = fixture();
  await f.otp.requestCode('alice', 'ip');
  f.advance(60000);
  await f.otp.requestCode('alice', 'ip');
  await rejectsCode(f.otp.verifyCode('alice', '123456'), 'failed-precondition');
  await f.otp.verifyCode('alice', f.messages[1].code);
  assert.equal(f.updates.length, 1);
});
test('an email change cannot be verified using the previous email code', async () => {
  const f = fixture();
  await f.otp.requestCode('alice', 'ip');
  f.users.get('alice').email = 'other@gmail.com';
  await rejectsCode(f.otp.verifyCode('alice', '123456'), 'failed-precondition');
});
test('SMTP failure cannot produce a usable code or leak credentials', async () => {
  const f = fixture();
  f.failMail();
  await assert.rejects(f.otp.requestCode('alice', 'ip'), error =>
    error.code === 'unavailable' && !error.message.includes('credentials') && error.details.resendAt > 0);
  assert.equal(f.db.data.get('emailVerificationChallenges/alice').codeHash, '');
  await rejectsCode(f.otp.verifyCode('alice', '123456'), 'failed-precondition');
});
test('hourly email budget survives account replacement and resets after an hour', async () => {
  const f = fixture();
  for (let i = 0; i < 5; i++) {
    await f.otp.requestCode('alice', 'ip');
    f.advance(60000);
  }
  await rejectsCode(f.otp.requestCode('alice', 'ip'), 'resource-exhausted');
  f.users.get('bob').email = 'alice@gmail.com';
  await rejectsCode(f.otp.requestCode('bob', 'different-ip'), 'resource-exhausted');
  f.advance(3600000);
  await f.otp.requestCode('bob', 'different-ip');
});
test('IP budget limits mass account signups', async () => {
  const f = fixture();
  for (let i = 0; i < 21; i++) f.users.set('u'+i, {uid:'u'+i,email:`u${i}@gmail.com`,emailVerified:false});
  for (let i = 0; i < 20; i++) await f.otp.requestCode('u'+i, 'same-ip');
  await rejectsCode(f.otp.requestCode('u20', 'same-ip'), 'resource-exhausted');
  await f.otp.requestCode('u20', 'another-ip');
});
test('Auth update failure permits retry without accepting a new code', async () => {
  const f = fixture();
  await f.otp.requestCode('alice', 'ip');
  f.failAuth(true);
  await assert.rejects(f.otp.verifyCode('alice', '123456'));
  f.failAuth(false);
  await f.otp.verifyCode('alice', '123456');
  assert.equal(f.updates.length, 1);
});
test('malformed codes cannot trigger verification', async () => {
  const f = fixture();
  await f.otp.requestCode('alice', 'ip');
  for (const code of [123456, null, {}, '12345', '1234567', 'abcdef']) {
    await rejectsCode(f.otp.verifyCode('alice', code), 'invalid-argument');
  }
  assert.equal(f.updates.length, 0);
});
