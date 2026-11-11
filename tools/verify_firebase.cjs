// Live smoke check using temporary users and an isolated temporary product.
// Only resources created by this run are removed in finally. Existing stock is untouched.
const fs = require('node:fs');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut } = require('firebase/auth');
const { getFirestore, doc, setDoc, getDocFromServer, getDocsFromServer,
  collection, query, where, runTransaction, serverTimestamp, terminate } = require('firebase/firestore');
const { adminClient } = require('./firebase_admin.cjs');

async function main() {
  const project = process.argv[2];
  const config = JSON.parse(fs.readFileSync(process.argv[3] || 'android/app/google-services.json', 'utf8'));
  if(project !== config.project_info.project_id || project.startsWith('demo-')) throw Error('A matching real Firebase project is required.');
  const client = config.client.find(c => c.client_info.android_client_info.package_name === 'vn.edu.hutech.pawpals_app');
  if(!client || client.api_key[0].current_key.includes('Example')) throw Error('PawPals Firebase configuration is invalid.');
  const api = await adminClient(project);
  const root = 'https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)/documents/';
  const run = 'pawpals-check-'+crypto.randomUUID().replaceAll('-','');
  const apps = [], accounts = [], ownedDocs = new Set();
  const checks = [];
  const options = {projectId:project,appId:client.client_info.mobilesdk_app_id,apiKey:client.api_key[0].current_key};
  const pass = label => { checks.push(label); console.log('PASS: '+label); };
  const checkDenied = async promise => {
    await assert.rejects(promise, error => error.code === 'permission-denied');
  };
  function fields(data) {
    const value = v => v === null ? {nullValue:null}
      : typeof v === 'string' ? {stringValue:v}
      : typeof v === 'number' ? {integerValue:String(v)}
      : typeof v === 'boolean' ? {booleanValue:v} : {mapValue:{fields:fields(v)}};
    return Object.fromEntries(Object.entries(data).map(([key,v])=>[key,value(v)]));
  }
  let failure;
  try {
    const appA = initializeApp(options,run+'-a'); apps.push(appA);
    const authA = getAuth(appA), dbA = getFirestore(appA);
    const email = run+'@example.invalid', password = 'PawPals!Aa1'+crypto.randomBytes(24).toString('base64url');
    const userA = (await createUserWithEmailAndPassword(authA,email,password)).user;
    accounts.push(userA.uid);
    await signOut(authA);
    await assert.rejects(signInWithEmailAndPassword(authA,email,'WrongPassword!123'),
      error => ['auth/invalid-credential','auth/wrong-password'].includes(error.code));
    await signInWithEmailAndPassword(authA,email,password);
    pass('Firebase Auth register, sign-in and wrong-password rejection');

    assert.equal(userA.emailVerified, false);
    pass('Email session works without OTP or email verification');

    const userPath = 'users/'+userA.uid;
    ownedDocs.add(userPath);
    await setDoc(doc(dbA,userPath),{uid:userA.uid,email,displayName:'PawPals connection check',
      phoneNumber:null,address:null,avatarUrl:null,membershipLevel:'STANDARD'});
    const petPath = userPath+'/pets/1', recordPath = userPath+'/health_records/2', reminderPath = userPath+'/reminders/3';
    for(const p of [petPath,recordPath,reminderPath]) ownedDocs.add(p);
    await setDoc(doc(dbA,petPath),{id:1,server_id:null,name:'Connection check',species:'Chó',breed:'Test',gender:'Đực',
      birth_date:'2023-01-01',weight:5,microchip_id:null,avatar_cloud_url:null,is_synced:0,updatedAt:serverTimestamp()});
    await setDoc(doc(dbA,recordPath),{id:2,pet_id:1,record_type:'CHECKUP',title:'Connection check',
      administered_date:'2026-11-06',next_due_date:null,veterinarian:'',clinic_name:'',notes:'Temporary test',cost:0,updatedAt:serverTimestamp()});
    await setDoc(doc(dbA,reminderPath),{id:3,pet_id:1,title:'Connection check',reminder_time:'23:59',repeat_interval:'DAILY',
      notification_id:3,is_active:0,updatedAt:serverTimestamp()});
    for(const p of [userPath,petPath,recordPath,reminderPath]) assert.equal((await getDocFromServer(doc(dbA,p))).exists(),true);
    const catalog = await getDocsFromServer(collection(dbA,'products'));
    assert(catalog.size >= 6);
    pass('Live Firestore profile, pet, health, reminder writes/reads and product reads');

    // An isolated test product avoids reserving or changing any existing product.
    const productPath='products/'+run, orderPath='orders/'+run;
    ownedDocs.add(productPath); ownedDocs.add(orderPath);
    await api(root+productPath+'?currentDocument.exists=false',{method:'PATCH',body:{fields:fields({
      id:run,name:'Kiểm tra kết nối (tự xóa)',category:'ACCESSORY',petTarget:'ALL',price:100000,originalPrice:100000,
      stock:2,imageUrl:'',description:'Temporary connection check',isFeatured:false,
    })}});
    const productRef=doc(dbA,productPath), orderRef=doc(dbA,orderPath);
    async function checkout() {
      await runTransaction(dbA,async tx=>{
        if((await tx.get(orderRef)).exists()) return;
        const product=(await tx.get(productRef)).data();
        tx.update(productRef,{stock:product.stock-1,lastOrderId:run,updatedAt:serverTimestamp()});
        tx.set(orderRef,{orderId:run,userId:userA.uid,
          items:{[run]:{name:product.name,price:100000,quantity:1,imageUrl:''}},
          recipient:{name:'Kiểm tra kết nối',phone:'0900000000',address:'Dữ liệu kiểm thử - không giao hàng'},
          subtotal:100000,discountAmount:10000,shippingFee:25000,totalAmount:115000,voucher:'PAWPALS10',
          status:'Chờ xác nhận',paymentMethod:'COD',createdAt:serverTimestamp()});
      },{maxAttempts:3});
    }
    await checkout(); await checkout();
    assert.equal((await getDocFromServer(productRef)).data().stock,1);
    assert.equal((await getDocsFromServer(query(collection(dbA,'orders'),where('userId','==',userA.uid)))).size,1);
    await runTransaction(dbA,async tx=>{
      const order=(await tx.get(orderRef)).data();
      const product=(await tx.get(productRef)).data();
      assert.equal(order.status,'Chờ xác nhận');
      tx.update(productRef,{stock:product.stock+1,lastOrderId:run,updatedAt:serverTimestamp()});
      tx.update(orderRef,{status:'Đã hủy',cancelledAt:serverTimestamp()});
    });
    assert.equal((await getDocFromServer(productRef)).data().stock,2);
    pass('Live checkout, idempotent retry, voucher, cancellation and stock return');

    const appB=initializeApp(options,run+'-b'); apps.push(appB);
    const dbB=getFirestore(appB);
    await checkDenied(getDocFromServer(doc(dbB,petPath)));
    const userB=(await createUserWithEmailAndPassword(getAuth(appB),run+'-b@example.invalid',password)).user;
    accounts.push(userB.uid);
    await api('https://identitytoolkit.googleapis.com/v1/projects/'+project+'/accounts:update', {
      method:'POST',body:{localId:userB.uid,emailVerified:true},
    });
    await userB.reload();
    await userB.getIdToken(true);
    await checkDenied(getDocFromServer(doc(dbB,userPath)));
    await checkDenied(getDocFromServer(doc(dbB,petPath)));
    await checkDenied(getDocFromServer(doc(dbB,orderPath)));
    pass('Unauthenticated and cross-account access are rejected on the real project');
  } catch(error) { failure=error; }
  finally {
    const cleanupErrors=[];
    // Every document and account here was created by this specific random run.
    for(const p of [...ownedDocs].reverse()) {
      try { await api(root+p,{method:'DELETE'}); }
      catch(error) { if(error.status!==404) cleanupErrors.push(p); }
    }
    for(const uid of accounts) {
      try { await api('https://identitytoolkit.googleapis.com/v1/accounts:delete',{
        method:'POST',body:{targetProjectId:project,localId:uid}}); }
      catch(_) { cleanupErrors.push('temporary Auth account '+uid); }
    }
    for(const app of apps) { await terminate(getFirestore(app)); await deleteApp(app); }
    if(cleanupErrors.length) throw Error('Cleanup incomplete for: '+cleanupErrors.join(', '));
    console.log('PASS: temporary test accounts and data removed');
  }
  if(failure) throw failure;
  fs.mkdirSync('build',{recursive:true});
  fs.writeFileSync('build/firebase-verification.json',JSON.stringify({projectId:project,verifiedAt:new Date().toISOString(),checks,cleanup:true},null,2));
  console.log('Verified project: '+project);
}
main().catch(error=>{ console.error(error.message || 'Live Firebase check failed.'); process.exitCode=1; });
