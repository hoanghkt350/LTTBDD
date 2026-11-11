'use strict';

const { PaymentError } = require('./momo_gateway');
const POLL_MS = 5 * 60 * 1000;
const TERMINAL_POLL = Number.MAX_SAFE_INTEGER;
const FAILED_CODES = new Set([98, 99, 1001, 1002, 1003, 1004, 1005, 1006, 1007,
  1017, 1026, 2019, 4001, 4002, 4100]);
const validId = id => typeof id === 'string' && /^[A-Za-z0-9_-]{8,50}$/.test(id);
const fail = (code, message) => { throw new PaymentError(code, message); };

function validateCheckout(data) {
  const quantities = data?.quantities;
  if (!quantities || typeof quantities !== 'object' || Array.isArray(quantities) ||
      Object.keys(quantities).length < 1 || Object.keys(quantities).length > 5 ||
      Object.entries(quantities).some(([id, q]) => !/^[A-Za-z0-9_-]{1,128}$/.test(id) ||
        !Number.isInteger(q) || q < 1 || q > 99)) {
    fail('invalid-argument', 'Mỗi đơn tối đa 5 loại sản phẩm, mỗi loại từ 1 đến 99.');
  }
  const voucher = typeof data.voucher === 'string' ? data.voucher.trim().toUpperCase() : '';
  if (!['', 'FREESHIP', 'PAWPALS10', 'HUTECH10'].includes(voucher)) {
    fail('invalid-argument', 'Mã giảm giá không hợp lệ.');
  }
  const recipient = {};
  for (const key of ['name', 'phone', 'address']) {
    if (typeof data.recipient?.[key] !== 'string') fail('invalid-argument', 'Nhập đầy đủ thông tin nhận hàng.');
    recipient[key] = data.recipient[key].trim();
  }
  if (!recipient.name || recipient.name.length > 80 || !/^\+?[0-9]{9,12}$/.test(recipient.phone) ||
      recipient.address.length < 8 || recipient.address.length > 300) {
    fail('invalid-argument', 'Tên, số điện thoại hoặc địa chỉ nhận hàng không hợp lệ.');
  }
  return { quantities, voucher, recipient, prices: data.prices || {} };
}

function createPaymentService({ db, auth, gateway, timestamp, now = Date.now }) {
  const sessionRef = id => db.collection('payment_sessions').doc(id);
  const orderRef = id => db.collection('orders').doc(id);
  async function account(uid) {
    if (!uid) fail('unauthenticated', 'Bạn cần đăng nhập lại.');
    const user = await auth.getUser(uid);
    if (!user || user.disabled) {
      fail('permission-denied', 'Tài khoản không được phép thanh toán.');
    }
  }
  function sameGateway(session) {
    if (session.partnerCode !== gateway.partnerCode || session.mode !== gateway.mode) {
      fail('failed-precondition', 'Cấu hình MoMo đã thay đổi. Vui lòng liên hệ cửa hàng để kiểm tra đơn cũ.');
    }
  }
  const receipt = session => ({ orderId: session.orderId, paymentStatus: session.status,
    mode: session.mode, paymentUrl: session.status === 'pending' ? session.payUrl || null : null });

  async function create(uid, orderId, data) {
    await account(uid);
    if (!validId(orderId)) fail('invalid-argument', 'Mã đơn hàng không hợp lệ.');
    await db.runTransaction(async tx => {
      const order = (await tx.get(orderRef(orderId))).data();
      const existing = (await tx.get(sessionRef(orderId))).data();
      if (order || existing) {
        if (!order || !existing || order.userId !== uid || existing.uid !== uid || order.paymentMethod !== 'MOMO') {
          fail('permission-denied', 'Mã đơn đã được sử dụng. Hãy kiểm tra lịch sử đơn hàng.');
        }
        sameGateway(existing);
        return;
      }
      const input = validateCheckout(data);
      const rateRef = db.collection('payment_rate_limits').doc(uid);
      const rate = (await tx.get(rateRef)).data();
      if (rate?.windowEndsAtMs > now() && rate.count >= 5) {
        fail('resource-exhausted', 'Bạn đã tạo nhiều phiên thanh toán. Vui lòng kiểm tra đơn cũ hoặc thử lại sau 15 phút.');
      }
      const products = [];
      let subtotal = 0;
      const items = Object.create(null);
      for (const [id, quantity] of Object.entries(input.quantities)) {
        const ref = db.collection('products').doc(id);
        const product = (await tx.get(ref)).data();
        if (!product || product.isActive === false) fail('failed-precondition', 'Sản phẩm đã ngừng bán. Hãy cập nhật giỏ hàng.');
        if (!Number.isSafeInteger(product.price) || product.price <= 0 || input.prices[id] !== product.price) {
          fail('failed-precondition', 'Giá sản phẩm đã thay đổi. Hãy cập nhật giỏ hàng.');
        }
        if (!Number.isSafeInteger(product.stock) || product.stock < quantity) {
          fail('failed-precondition', 'Số lượng sản phẩm vượt quá tồn kho. Hãy cập nhật giỏ hàng.');
        }
        subtotal += product.price * quantity;
        items[id] = { name: product.name, imageUrl: product.imageUrl || '', price: product.price, quantity };
        products.push({ ref, stock: product.stock - quantity });
      }
      const discountAmount = ['PAWPALS10', 'HUTECH10'].includes(input.voucher) ? Math.round(subtotal * 0.1) : 0;
      const shippingFee = subtotal >= 300000 || input.voucher === 'FREESHIP' ? 0 : 25000;
      const amount = subtotal - discountAmount + shippingFee;
      if (!Number.isSafeInteger(amount) || amount < 1000 || amount > 50000000) {
        fail('invalid-argument', 'MoMo hỗ trợ đơn từ 1.000đ đến 50.000.000đ. Vui lòng chọn COD cho đơn này.');
      }
      for (const product of products) tx.update(product.ref, {
        stock: product.stock, lastOrderId: orderId, updatedAt: timestamp(),
      });
      tx.set(orderRef(orderId), { orderId, userId: uid, items, recipient: input.recipient,
        subtotal, discountAmount, shippingFee, totalAmount: amount, voucher: input.voucher,
        status: 'Chờ thanh toán', paymentMethod: 'MOMO', paymentStatus: 'pending',
        paymentEnvironment: gateway.mode, createdAt: timestamp() });
      tx.set(sessionRef(orderId), { orderId, uid, amount, requestId: orderId,
        orderInfo: `PawPals - Thanh toan don ${orderId}`, partnerCode: gateway.partnerCode,
        mode: gateway.mode, status: 'pending', stockReserved: true,
        createdAtMs: now(), pollAtMs: now() + POLL_MS, createLeaseUntilMs: 0 });
      tx.set(rateRef, { windowEndsAtMs: rate?.windowEndsAtMs > now() ? rate.windowEndsAtMs : now() + 15 * 60 * 1000,
        count: rate?.windowEndsAtMs > now() ? rate.count + 1 : 1 });
    });

    // The gateway call is outside the Firestore transaction. Its stable IDs make retries safe.
    const locked = await db.runTransaction(async tx => {
      const session = (await tx.get(sessionRef(orderId))).data();
      if (session.status !== 'pending' || session.payUrl || session.createLeaseUntilMs > now()) return null;
      tx.update(sessionRef(orderId), { createLeaseUntilMs: now() + 45000 });
      return session;
    });
    if (locked) {
      try {
        const payUrl = await gateway.create(locked);
        await db.runTransaction(async tx => {
          const session = (await tx.get(sessionRef(orderId))).data();
          if (session.status === 'pending') tx.update(sessionRef(orderId), { payUrl, createLeaseUntilMs: 0 });
        });
      } catch (error) {
        if (error instanceof PaymentError && error.details?.definitive) {
          await settle(orderId, { orderId, partnerCode: gateway.partnerCode, amount: locked.amount,
            resultCode: error.details.resultCode }, true);
        } else {
          // A timeout is ambiguous: preserve the reservation and reconcile, never declare failure.
          await sessionRef(orderId).update({ createLeaseUntilMs: 0, pollAtMs: now() + POLL_MS });
        }
      }
    }
    return receipt((await sessionRef(orderId).get()).data());
  }

  async function settle(orderId, result, rejectedCreate = false) {
    if (!validId(orderId)) fail('invalid-argument', 'Mã đơn hàng không hợp lệ.');
    return db.runTransaction(async tx => {
      const session = (await tx.get(sessionRef(orderId))).data();
      const order = (await tx.get(orderRef(orderId))).data();
      if (!session || !order) fail('not-found', 'Không tìm thấy giao dịch MoMo.');
      sameGateway(session);
      if (result.orderId !== session.orderId || result.partnerCode !== session.partnerCode ||
          !Number.isSafeInteger(Number(result.amount)) || Number(result.amount) !== session.amount ||
          !Number.isInteger(result.resultCode)) {
        fail('permission-denied', 'Thông tin giao dịch MoMo không khớp đơn hàng.');
      }
      const success = result.resultCode === 0 || result.resultCode === 9000; // autoCapture=true
      if (success && !/^[0-9]{1,30}$/.test(String(result.transId || ''))) {
        fail('invalid-argument', 'Mã giao dịch MoMo không hợp lệ.');
      }
      if (['paid', 'review_required'].includes(session.status)) return receipt(session);
      if (!success && !rejectedCreate && !FAILED_CODES.has(result.resultCode)) {
        if (session.status === 'pending') tx.update(sessionRef(orderId), { pollAtMs: now() + POLL_MS });
        return receipt(session);
      }
      if (!success && session.status === 'failed') return receipt(session);
      const lateSuccess = success && !session.stockReserved;
      const returnStock = session.stockReserved && (!success || session.mode === 'sandbox');
      const products = [];
      if (returnStock) {
        for (const [id, item] of Object.entries(order.items)) {
          const ref = db.collection('products').doc(id);
          const product = (await tx.get(ref)).data();
          if (!product || !Number.isSafeInteger(product.stock)) {
            fail('failed-precondition', 'Không thể hoàn kho. Cần quản trị viên kiểm tra.');
          }
          products.push({ ref, stock: product.stock + item.quantity });
        }
      }
      for (const product of products) tx.update(product.ref, {
        stock: product.stock, lastOrderId: orderId, updatedAt: timestamp(),
      });
      const paymentStatus = lateSuccess ? 'review_required' : success ? 'paid' : 'failed';
      const status = lateSuccess ? 'Cần đối soát' : success
        ? session.mode === 'sandbox' ? 'Thử nghiệm thành công' : 'Chờ xác nhận' : 'Đã hủy';
      const change = { paymentStatus, status, paymentResultCode: result.resultCode,
        statusUpdatedAt: timestamp(), statusUpdatedBy: 'system:momo',
        ...(success ? { paymentTransactionId: String(result.transId), paidAt: timestamp() } : { cancelledAt: timestamp() }) };
      tx.update(orderRef(orderId), change);
      tx.update(sessionRef(orderId), { status: paymentStatus, resultCode: result.resultCode,
        stockReserved: session.stockReserved && !returnStock,
        pollAtMs: TERMINAL_POLL, ...(success ? { transactionId: String(result.transId) } : {}) });
      return receipt({ ...session, status: paymentStatus });
    });
  }

  async function notify(body) {
    const result = gateway.verifyNotification(body);
    if (!validId(result.orderId)) fail('invalid-argument', 'Mã đơn hàng không hợp lệ.');
    const session = (await sessionRef(result.orderId).get()).data();
    if (!session) fail('not-found', 'Không tìm thấy giao dịch MoMo.');
    if (result.requestId !== session.requestId || result.orderInfo !== session.orderInfo || result.extraData !== '') {
      fail('permission-denied', 'Thông báo MoMo không khớp phiên thanh toán.');
    }
    return settle(result.orderId, result);
  }

  async function reconcile(orderId) {
    const session = await db.runTransaction(async tx => {
      const data = (await tx.get(sessionRef(orderId))).data();
      if (!data || data.status !== 'pending' || data.queryLeaseUntilMs > now()) return null;
      sameGateway(data);
      tx.update(sessionRef(orderId), { queryLeaseUntilMs: now() + 45000, pollAtMs: now() + POLL_MS });
      return data;
    });
    if (!session) return;
    try {
      let result;
      try {
        result = await gateway.query(session);
      } catch (error) {
        if (error instanceof PaymentError && error.code === 'not-found' && !session.payUrl) {
          // Recover a crash after reserving stock but before the create request reached MoMo.
          // The same order/request IDs are reused; no second reservation is made.
          await create(session.uid, orderId);
          return;
        }
        throw error;
      }
      await settle(orderId, result);
    } finally {
      await sessionRef(orderId).update({ queryLeaseUntilMs: now() + 10000 });
    }
  }

  async function refresh(uid, orderId) {
    await account(uid);
    if (!validId(orderId)) fail('invalid-argument', 'Mã đơn hàng không hợp lệ.');
    const session = (await sessionRef(orderId).get()).data();
    if (!session || session.uid !== uid) fail('permission-denied', 'Bạn không có quyền xem giao dịch này.');
    await reconcile(orderId);
    return receipt((await sessionRef(orderId).get()).data());
  }

  async function reconcilePending() {
    const due = await db.collection('payment_sessions').where('pollAtMs', '<=', now()).limit(20).get();
    for (let i = 0; i < due.docs.length; i += 5) {
      await Promise.all(due.docs.slice(i, i + 5).map(async doc => {
        try { await reconcile(doc.id); } catch (_) { /* Keep the reservation and retry next schedule. */ }
      }));
    }
    return due.docs.length;
  }

  return { create, notify, refresh, reconcilePending };
}

module.exports = { createPaymentService, validateCheckout, FAILED_CODES };
