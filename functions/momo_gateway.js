'use strict';

const { createHmac, timingSafeEqual, randomUUID } = require('node:crypto');

class PaymentError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

const CREATE_FIELDS = ['accessKey', 'amount', 'extraData', 'ipnUrl', 'orderId',
  'orderInfo', 'partnerCode', 'redirectUrl', 'requestId', 'requestType'];
const IPN_FIELDS = ['accessKey', 'amount', 'extraData', 'message', 'orderId',
  'orderInfo', 'orderType', 'partnerCode', 'payType', 'requestId', 'responseTime',
  'resultCode', 'transId'];

function signature(secret, fields, data) {
  const raw = fields.map(key => {
    const value = data[key];
    if (!['string', 'number'].includes(typeof value) ||
        (typeof value === 'number' && !Number.isSafeInteger(value))) {
      throw new PaymentError('invalid-argument', 'Dữ liệu thanh toán không hợp lệ.');
    }
    return `${key}=${value}`;
  }).join('&');
  return createHmac('sha256', secret).update(raw, 'utf8').digest('hex');
}

function equalSignature(expected, supplied) {
  return typeof supplied === 'string' && /^[a-fA-F0-9]{64}$/.test(supplied) &&
    timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(supplied, 'hex'));
}

function validPayUrl(value, mode) {
  try {
    const uri = new URL(value);
    return uri.protocol === 'https:' && !uri.username && !uri.password &&
      (!uri.port || uri.port === '443') &&
      uri.hostname === (mode === 'production' ? 'payment.momo.vn' : 'test-payment.momo.vn');
  } catch (_) { return false; }
}

function createMomoGateway(config, { fetchImpl = fetch } = {}) {
  if (!config || !['sandbox', 'production'].includes(config.mode) ||
      !/^[A-Za-z0-9_-]{3,50}$/.test(config.partnerCode || '') ||
      typeof config.accessKey !== 'string' || !config.accessKey ||
      typeof config.secretKey !== 'string' || config.secretKey.length < 16) {
    throw new PaymentError('failed-precondition', 'Thanh toán MoMo chưa được cấu hình. Vui lòng chọn COD hoặc liên hệ cửa hàng.');
  }
  for (const field of ['ipnUrl', 'redirectUrl']) {
    let url;
    try { url = new URL(config[field]); } catch (_) { /* Invalid config. */ }
    if (!url || url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
      throw new PaymentError('failed-precondition', 'Địa chỉ nhận kết quả MoMo chưa hợp lệ.');
    }
  }
  const endpoint = config.mode === 'production'
    ? 'https://payment.momo.vn/v2/gateway/api/'
    : 'https://test-payment.momo.vn/v2/gateway/api/';
  async function post(path, body) {
    try {
      const response = await fetchImpl(endpoint + path, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body), signal: AbortSignal.timeout(35000), redirect: 'error',
      });
      if (!response.ok) throw new Error('Gateway unavailable');
      const result = await response.json();
      if (!result || !Number.isInteger(result.resultCode)) throw new Error('Invalid response');
      return result;
    } catch (_) {
      // Fetch errors and gateway messages can contain private configuration.
      throw new PaymentError('unavailable', 'Chưa nhận được kết quả từ MoMo. Đơn hàng vẫn được giữ để kiểm tra lại.');
    }
  }
  return {
    mode: config.mode,
    partnerCode: config.partnerCode,
    async create(session) {
      const data = { partnerCode: config.partnerCode, requestId: session.requestId,
        orderId: session.orderId, amount: session.amount, orderInfo: session.orderInfo,
        redirectUrl: config.redirectUrl, ipnUrl: config.ipnUrl, extraData: '',
        requestType: 'captureWallet', autoCapture: true, lang: 'vi' };
      data.signature = signature(config.secretKey, CREATE_FIELDS, { ...data, accessKey: config.accessKey });
      const result = await post('create', data);
      if (result.resultCode !== 0) {
        // Only explicit request rejections prove that no payment was created.
        const definitive = [11, 12, 13, 20, 21, 22, 47, 98].includes(result.resultCode);
        throw new PaymentError('unavailable', 'MoMo chưa tạo được trang thanh toán. Vui lòng thử lại.',
          { definitive, resultCode: result.resultCode });
      }
      if (result.partnerCode !== config.partnerCode || result.orderId !== session.orderId ||
          result.requestId !== session.requestId || Number(result.amount) !== session.amount ||
          !validPayUrl(result.payUrl, config.mode)) {
        throw new PaymentError('unavailable', 'Chưa xác minh được trang thanh toán MoMo. Vui lòng kiểm tra lại đơn hàng.');
      }
      if (result.signature) {
        const expected = signature(config.secretKey,
          ['accessKey', 'amount', 'orderId', 'partnerCode', 'payUrl', 'requestId', 'responseTime', 'resultCode'],
          { ...result, accessKey: config.accessKey });
        if (!equalSignature(expected, result.signature)) {
          throw new PaymentError('unavailable', 'Chữ ký trang thanh toán MoMo không hợp lệ.');
        }
      }
      return result.payUrl;
    },
    verifyNotification(body) {
      if (!body || typeof body !== 'object' || Array.isArray(body) ||
          JSON.stringify(body).length > 16000 || body.partnerCode !== config.partnerCode) {
        throw new PaymentError('permission-denied', 'Thông báo MoMo không hợp lệ.');
      }
      const expected = signature(config.secretKey, IPN_FIELDS, { ...body, accessKey: config.accessKey });
      if (!equalSignature(expected, body.signature)) {
        throw new PaymentError('permission-denied', 'Chữ ký MoMo không hợp lệ.');
      }
      return body;
    },
    async query(session) {
      const data = { partnerCode: config.partnerCode, orderId: session.orderId,
        requestId: randomUUID(), lang: 'vi' };
      data.signature = signature(config.secretKey, ['accessKey', 'orderId', 'partnerCode'],
        { ...data, accessKey: config.accessKey });
      // The query API response is authenticated by TLS; MoMo does not specify a response signature.
      const result = await post('query', data);
      if (result.partnerCode !== config.partnerCode || result.orderId !== session.orderId ||
          result.requestId !== data.requestId) {
        throw new PaymentError('unavailable', 'Chưa xác minh được trạng thái MoMo. Vui lòng thử lại sau.');
      }
      if (result.resultCode === 42) {
        throw new PaymentError('not-found', 'MoMo chưa ghi nhận phiên thanh toán này.');
      }
      if (Number(result.amount) !== session.amount) {
        throw new PaymentError('unavailable', 'Số tiền MoMo không khớp đơn hàng.');
      }
      return result;
    },
  };
}

module.exports = { createMomoGateway, PaymentError, signature, equalSignature,
  CREATE_FIELDS, IPN_FIELDS, validPayUrl };
