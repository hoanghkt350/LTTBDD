const { readFileSync } = require('node:fs');
const assert = require('node:assert/strict');
const { test, before, beforeEach, after } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } = require('firebase/firestore');

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
const adminDb = (verified = true, claim = true) => env.authenticatedContext('admin', {email:'admin@example.com',email_verified:verified,admin:claim}).firestore();
const managedProduct = id => ({id,name:'Managed product',category:'FOOD',petTarget:'ALL',price:100000,
  originalPrice:100000,stock:10,imageUrl:'',description:'Description',isFeatured:false,isActive:true,updatedAt:serverTimestamp()});
const managedClinic = id => ({id,name:'Clinic',address:'Verified address',latitude:10,longitude:106,phone:'0901234567',
  openHours:'08:00 - 21:00',services:['Checkup'],isOpen24_7:false,updatedAt:serverTimestamp()});
const managedArticle = id => ({id,title:'Article',category:'Care',author:'Author',publishedAt:'2026-11-07',thumbnailUrl:'',
  summary:'Summary',content:'Content',readTimeMinutes:5,updatedAt:serverTimestamp()});
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
test('verified administrators can create and edit catalog, clinics and articles; users cannot', async () => {
  const fixtures=[['products/new',managedProduct('new')],['clinics/new',managedClinic('new')],['articles/new',managedArticle('new')]];
  for (const [path,data] of fixtures) {
    await assertFails(setDoc(doc(db('alice'),path),data));
    await assertFails(setDoc(doc(adminDb(false),path),data));
    await assertFails(setDoc(doc(adminDb(true,'true'),path),data));
    await assertSucceeds(setDoc(doc(adminDb(),path),data));
    await assertFails(updateDoc(doc(db('alice'),path),{name:'Tampered'}));
    await assertFails(deleteDoc(doc(db('alice'),path)));
  }
  await assertSucceeds(updateDoc(doc(adminDb(),'products/new'),{price:90000,updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(adminDb(),'products/new'),{stock:20,updatedAt:serverTimestamp()}));
  await assertSucceeds(deleteDoc(doc(adminDb(),'clinics/new')));
  await assertSucceeds(deleteDoc(doc(adminDb(),'articles/new')));
  await assertFails(deleteDoc(doc(adminDb(),'products/new')));
});
test('admin content validation rejects invalid prices, stock, coordinates, URLs and empty articles', async () => {
  for (const change of [{price:-1},{stock:-1},{stock:1.5},{originalPrice:1},{imageUrl:'http://unsafe.test/a.png'},{category:'FAKE'},{isActive:'true'}]) {
    await assertFails(setDoc(doc(adminDb(),'products/bad'),{...managedProduct('bad'),...change}));
  }
  await assertFails(setDoc(doc(adminDb(),'clinics/bad'),{...managedClinic('bad'),latitude:91}));
  await assertFails(setDoc(doc(adminDb(),'articles/bad'),{...managedArticle('bad'),content:''}));
});
test('profile fields and membership cannot promote a user to administrator', async () => {
  const profile={uid:'alice',email:'alice@example.com',displayName:'Alice',membershipLevel:'STANDARD'};
  for (const forged of [{admin:true},{role:'admin'},{membershipLevel:'ADMIN'}]) {
    await assertFails(setDoc(doc(db('alice'),'users/alice'),{...profile,...forged}));
  }
  await assertFails(setDoc(doc(db('alice'),'roles/alice'),{admin:true}));
  await assertFails(setDoc(doc(db('alice'),'admins/alice'),{admin:true}));
  await assertFails(updateDoc(doc(db('alice'),'products/p1'),{price:1}));
});
test('administrators can list profiles and all orders but cannot inspect private pet records or OTPs', async () => {
  await assertSucceeds(setDoc(doc(db('alice'),'users/alice'),{uid:'alice',email:'alice@example.com',displayName:'Alice',membershipLevel:'STANDARD'}));
  await checkout(db('alice'),orderData('alice','visible-to-admin'));
  await assertSucceeds(getDocs(collection(adminDb(),'users')));
  await assertSucceeds(getDocs(collection(adminDb(),'orders')));
  await assertSucceeds(getDoc(doc(adminDb(),'users/alice')));
  await assertFails(getDoc(doc(adminDb(),'users/alice/pets/1')));
  await assertFails(getDoc(doc(adminDb(),'emailVerificationChallenges/alice')));
  await assertFails(updateDoc(doc(adminDb(),'users/alice'),{displayName:'Changed by admin'}));
});
test('only administrators can advance an order and terminal states cannot be reversed', async () => {
  await checkout(db('alice'),orderData('alice','workflow'));
  const change = status => ({status,statusUpdatedAt:serverTimestamp(),statusUpdatedBy:'admin'});
  await assertFails(updateDoc(doc(db('alice'),'orders/workflow'),change('Đang giao')));
  await assertFails(updateDoc(doc(adminDb(),'orders/workflow'),change('Hoàn thành')));
  await assertSucceeds(updateDoc(doc(adminDb(),'orders/workflow'),change('Đang giao')));
  await assertFails(updateDoc(doc(adminDb(),'orders/workflow'),{...change('Hoàn thành'),totalAmount:0}));
  await assertFails(updateDoc(doc(adminDb(),'orders/workflow'),{...change('Hoàn thành'),userId:'admin'}));
  await assertSucceeds(updateDoc(doc(adminDb(),'orders/workflow'),change('Hoàn thành')));
  await assertFails(updateDoc(doc(adminDb(),'orders/workflow'),change('Chờ xác nhận')));
});
test('admin cancellation must return stock atomically, only once, including a five-line order', async () => {
  const order=orderData('alice','admin-cancel',5);
  const database=adminDb();
  await checkout(db('alice'),order);
  await assertFails(updateDoc(doc(adminDb(),'orders/admin-cancel'),{status:'Đã hủy',cancelledAt:serverTimestamp()}));
  const batch=writeBatch(database);
  batch.update(doc(database,'orders/admin-cancel'),{status:'Đã hủy',cancelledAt:serverTimestamp()});
  for (const id of Object.keys(order.items)) batch.update(doc(database,'products',id),{stock:10,lastOrderId:'admin-cancel',updatedAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  const retry=writeBatch(database);
  retry.update(doc(database,'orders/admin-cancel'),{status:'Đã hủy',cancelledAt:serverTimestamp()});
  for (const id of Object.keys(order.items)) retry.update(doc(database,'products',id),{stock:11,lastOrderId:'admin-cancel',updatedAt:serverTimestamp()});
  await assertFails(retry.commit());
  assert.equal((await getDoc(doc(db('alice'),'products/p1'))).data().stock,10);
});
test('archiving prevents checkout and still permits stock restoration on cancellation', async () => {
  const database = adminDb();
  const customer = db('alice');
  await assertSucceeds(setDoc(doc(database,'products/new'),managedProduct('new')));
  const order = orderData('alice','archived');
  order.items = {new:{name:'Managed product',price:100000,quantity:1,imageUrl:''}};
  await assertSucceeds(checkout(db('alice'),order));
  await assertSucceeds(updateDoc(doc(database,'products/new'),{isActive:false,updatedAt:serverTimestamp()}));
  await assertFails(checkout(db('alice'),{...order,orderId:'inactive'},8));
  const batch=writeBatch(customer);
  batch.update(doc(customer,'orders/archived'),{status:'Đã hủy',cancelledAt:serverTimestamp()});
  batch.update(doc(customer,'products/new'),{stock:10,lastOrderId:'archived',updatedAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
});
