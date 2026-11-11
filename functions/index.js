'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const nodemailer = require('nodemailer');
const { createVerificationService, VerificationError } = require('./otp');

initializeApp();
const mailConfig = defineSecret('PAWPALS_MAIL_CONFIG');
let service;

function getService() {
  if (service) return service;
  const config = JSON.parse(mailConfig.value());
  if (!config.user || !config.password || !config.otpSecret || ![465, 587].includes(Number(config.port || 465))) {
    throw new Error('Invalid mail configuration.');
  }
  const transport = nodemailer.createTransport({
    host: config.host || 'smtp.gmail.com',
    port: Number(config.port || 465),
    secure: Number(config.port || 465) === 465,
    requireTLS: true,
    tls: { rejectUnauthorized: true },
    auth: { user: config.user, pass: config.password },
    connectionTimeout: 10000, greetingTimeout: 10000, socketTimeout: 15000,
    logger: false, debug: false,
  });
  service = createVerificationService({ db: getFirestore(), auth: getAuth(), hashKey: config.otpSecret,
    sendMail: async ({ to, code }) => {
      const result = await transport.sendMail({
        from: { name: 'PawPals', address: config.user }, to,
        subject: `${code} là mã xác nhận PawPals của bạn`,
        text: `Chào bạn,\n\nMã xác nhận PawPals: ${code}\n\nMã có hiệu lực trong 10 phút. Không chia sẻ mã này với bất kỳ ai.\nNếu bạn không yêu cầu, hãy bỏ qua email này.\n\nPawPals — Một người bạn. Trọn yêu thương.`,
        html: `<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:32px;background:#f8f9f5;color:#253d35;border-radius:24px"><h1 style="color:#427968">PawPals</h1><h2>Xác nhận email của bạn</h2><p>Nhập mã bên dưới để bắt đầu chăm sóc người bạn nhỏ.</p><div style="font-size:36px;font-weight:bold;letter-spacing:8px;background:#eaf2e9;padding:20px;text-align:center;border-radius:16px">${code}</div><p>Mã có hiệu lực trong <b>10 phút</b>. Không chia sẻ mã này với bất kỳ ai.</p><p style="color:#738078">Nếu bạn không yêu cầu, hãy bỏ qua email này.</p></div>`,
      });
      if (!result.accepted?.length) throw new Error('Mail was not accepted.');
    },
  });
  return service;
}

function callable(action) {
  return onCall({ region: 'asia-southeast1', secrets: [mailConfig],
    maxInstances: 5, timeoutSeconds: 60, memory: '256MiB' }, async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Bạn cần đăng nhập lại.');
    try {
      return await action(getService(), request);
    } catch (error) {
      if (error instanceof VerificationError) throw new HttpsError(error.code, error.message, error.details);
      // SMTP errors can contain credentials or recipient data. Never forward or log them.
      throw new HttpsError('unavailable', 'Dịch vụ xác nhận email đang bận. Vui lòng thử lại sau.');
    }
  });
}

exports.sendEmailVerificationCode = callable((otp, request) =>
  otp.requestCode(request.auth.uid, request.rawRequest.ip));
exports.verifyEmailVerificationCode = callable((otp, request) =>
  otp.verifyCode(request.auth.uid, request.data?.code));

Object.assign(exports, require('./momo_functions'));
