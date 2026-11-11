const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { createHmac } = require('node:crypto');
const fromFunctions = createRequire(require.resolve('../functions/package.json'));
const { initializeApp, deleteApp } = fromFunctions('firebase-admin/app');
const { getFirestore, FieldValue } = fromFunctions('firebase-admin/firestore');
const { createMomoGateway } = require('../functions/momo_gateway');
const { createPaymentService } = require('../functions/payments');

const projectId = 'demo-pawpals-payments';
const config = { mode:'production', partnerCode:'PAWPALS_TEST_PARTNER', accessKey:'test-access-key',
  secretKey:'fixture-secret-key-never-use-in-production',
  ipnUrl:'https://merchant.example/ipn',redirectUrl:'https://merchant.example/return' };
let app, db, payments, queryCode;
before(() => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^127\.0\.0\.1:\d+$/,
    'Payment integration tests require a localhost Firestore Emulator.');
  app = initializeApp({ projectId }, 'payment-integration');
  db = getFirestore(app);
  const gateway = createMomoGateway(config, { fetchImpl: async (url, options) => {
    const request = JSON.parse(options.body);
    const session = (await db.collection('payment_sessions').doc(request.orderId).get()).data();
    return { ok:true,json:async()=>({ partnerCode:config.partnerCode,orderId:request.orderId,
      requestId:request.requestId,amount:session.amount,resultCode:url.endsWith('/create') ? 0 : queryCode,
      transId:987654321,payUrl:'https://payment.momo.vn/v2/gateway/pay?t=fixture' }) };
  } });
  payments = createPaymentService({db,auth:{getUser:async()=>({emailVerified:true})},gateway,
    timestamp:()=>FieldValue.serverTimestamp()});
});
beforeEach(async () => {
  const response = await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method:'DELETE'});
  assert.equal(response.ok,true);
  queryCode = 1000;
  await db.collection('products').doc('p1').set({name:'Pet food',imageUrl:'',price:100000,stock:2,isActive:true});
});
after(async()=>{if(app)await deleteApp(app);});
const input = () => ({quantities:{p1:1},prices:{p1:100000},recipient:{name:'Buyer',phone:'0901234567',address:'123 Example Street'}});
async function notify(id, code) {
  const session = (await db.collection('payment_sessions').doc(id).get()).data();
  const body = {amount:session.amount,extraData:'',message:'Gateway result',orderId:id,orderInfo:session.orderInfo,
    orderType:'momo_wallet',partnerCode:config.partnerCode,payType:'qr',requestId:id,responseTime:Date.now(),resultCode:code,transId:987654321};
  const raw = `accessKey=${config.accessKey}&amount=${body.amount}&extraData=&message=${body.message}&orderId=${id}`+
    `&orderInfo=${body.orderInfo}&orderType=momo_wallet&partnerCode=${config.partnerCode}&payType=qr&requestId=${id}`+
    `&responseTime=${body.responseTime}&resultCode=${code}&transId=987654321`;
  body.signature=createHmac('sha256',config.secretKey).update(raw).digest('hex');
  return payments.notify(body);
}
const stock=async()=>(await db.collection('products').doc('p1').get()).data().stock;

test('real Firestore retries reserve one order once and valid IPNs settle atomically', async()=>{
  await Promise.all([payments.create('alice','firestore-order-1',input()),payments.create('alice','firestore-order-1',input())]);
  assert.equal(await stock(),1);
  await Promise.all([notify('firestore-order-1',0),notify('firestore-order-1',0)]);
  const order=(await db.collection('orders').doc('firestore-order-1').get()).data();
  assert.equal(order.paymentStatus,'paid');
  assert.equal(order.status,'Chờ xác nhận');
  assert.ok(order.paidAt.toMillis()>0);
  assert.equal(await stock(),1);
});

test('real Firestore restores inventory exactly once for concurrent failed notifications', async()=>{
  await payments.create('alice','firestore-order-2',input());
  await Promise.all([notify('firestore-order-2',1005),notify('firestore-order-2',1005)]);
  assert.equal(await stock(),2);
  assert.equal((await db.collection('orders').doc('firestore-order-2').get()).data().status,'Đã hủy');
});

test('real Firestore prevents overselling and query recovers an absent IPN', async()=>{
  await db.collection('products').doc('p1').update({stock:1});
  const attempts=await Promise.allSettled([
    payments.create('alice','firestore-order-3',input()),payments.create('bob','firestore-order-4',input()),
  ]);
  assert.equal(attempts.filter(r=>r.status==='fulfilled').length,1);
  const winner=attempts[0].status==='fulfilled' ? ['alice','firestore-order-3'] : ['bob','firestore-order-4'];
  queryCode=0;
  await payments.refresh(...winner);
  assert.equal((await db.collection('orders').doc(winner[1]).get()).data().paymentStatus,'paid');
  assert.equal(await stock(),0);
});
