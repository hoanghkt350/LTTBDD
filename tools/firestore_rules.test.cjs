const { readFileSync } = require('node:fs');
const assert = require('node:assert/strict');
const { test, before, beforeEach, after } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, getAggregateFromServer, count, sum, Timestamp } = require('firebase/firestore');

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

async function seedOnlineOrder(id, paymentStatus = 'pending', mode = 'production') {
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(), 'orders', id), {
      ...orderData('alice', id), paymentMethod: 'MOMO', paymentStatus,
      paymentEnvironment: mode, status: paymentStatus === 'paid' ? 'Chờ xác nhận' : 'Chờ thanh toán',
    });
  });
}

test('clients cannot create online orders, forge payment results or access gateway sessions', async () => {
  await assertFails(checkout(db('alice'), {...orderData('alice','forged-online'),paymentMethod:'MOMO',paymentStatus:'paid'}));
  await seedOnlineOrder('server-online');
  for (const database of [db('alice'), adminDb()]) {
    await assertFails(updateDoc(doc(database,'orders/server-online'),{paymentStatus:'paid',paymentTransactionId:'forged'}));
    for (const collection of ['payment_sessions','payment_rate_limits']) {
      await assertFails(getDoc(doc(database,collection,'server-online')));
      await assertFails(setDoc(doc(database,collection,'server-online'),{status:'paid'}));
    }
  }
  await assertSucceeds(getDoc(doc(db('alice'),'orders/server-online')));
  await assertFails(getDoc(doc(db('bob'),'orders/server-online')));
});

test('unpaid and sandbox MoMo orders cannot ship; only paid production orders can advance', async () => {
  const change = {status:'Đang giao',statusUpdatedAt:serverTimestamp(),statusUpdatedBy:'admin'};
  await seedOnlineOrder('unpaid');
  await assertFails(updateDoc(doc(adminDb(),'orders/unpaid'),change));
  await seedOnlineOrder('sandbox-paid','paid','sandbox');
  await assertFails(updateDoc(doc(adminDb(),'orders/sandbox-paid'),change));
  await seedOnlineOrder('production-paid','paid');
  await assertSucceeds(updateDoc(doc(adminDb(),'orders/production-paid'),change));
  await assertSucceeds(updateDoc(doc(adminDb(),'orders/production-paid'),{
    ...change,status:'Hoàn thành',
  }));
});

test('online cancellation and stock release cannot bypass gateway verification', async () => {
  await seedOnlineOrder('online-cancel','paid');
  for (const database of [db('alice'),adminDb()]) {
    const batch = writeBatch(database);
    batch.update(doc(database,'orders/online-cancel'),{status:'Đã hủy',cancelledAt:serverTimestamp()});
    batch.update(doc(database,'products/p1'),{stock:11,lastOrderId:'online-cancel',updatedAt:serverTimestamp()});
    await assertFails(batch.commit());
  }
});
const managedProduct = id => ({id,name:'Managed product',category:'FOOD',petTarget:'ALL',price:100000,
  originalPrice:100000,stock:10,imageUrl:'',description:'Description',isFeatured:false,isActive:true,updatedAt:serverTimestamp()});
const managedClinic = id => ({id,name:'Clinic',address:'Verified address',latitude:10,longitude:106,phone:'0901234567',
  openHours:'08:00 - 21:00',services:['Checkup'],isOpen24_7:false,updatedAt:serverTimestamp()});
const managedArticle = id => ({id,title:'Article',category:'Care',author:'Author',publishedAt:'2026-11-07',thumbnailUrl:'',
  summary:'Summary',content:'Content',readTimeMinutes:5,updatedAt:serverTimestamp()});
const adminRequest = uid => ({uid,email:uid+'@example.com',displayName:uid,reason:'Help maintain the PawPals catalog',
  status:'pending',createdAt:serverTimestamp(),updatedAt:serverTimestamp(),reviewedAt:null,reviewedBy:null,reviewNote:''});
const reviewRequest = (status, reviewer='admin') => ({status,updatedAt:serverTimestamp(),reviewedAt:serverTimestamp(),
  reviewedBy:reviewer,reviewNote:'Reviewed by administrator'});
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
test('email accounts can use their own data without verification; ownership and roles are enforced', async () => {
  const database = db('alice', false);
  await assertSucceeds(getDoc(doc(database, 'products/p1')));
  await assertSucceeds(getDoc(doc(database, 'users/alice')));
  await assertSucceeds(getDocs(collection(database, 'users/alice/pets')));
  await assertSucceeds(getDocs(collection(database, 'clinics')));
  await assertSucceeds(getDocs(collection(database, 'articles')));
  await assertSucceeds(getDocs(query(collection(database, 'orders'), where('userId', '==', 'alice'))));
  await assertFails(setDoc(doc(database, 'users/alice'), {
    uid:'alice',email:'alice@example.com',displayName:'Alice',membershipLevel:'STANDARD',emailVerified:true,
  }));
  await assertSucceeds(setDoc(doc(database, 'users/alice'), {
    uid:'alice',email:'alice@example.com',displayName:'Alice',membershipLevel:'STANDARD',
    phoneNumber:null,address:null,avatarUrl:null,
  }));
  await assertSucceeds(setDoc(doc(database, 'users/alice/pets/1'), {
    id:1,name:'Milo',weight:5,avatar_cloud_url:null,updatedAt:serverTimestamp(),
  }));
  await assertSucceeds(checkout(database, orderData('alice', 'unverified')));
  await assertFails(getDoc(doc(database, 'users/bob')));
  await assertFails(setDoc(doc(database, 'products/self-promoted'), managedProduct('self-promoted')));
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

test('dated health reminders and completion sync remain private to the owner', async () => {
  const data = {id:2,pet_id:1,title:'Vaccine follow-up',cost:0,next_due_date:'2026-11-10',
    next_due_reminder_enabled:true,next_due_reminder_time:'09:30',next_due_completed:false,updatedAt:serverTimestamp()};
  const ref = doc(db('alice'),'users/alice/health_records/2');
  await assertSucceeds(setDoc(ref,data));
  await assertSucceeds(updateDoc(ref,{next_due_completed:true,updatedAt:serverTimestamp()}));
  await assertFails(getDoc(doc(db('bob'),'users/alice/health_records/2')));
  await assertFails(getDoc(doc(adminDb(),'users/alice/health_records/2')));
  await assertFails(updateDoc(doc(db('bob'),'users/alice/health_records/2'),{next_due_completed:false,updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{next_due_completed:false,next_due_reminder_enabled:false,updatedAt:serverTimestamp()}));
});

test('dashboard aggregates all matching orders, uses completion dates and requires administrator access', async () => {
  const start = Timestamp.fromDate(new Date('2026-11-07T17:00:00Z'));
  const end = Timestamp.fromDate(new Date('2026-11-08T17:00:00Z'));
  await env.withSecurityRulesDisabled(async ctx => {
    const database = ctx.firestore();
    const batch = writeBatch(database);
    const add = (id,status,total,completedAt) => batch.set(doc(database,'orders',id),{
      ...orderData('alice',id),status,totalAmount:total,
      createdAt:Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')),
      ...(completedAt ? {statusUpdatedAt:Timestamp.fromDate(new Date(completedAt))} : {}),
    });
    add('before','Hoàn thành',100,'2026-11-07T16:59:59Z');
    add('at-start','Hoàn thành',200,'2026-11-07T17:00:00Z');
    add('last-second','Hoàn thành',300,'2026-11-08T16:59:59Z');
    add('at-end','Hoàn thành',400,'2026-11-08T17:00:00Z');
    add('cancelled','Đã hủy',999999,'2026-11-08T01:00:00Z');
    add('legacy','Hoàn thành',999999,null);
    for (let i=0;i<105;i++) add('pending-'+i,'Chờ xác nhận',999999,null);
    await batch.commit();
  });
  const completedQuery = database => query(collection(database,'orders'),where('status','==','Hoàn thành'),
    where('statusUpdatedAt','>=',start),where('statusUpdatedAt','<',end));
  const total = await assertSucceeds(getAggregateFromServer(completedQuery(adminDb()),{count:count(),revenue:sum('totalAmount')}));
  assert.equal(total.data().count,2);
  assert.equal(total.data().revenue,500);
  const pending = await assertSucceeds(getAggregateFromServer(query(collection(adminDb(),'orders'),where('status','==','Chờ xác nhận')),{count:count()}));
  assert.equal(pending.data().count,105);
  await assertFails(getAggregateFromServer(completedQuery(db('alice')),{count:count(),revenue:sum('totalAmount')}));
  await assertSucceeds(getAggregateFromServer(completedQuery(adminDb(false)),{count:count()}));
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
test('administrators can create and edit catalog, clinics and articles; users cannot', async () => {
  const fixtures=[['products/new',managedProduct('new')],['clinics/new',managedClinic('new')],['articles/new',managedArticle('new')]];
  for (const [path,data] of fixtures) {
    await assertFails(setDoc(doc(db('alice'),path),data));
    await assertSucceeds(setDoc(doc(adminDb(false),path),data));
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

test('only signed-in owners can submit a correctly attributed pending admin request', async () => {
  await assertSucceeds(getDoc(doc(db('alice'), 'admin_requests/alice')));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'admin_requests/alice'), adminRequest('alice')));
  await assertFails(setDoc(doc(db('bob'), 'admin_requests/alice'), adminRequest('alice')));
  for (const forged of [{uid:'bob'},{email:'admin@example.com'},{status:'approved'},
    {reviewedBy:'admin'},{reviewedAt:serverTimestamp()},{reason:'short'},{reason:'x'.repeat(501)},
    {admin:true},{createdAt:new Date(0)}]) {
    await assertFails(setDoc(doc(db('alice'), 'admin_requests/alice'), {...adminRequest('alice'),...forged}));
  }
  await assertSucceeds(setDoc(doc(db('alice'), 'admin_requests/alice'), adminRequest('alice')));
  await assertSucceeds(getDoc(doc(db('alice'), 'admin_requests/alice')));
  await assertFails(getDoc(doc(db('bob'), 'admin_requests/alice')));
  await assertFails(getDocs(collection(db('alice'), 'admin_requests')));
  await assertSucceeds(getDocs(collection(adminDb(), 'admin_requests')));
});

test('pending applicants cannot approve, rewrite, duplicate or delete their request', async () => {
  const database = db('alice');
  const ref = doc(database, 'admin_requests/alice');
  await setDoc(ref, adminRequest('alice'));
  await assertFails(updateDoc(ref, reviewRequest('approved', 'alice')));
  await assertFails(updateDoc(ref, {reason:'A different reason for access',updatedAt:serverTimestamp()}));
  await assertFails(setDoc(ref, adminRequest('alice')));
  await assertFails(deleteDoc(ref));
  const batch = writeBatch(database);
  batch.update(ref, reviewRequest('approved', 'alice'));
  batch.set(doc(database, 'products/self-promoted'), managedProduct('self-promoted'));
  await assertFails(batch.commit());
});

test('reviews preserve applicant details, require the real reviewer and reject stale decisions', async () => {
  await setDoc(doc(db('alice'), 'admin_requests/alice'), adminRequest('alice'));
  const ref = doc(adminDb(), 'admin_requests/alice');
  await assertFails(updateDoc(doc(db('bob'), 'admin_requests/alice'), reviewRequest('approved', 'bob')));
  await assertFails(updateDoc(ref, {...reviewRequest('approved'),uid:'admin'}));
  await assertFails(updateDoc(ref, {...reviewRequest('approved'),reason:'Changed by reviewer'}));
  await assertFails(updateDoc(ref, reviewRequest('approved', 'someone-else')));
  await assertFails(updateDoc(ref, {...reviewRequest('approved'),reviewedAt:new Date(0)}));
  await assertSucceeds(updateDoc(ref, reviewRequest('approved')));
  await assertFails(updateDoc(ref, reviewRequest('rejected')));
  assert.equal((await getDoc(ref)).data().reason, adminRequest('alice').reason);
});

test('approved applicants manage content and review others without a custom claim; revocation takes effect immediately', async () => {
  const alice = db('alice');
  await setDoc(doc(alice, 'admin_requests/alice'), adminRequest('alice'));
  await updateDoc(doc(adminDb(), 'admin_requests/alice'), reviewRequest('approved'));
  await assertSucceeds(setDoc(doc(alice, 'products/delegated'), managedProduct('delegated')));
  await assertSucceeds(updateDoc(doc(alice, 'products/delegated'), {price:90000,updatedAt:serverTimestamp()}));
  await assertSucceeds(getDocs(collection(alice, 'users')));
  await assertFails(getDoc(doc(alice, 'users/bob/pets/1')));
  await assertSucceeds(setDoc(doc(db('alice',false), 'products/unverified-admin'), managedProduct('unverified-admin')));
  await setDoc(doc(db('bob'), 'admin_requests/bob'), adminRequest('bob'));
  await assertSucceeds(updateDoc(doc(alice, 'admin_requests/bob'), reviewRequest('approved', 'alice')));
  await assertFails(updateDoc(doc(alice, 'admin_requests/alice'), reviewRequest('revoked', 'alice')));
  await assertSucceeds(updateDoc(doc(adminDb(), 'admin_requests/alice'), reviewRequest('revoked')));
  await assertFails(getDocs(collection(alice, 'users')));
  await assertFails(updateDoc(doc(alice, 'products/delegated'), {price:1,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(alice, 'admin_requests/alice'), reviewRequest('approved', 'alice')));
});

test('a rejected or revoked applicant can resubmit without restoring privileges or rewriting the original creation date', async () => {
  for (const finalStatus of ['rejected', 'revoked']) {
    const uid = finalStatus;
    const database = db(uid);
    const ref = doc(database, 'admin_requests/'+uid);
    await setDoc(ref, adminRequest(uid));
    if (finalStatus === 'revoked') await updateDoc(doc(adminDb(), 'admin_requests/'+uid), reviewRequest('approved'));
    await updateDoc(doc(adminDb(), 'admin_requests/'+uid), reviewRequest(finalStatus));
    const previous = (await getDoc(ref)).data();
    await assertFails(setDoc(ref, adminRequest(uid)));
    await assertSucceeds(setDoc(ref, {...adminRequest(uid),createdAt:previous.createdAt}));
    await assertFails(getDocs(collection(database, 'users')));
    assert.equal((await getDoc(ref)).data().status, 'pending');
  }
});

test('even a custom-claim admin cannot review their own request', async () => {
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), 'admin_requests/admin'), adminRequest('admin')));
  await assertFails(updateDoc(doc(adminDb(), 'admin_requests/admin'), reviewRequest('approved')));
});

test('an approved admin can cancel a five-line customer order and return all stock atomically', async () => {
  const database = db('manager');
  await setDoc(doc(database, 'admin_requests/manager'), adminRequest('manager'));
  await updateDoc(doc(adminDb(), 'admin_requests/manager'), reviewRequest('approved'));
  const order = orderData('alice','delegated-cancel',5);
  await checkout(db('alice'),order);
  const batch = writeBatch(database);
  batch.update(doc(database,'orders/delegated-cancel'),{status:'Đã hủy',cancelledAt:serverTimestamp()});
  for (const id of Object.keys(order.items)) batch.update(doc(database,'products',id),
    {stock:10,lastOrderId:'delegated-cancel',updatedAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
});
