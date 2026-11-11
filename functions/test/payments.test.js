'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const { createMomoGateway, signature, CREATE_FIELDS, PaymentError } = require('../momo_gateway');
const { createPaymentService } = require('../payments');

// Commit transactions atomically and reject reads after writes, as Firestore does.
class MemoryStore {
  data = new Map();
  queue = Promise.resolve();
  collection(name) {
    const store = this;
    return {
      doc(id) {
        const ref = { path: `${name}/${id}` };
        ref.get = async () => ({ data: () => structuredClone(store.data.get(ref.path)) });
        ref.update = change => store.runTransaction(async tx => {
          await tx.get(ref);
          tx.update(ref, change);
        });
        return ref;
      },
      where(field, op, value) {
        assert.equal(op, '<=');
        return { limit: count => ({ get: async () => ({ docs: [...store.data]
          .filter(([path, data]) => path.startsWith(name + '/') && data[field] <= value)
          .slice(0, count).map(([path, data]) => ({ id: path.split('/')[1], data: () => structuredClone(data) })) }) }) };
      },
    };
  }
  runTransaction(action) {
    const pending = this.queue.then(async () => {
      const data = structuredClone(this.data);
      let writing = false;
      const result = await action({
        get: async ref => {
          assert.equal(writing, false, 'Firestore requires all reads before writes');
          return { data: () => structuredClone(data.get(ref.path)) };
        },
        set: (ref, value) => { writing = true; data.set(ref.path, structuredClone(value)); },
        update: (ref, change) => {
          writing = true;
          assert.ok(data.has(ref.path), 'Cannot update a missing document');
          data.set(ref.path, { ...data.get(ref.path), ...structuredClone(change) });
        },
      });
      this.data = data;
      return result;
    });
    this.queue = pending.catch(() => {});
    return pending;
  }
}

const config = { mode: 'production', partnerCode: 'PAWPALS_TEST_PARTNER',
  accessKey: 'test-access-key', secretKey: 'fixture-secret-key-never-use-in-production',
  ipnUrl: 'https://merchant.example/momoIpn', redirectUrl: 'https://merchant.example/momoReturn' };
const input = () => ({ quantities: { p1: 1 }, prices: { p1: 100000 }, voucher: '',
  recipient: { name: 'Buyer', phone: '0901234567', address: '123 Example Street' } });
const rejectsCode = (promise, code) => assert.rejects(promise, error => error.code === code);

function fixture(mode = 'production') {
  let clock = 1000000, createError = false, queryError = false, createCode = 0, queryCode = 1000;
  const db = new MemoryStore(), requests = [];
  db.data.set('products/p1', { name: 'Pet food', price: 100000, imageUrl: '', stock: 10, isActive: true });
  const users = { alice: { emailVerified: true }, bob: { emailVerified: true } };
  const gateway = createMomoGateway({ ...config, mode }, { fetchImpl: async (url, options) => {
    const body = JSON.parse(options.body);
    requests.push({ url, body });
    if ((url.endsWith('/create') && createError) || (url.endsWith('/query') && queryError)) {
      throw new Error('Simulated timeout containing private credentials');
    }
    const code = url.endsWith('/create') ? createCode : queryCode;
    const session = db.data.get(`payment_sessions/${body.orderId}`);
    return { ok: true, json: async () => ({ partnerCode: config.partnerCode,
      requestId: body.requestId, orderId: body.orderId, amount: session.amount,
      resultCode: code, transId: 123456789, responseTime: clock, extraData: '',
      payUrl: `https://${mode === 'production' ? 'payment' : 'test-payment'}.momo.vn/v2/gateway/pay?t=fixture` }) };
  } });
  const payments = createPaymentService({ db, gateway, auth: { getUser: async uid => users[uid] },
    timestamp: () => clock, now: () => clock });
  function notification(id = 'order-0001', code = 0, changes = {}) {
    const session = db.data.get(`payment_sessions/${id}`);
    const body = { partnerCode: config.partnerCode, orderId: id, requestId: id,
      amount: session.amount, orderInfo: session.orderInfo, orderType: 'momo_wallet',
      transId: 123456789, resultCode: code, message: 'Gateway result', payType: 'qr',
      responseTime: clock, extraData: '', ...changes };
    // Construct the documented canonical string independently of the implementation.
    const raw = `accessKey=${config.accessKey}&amount=${body.amount}&extraData=${body.extraData}` +
      `&message=${body.message}&orderId=${body.orderId}&orderInfo=${body.orderInfo}&orderType=${body.orderType}` +
      `&partnerCode=${body.partnerCode}&payType=${body.payType}&requestId=${body.requestId}` +
      `&responseTime=${body.responseTime}&resultCode=${body.resultCode}&transId=${body.transId}`;
    body.signature = createHmac('sha256', config.secretKey).update(raw).digest('hex');
    return body;
  }
  return { db, payments, users, requests, notification,
    stock: () => db.data.get('products/p1').stock,
    order: (id = 'order-0001') => db.data.get(`orders/${id}`),
    advance: ms => { clock += ms; }, failCreate: () => { createError = true; },
    recoverCreate: () => { createError = false; },
    failQuery: () => { queryError = true; }, setCreateCode: code => { createCode = code; },
    setQueryCode: code => { queryCode = code; } };
}

test('creation signs the documented field order and targets only the configured MoMo host', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  const { body, url } = f.requests[0];
  assert.equal(url, 'https://payment.momo.vn/v2/gateway/api/create');
  const raw = `accessKey=${config.accessKey}&amount=125000&extraData=&ipnUrl=${config.ipnUrl}` +
    `&orderId=order-0001&orderInfo=PawPals - Thanh toan don order-0001&partnerCode=${config.partnerCode}` +
    `&redirectUrl=${config.redirectUrl}&requestId=order-0001&requestType=captureWallet`;
  assert.equal(body.signature, createHmac('sha256', config.secretKey).update(raw).digest('hex'));
  assert.equal(body.autoCapture, true);
});

test('server computes the total, reserves stock once and keeps retries on the same payment', async () => {
  const f = fixture();
  const data = { ...input(), voucher: 'PAWPALS10', totalAmount: 1, paymentStatus: 'paid' };
  const sessions = await Promise.all(Array.from({ length: 4 }, () => f.payments.create('alice', 'order-0001', data)));
  assert.equal(f.stock(), 9);
  assert.equal(f.order().totalAmount, 115000);
  assert.equal(f.order().paymentStatus, 'pending');
  assert.equal(f.order().status, 'Chờ thanh toán');
  assert.equal(f.requests.filter(r => r.url.endsWith('/create')).length, 1);
  assert.ok(sessions.every(s => s.orderId === 'order-0001'));
  assert.ok((await f.payments.create('alice', 'order-0001')).paymentUrl);
});

test('disabled and anonymous accounts cannot reserve inventory', async () => {
  const f = fixture();
  await rejectsCode(f.payments.create(null, 'order-0001', input()), 'unauthenticated');
  f.users.alice.disabled = true;
  await rejectsCode(f.payments.create('alice', 'order-0001', input()), 'permission-denied');
  assert.equal(f.stock(), 10);
});

test('email accounts can reserve inventory without an OTP verification step', async () => {
  const f = fixture();
  f.users.alice.emailVerified = false;
  await f.payments.create('alice', 'order-unverified', input());
  assert.equal(f.stock(), 9);
});

test('invalid quantities, vouchers, addresses and changed prices never create an order', async () => {
  const f = fixture();
  for (const change of [{ quantities: { p1: -1 } }, { quantities: { p1: 1.5 } },
    { quantities: {} }, { voucher: 'FREE100' }, { recipient: { ...input().recipient, address: '' } }]) {
    await rejectsCode(f.payments.create('alice', 'order-0001', { ...input(), ...change }), 'invalid-argument');
  }
  await rejectsCode(f.payments.create('alice', 'order-0001', { ...input(), prices: { p1: 1 } }), 'failed-precondition');
  assert.equal(f.stock(), 10);
  assert.equal(f.order(), undefined);
});

test('concurrent buyers cannot both reserve the last item', async () => {
  const f = fixture();
  f.db.data.get('products/p1').stock = 1;
  const result = await Promise.allSettled([
    f.payments.create('alice', 'order-0001', input()), f.payments.create('bob', 'order-0002', input()),
  ]);
  assert.equal(result.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(f.stock(), 0);
});

test('unusual product document IDs cannot alter the items prototype or lose stock on cancellation', async () => {
  const f = fixture();
  f.db.data.set('products/__proto__', {name:'Pet toy',imageUrl:'',price:100000,stock:2,isActive:true});
  const data = {...input(), quantities:JSON.parse('{"__proto__":1}'), prices:JSON.parse('{"__proto__":100000}')};
  await f.payments.create('alice','order-0001',data);
  assert.deepEqual(Object.keys(f.order().items),['__proto__']);
  assert.equal(f.db.data.get('products/__proto__').stock,1);
  await f.payments.notify(f.notification('order-0001',1006));
  assert.equal(f.db.data.get('products/__proto__').stock,2);
});

test('forged signatures and signed amount or identity mismatches cannot mark an order paid', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  await rejectsCode(f.payments.notify({ ...f.notification(), signature: '0'.repeat(64) }), 'permission-denied');
  for (const change of [{ amount: 1 }, { requestId: 'unrelated' }, { orderInfo: 'unrelated' },
    { extraData: 'forged' }, { partnerCode: 'OTHER_PARTNER' }]) {
    await rejectsCode(f.payments.notify(f.notification('order-0001', 0, change)), 'permission-denied');
  }
  assert.equal(f.order().paymentStatus, 'pending');
  assert.equal(f.stock(), 9);
});

test('a valid IPN confirms payment once; later failures cannot reverse a paid transaction', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  await Promise.all(Array.from({ length: 5 }, () => f.payments.notify(f.notification())));
  await f.payments.notify(f.notification('order-0001', 1006));
  assert.equal(f.order().paymentStatus, 'paid');
  assert.equal(f.order().status, 'Chờ xác nhận');
  assert.equal(f.order().paymentTransactionId, '123456789');
  assert.equal(f.stock(), 9);
});

test('cancelled and expired gateway payments return stock exactly once', async () => {
  for (const code of [1005, 1006, 1001]) {
    const f = fixture();
    await f.payments.create('alice', 'order-0001', input());
    await Promise.all([f.payments.notify(f.notification('order-0001', code)),
      f.payments.notify(f.notification('order-0001', code))]);
    assert.equal(f.order().status, 'Đã hủy');
    assert.equal(f.order().paymentStatus, 'failed');
    assert.equal(f.stock(), 10);
    await f.payments.create('alice', 'order-0001');
    assert.equal(f.stock(), 10);
  }
});

test('late money after stock release requires reconciliation and cannot create a fulfillable order', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  await f.payments.notify(f.notification('order-0001', 1006));
  await f.payments.notify(f.notification());
  await f.payments.notify(f.notification());
  assert.equal(f.order().paymentStatus, 'review_required');
  assert.equal(f.order().status, 'Cần đối soát');
  assert.equal(f.stock(), 10);
});

test('sandbox success is visibly separate and restores all reserved inventory', async () => {
  const f = fixture('sandbox');
  const session = await f.payments.create('alice', 'order-0001', input());
  assert.equal(session.mode, 'sandbox');
  assert.match(session.paymentUrl, /^https:\/\/test-payment\.momo\.vn\//);
  await f.payments.notify(f.notification());
  assert.equal(f.order().paymentEnvironment, 'sandbox');
  assert.equal(f.order().status, 'Thử nghiệm thành công');
  assert.equal(f.stock(), 10);
});

test('a lost create response keeps the same order and stock reservation for recovery', async () => {
  const f = fixture();
  f.failCreate();
  const session = await f.payments.create('alice', 'order-0001', input());
  assert.equal(session.paymentStatus, 'pending');
  assert.equal(session.paymentUrl, null);
  await f.payments.create('alice', 'order-0001');
  assert.equal(f.stock(), 9);
  f.setQueryCode(0);
  await f.payments.refresh('alice', 'order-0001');
  assert.equal(f.order().paymentStatus, 'paid');
});

test('an explicit merchant configuration rejection releases inventory and never claims payment', async () => {
  const f = fixture();
  f.setCreateCode(13);
  const session = await f.payments.create('alice', 'order-0001', input());
  assert.equal(session.paymentStatus, 'failed');
  assert.equal(f.stock(), 10);
});

test('query recovers a missed IPN and is throttled for repeated checks', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  await Promise.all(Array.from({ length: 4 }, () => f.payments.refresh('alice', 'order-0001')));
  assert.equal(f.requests.filter(r => r.url.endsWith('/query')).length, 1);
  f.advance(10001);
  f.setQueryCode(0);
  await f.payments.refresh('alice', 'order-0001');
  assert.equal(f.order().paymentStatus, 'paid');
});

test('only the buyer can resume or reconcile a payment', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  await rejectsCode(f.payments.create('bob', 'order-0001'), 'permission-denied');
  await rejectsCode(f.payments.refresh('bob', 'order-0001'), 'permission-denied');
  assert.equal(f.requests.length, 1);
});

test('pending, processing and unknown results keep inventory; automatic reconciliation releases only a confirmed failure', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  for (const code of [1000, 7000, 7002, 42]) {
    await f.payments.notify(f.notification('order-0001', code));
    assert.equal(f.stock(), 9);
    assert.equal(f.order().paymentStatus, 'pending');
  }
  f.setQueryCode(1005);
  f.advance(300001);
  assert.equal(await f.payments.reconcilePending(), 1);
  assert.equal(f.stock(), 10);
  assert.equal(await f.payments.reconcilePending(), 0);
});

test('a query outage cannot be mistaken for cancellation or release reserved stock', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  f.failQuery();
  f.advance(300001);
  await f.payments.reconcilePending();
  assert.equal(f.stock(), 9);
  assert.equal(f.order().paymentStatus, 'pending');
});

test('a crash before gateway creation is recovered with the same IDs without holding orphaned stock forever', async () => {
  const f = fixture();
  f.failCreate();
  await f.payments.create('alice', 'order-0001', input());
  f.recoverCreate();
  f.setQueryCode(42);
  const session = await f.payments.refresh('alice', 'order-0001');
  assert.ok(session.paymentUrl);
  assert.equal(f.stock(), 9);
  assert.equal(f.requests.filter(r => r.url.endsWith('/create')).length, 2);
  assert.equal(f.order().paymentStatus, 'pending');
});

test('automatic capture accepts authorized result 9000', async () => {
  const f = fixture();
  await f.payments.create('alice', 'order-0001', input());
  await f.payments.notify(f.notification('order-0001', 9000));
  assert.equal(f.order().paymentStatus, 'paid');
});

test('unknown environments, unsafe callbacks and structured signature values are rejected', () => {
  assert.throws(() => createMomoGateway({ ...config, mode: 'anything' }), PaymentError);
  assert.throws(() => createMomoGateway({ ...config, ipnUrl: 'http://unsafe.example/ipn' }), PaymentError);
  assert.throws(() => signature(config.secretKey, CREATE_FIELDS, { amount: { arbitrary: true } }), PaymentError);
});

test('payment creation is rate limited without charging retries against the budget', async () => {
  const f = fixture();
  for (let i = 1; i <= 5; i++) {
    await f.payments.create('alice', 'order-000' + i, input());
  }
  await rejectsCode(f.payments.create('alice', 'order-0006', input()), 'resource-exhausted');
  await f.payments.create('alice', 'order-0001');
  assert.equal(f.stock(), 5);
});

