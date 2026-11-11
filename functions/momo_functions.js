'use strict';

const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { createMomoGateway, PaymentError } = require('./momo_gateway');
const { createPaymentService } = require('./payments');

const configSecret = defineSecret('PAWPALS_MOMO_CONFIG');
const options = { region: 'asia-southeast1', secrets: [configSecret],
  maxInstances: 5, timeoutSeconds: 120, memory: '256MiB' };
let service;
function getService() {
  if (service) return service;
  let config;
  try { config = JSON.parse(configSecret.value()); } catch (_) {
    throw new PaymentError('failed-precondition', 'Thanh toán MoMo chưa được cấu hình. Vui lòng chọn COD.');
  }
  const project = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  if (!project) throw new PaymentError('failed-precondition', 'Chưa xác định được máy chủ thanh toán.');
  const base = `https://asia-southeast1-${project}.cloudfunctions.net/`;
  const gateway = createMomoGateway({ ...config, ipnUrl: base + 'momoIpn', redirectUrl: base + 'momoReturn' });
  service = createPaymentService({ db: getFirestore(), auth: getAuth(), gateway,
    timestamp: () => FieldValue.serverTimestamp() });
  return service;
}

function callable(action) {
  return onCall(options, async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Bạn cần đăng nhập lại.');
    try {
      return await action(getService(), request);
    } catch (error) {
      if (error instanceof PaymentError) throw new HttpsError(error.code, error.message);
      throw new HttpsError('unavailable', 'Chưa kết nối được dịch vụ MoMo. Hãy kiểm tra lịch sử đơn hàng trước khi thử lại.');
    }
  });
}

exports.createMomoPayment = callable((payments, request) =>
  payments.create(request.auth.uid, request.data?.orderId, request.data?.checkout));
exports.checkMomoPayment = callable((payments, request) =>
  payments.refresh(request.auth.uid, request.data?.orderId));

exports.momoIpn = onRequest({ ...options, timeoutSeconds: 15, invoker: 'public' }, async (request, response) => {
  response.set('Cache-Control', 'no-store');
  if (request.method !== 'POST') return response.status(405).send('Method not allowed');
  if (!request.is('application/json')) return response.status(415).send('JSON required');
  try {
    await getService().notify(request.body);
    return response.status(204).send();
  } catch (error) {
    const status = error instanceof PaymentError
      ? ({ 'permission-denied': 403, 'invalid-argument': 400, 'not-found': 404 }[error.code] || 503) : 503;
    // Never acknowledge an invalid signature or an uncommitted stock update.
    return response.status(status).send('Payment notification could not be confirmed');
  }
});

exports.reconcileMomoPayments = onSchedule({ ...options, timeoutSeconds: 300,
  schedule: 'every 5 minutes', timeZone: 'Asia/Ho_Chi_Minh', maxInstances: 1 },
async () => { await getService().reconcilePending(); });

// The browser return is informational. Its query parameters cannot mark an order paid.
exports.momoReturn = onRequest({ region: 'asia-southeast1', maxInstances: 3,
  invoker: 'public' }, (request, response) => {
  response.set({ 'Cache-Control': 'no-store', 'Content-Type': 'text/html; charset=utf-8',
    'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
    'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' });
  response.send('<!doctype html><html lang="vi"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Thanh toán PawPals</title><style>body{font-family:system-ui,sans-serif;background:#f8f9f5;color:#253d35;padding:32px;max-width:480px;margin:48px auto;line-height:1.6}a{display:inline-block;background:#427968;color:white;padding:12px 20px;border-radius:12px;text-decoration:none}</style><h1>Quay lại PawPals</h1><p>Kết quả thanh toán được xác minh trực tiếp với MoMo. Mở ứng dụng để xem trạng thái đơn hàng.</p><a href="pawpals://payments">Mở PawPals</a><p>Nếu nút không mở được ứng dụng, hãy quay lại PawPals và chọn Đơn hàng của tôi.</p></html>');
});
