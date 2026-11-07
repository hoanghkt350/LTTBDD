const { readFileSync } = require('node:fs');
const { test, before, beforeEach, after } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, writeBatch, serverTimestamp } = require('firebase/firestore');

let env;
before(async () => {
  const endpoint=process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  const [host,port]=endpoint.split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-pawpals',
    firestore: { host, port:Number(port), rules: readFileSync('../firestore.rules', 'utf8') }
  });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    for(let i=1;i<=6;i++) await setDoc(doc(ctx.firestore(), 'products/p'+i), {
      id:'p'+i, name:'Product '+i, price:100000, stock:10, imageUrl:'https://example.com/p.jpg'
    });
  });
});
after(async () => { if(env) await env.cleanup(); });
const db = (uid, verified = true) => env.authenticatedContext(uid, {email:uid+'@example.com', email_verified:verified}).firestore();
function orderData(uid, id, count=1) {
  const items={};
  for(let i=1;i<=count;i++) items['p'+i]={name:'Product '+i,price:100000,quantity:1,imageUrl:'https://example.com/p.jpg'};
  const subtotal=count*100000;
  return {orderId:id,userId:uid,items,recipient:{name:'Test',phone:'0901234567',address:'123 Example Street'},
    subtotal,discountAmount:0,shippingFee:subtotal>=300000 ? 0 : 25000,
    totalAmount:subtotal+(subtotal>=300000 ? 0 : 25000),voucher:'',status:'Chờ xác nhận',
    paymentMethod:'COD',createdAt:serverTimestamp()};
}
function checkout(database, order, stock=9) {
  const batch=writeBatch(database);
  batch.set(doc(database,'orders',order.orderId),order);
  for(const id of Object.keys(order.items)) batch.update(doc(database,'products',id),
    {stock,lastOrderId:order.orderId,updatedAt:serverTimestamp()});
  return batch.commit();
}
test('users cannot read other profiles or pet records', async () => {
  await assertSucceeds(setDoc(doc(db('alice'),'users/alice'), {
    uid:'alice',email:'alice@example.com',displayName:'Alice',membershipLevel:'STANDARD',
    phoneNumber:null,address:null,avatarUrl:null
  }));
  await assertFails(getDoc(doc(db('bob'),'users/alice')));
  await assertFails(setDoc(doc(db('alice'),'users/bob/pets/1'), {id:1,updatedAt:serverTimestamp()}));
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'products')));
});
test('unverified accounts cannot read catalogs, profiles, pets or orders or write data', async () => {
  const database = db('alice', false);
  await assertFails(getDoc(doc(database, 'products/p1')));
  await assertFails(getDoc(doc(database, 'users/alice')));
  await assertFails(getDocs(collection(database, 'users/alice/pets')));
  await assertFails(getDocs(collection(database, 'clinics')));
  await assertFails(getDocs(collection(database, 'articles')));
  await assertFails(getDocs(query(collection(database, 'orders'), where('userId', '==', 'alice'))));
  await assertFails(setDoc(doc(database, 'users/alice'), {
    uid:'alice',email:'alice@example.com',displayName:'Alice',membershipLevel:'STANDARD',emailVerified:true,
  }));
  await assertFails(setDoc(doc(database, 'users/alice/pets/1'), {
    id:1,name:'Milo',weight:5,avatar_cloud_url:null,updatedAt:serverTimestamp(),
  }));
  await assertFails(checkout(database, orderData('alice', 'unverified')));
});
test('OTP challenges and rate limits are inaccessible even to verified owners', async () => {
  for (const path of ['emailVerificationChallenges/alice', 'emailVerificationRateLimits/alice']) {
    await assertFails(getDoc(doc(db('alice'), path)));
    await assertFails(setDoc(doc(db('alice'), path), {code:'123456',attempts:0}));
  }
});
test('pet outbox writes and tombstones are owner-scoped', async () => {
  const ref=doc(db('alice'),'users/alice/pets/123');
  await assertSucceeds(setDoc(ref,{id:123,name:'Milo',weight:5,avatar_cloud_url:null,updatedAt:serverTimestamp()}));
  await assertFails(getDoc(doc(db('bob'),'users/alice/pets/123')));
  await assertSucceeds(setDoc(ref,{id:123,deleted:true,updatedAt:serverTimestamp()}));
});
test('valid order reserves stock and cancellation returns it once', async () => {
  const database=db('alice'), order=orderData('alice','order1');
  await assertSucceeds(checkout(database,order));
  if((await getDoc(doc(database,'products/p1'))).data().stock!==9) throw Error('stock not reserved');
  const batch=writeBatch(database);
  batch.update(doc(database,'orders/order1'),{status:'Đã hủy',cancelledAt:serverTimestamp()});
  batch.update(doc(database,'products/p1'),{stock:10,lastOrderId:'order1',updatedAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(database,'products/p1'),{stock:11,lastOrderId:'order1',updatedAt:serverTimestamp()}));
});
test('five product checkout stays within per-operation rule access limits', async () => {
  await assertSucceeds(checkout(db('alice'),orderData('alice','five',5)));
});
test('six product order is rejected', async () => {
  await assertFails(checkout(db('alice'),orderData('alice','six',6)));
});
test('forged prices or totals cannot be submitted', async () => {
  const cheap=orderData('alice','cheap');
  cheap.items.p1.price=1; cheap.subtotal=1; cheap.totalAmount=25001;
  await assertFails(checkout(db('alice'),cheap));
  const total=orderData('alice','total'); total.totalAmount=0;
  await assertFails(checkout(db('alice'),total));
});
test('orders without stock reservation and standalone stock changes fail', async () => {
  await assertFails(setDoc(doc(db('alice'),'orders/no-stock'),orderData('alice','no-stock')));
  await assertFails(updateDoc(doc(db('alice'),'products/p1'),{stock:0,lastOrderId:'made-up',updatedAt:serverTimestamp()}));
});
test('negative stock and invalid voucher are rejected', async () => {
  const order=orderData('alice','negative');
  order.items.p1.quantity=11; order.subtotal=1100000; order.shippingFee=0; order.totalAmount=1100000;
  await assertFails(checkout(db('alice'),order,-1));
  const bad=orderData('alice','voucher'); bad.voucher='ADMIN100';
  await assertFails(checkout(db('alice'),bad));
});
test('another user cannot read or cancel an order; queries must be scoped', async () => {
  await checkout(db('alice'),orderData('alice','private'));
  await assertFails(getDoc(doc(db('bob'),'orders/private')));
  await assertFails(updateDoc(doc(db('bob'),'orders/private'),{status:'Đã hủy',cancelledAt:serverTimestamp()}));
  await assertFails(getDocs(collection(db('alice'),'orders')));
  await assertSucceeds(getDocs(query(collection(db('alice'),'orders'),where('userId','==','alice'))));
});
test('discounts and free shipping follow the same formula as the app', async () => {
  const free=orderData('alice','free'); free.voucher='FREESHIP'; free.shippingFee=0; free.totalAmount=100000;
  await assertSucceeds(checkout(db('alice'),free));
  const discount=orderData('alice','discount'); discount.voucher='PAWPALS10'; discount.discountAmount=10000; discount.totalAmount=115000;
  await assertSucceeds(checkout(db('alice'),discount,8));
});
