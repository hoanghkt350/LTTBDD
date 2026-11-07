// Verify deployed roles using only temporary accounts and an archived test product.
const fs = require('node:fs');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {initializeApp,deleteApp} = require('firebase/app');
const {getAuth,createUserWithEmailAndPassword} = require('firebase/auth');
const {getFirestore,doc,setDoc,updateDoc,getDocFromServer,serverTimestamp,terminate} = require('firebase/firestore');
const {adminClient} = require('./firebase_admin.cjs');

async function main() {
  const project = process.argv[2];
  const config = JSON.parse(fs.readFileSync('android/app/google-services.json','utf8'));
  if (project !== config.project_info.project_id || project.startsWith('demo-')) throw new Error('Specify the matching real project.');
  const client = config.client.find(item => item.client_info.android_client_info.package_name === 'vn.edu.hutech.pawpals_app');
  const options = {projectId:project,appId:client.client_info.mobilesdk_app_id,apiKey:client.api_key[0].current_key};
  const request = await adminClient(project);
  const authEndpoint = 'https://identitytoolkit.googleapis.com/v1/projects/'+project;
  const firestoreEndpoint = 'https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)/documents/';
  const run = 'role-check-'+crypto.randomUUID().replaceAll('-','');
  const apps = [], accounts = [], paths = [], checks = [];
  const pass = label => {checks.push(label);console.log('PASS: '+label);};
  async function temporaryAccount(label, admin) {
    const app = initializeApp(options,run+'-'+label); apps.push(app);
    const user = (await createUserWithEmailAndPassword(getAuth(app),run+'-'+label+'@example.invalid','PawPals!Aa1'+crypto.randomBytes(24).toString('base64url'))).user;
    accounts.push(user.uid);
    await request(authEndpoint+'/accounts:update',{method:'POST',body:{localId:user.uid,emailVerified:true,customAttributes:JSON.stringify({admin})}});
    await user.reload(); await user.getIdToken(true);
    return {app,user,db:getFirestore(app)};
  }
  const denied = promise => assert.rejects(promise,error => error.code === 'permission-denied');
  let failure;
  try {
    const customer = await temporaryAccount('user',false);
    const manager = await temporaryAccount('admin',true);
    const profilePath = 'users/'+customer.user.uid, productPath = 'products/'+run;
    paths.push(profilePath,productPath);
    const profile = {uid:customer.user.uid,email:customer.user.email,displayName:'Temporary role check',membershipLevel:'STANDARD'};
    await setDoc(doc(customer.db,profilePath),profile);
    await denied(setDoc(doc(customer.db,profilePath),{...profile,role:'admin'}));
    const product = {id:run,name:'Kiểm tra phân quyền (tự xóa)',category:'FOOD',petTarget:'ALL',
      price:100000,originalPrice:100000,stock:0,imageUrl:'',description:'Temporary archived check',
      isActive:false,isFeatured:false,updatedAt:serverTimestamp()};
    await denied(setDoc(doc(customer.db,productPath),product));
    await setDoc(doc(manager.db,productPath),product);
    await updateDoc(doc(manager.db,productPath),{price:90000,updatedAt:serverTimestamp()});
    assert.equal((await getDocFromServer(doc(manager.db,productPath))).data().price,90000);
    pass('Only an administrator can create/edit products; profile fields cannot elevate a user');
    assert.equal((await getDocFromServer(doc(manager.db,profilePath))).data().uid,customer.user.uid);
    await denied(getDocFromServer(doc(manager.db,profilePath+'/pets/1')));
    await denied(getDocFromServer(doc(manager.db,'emailVerificationChallenges/'+customer.user.uid)));
    pass('Admin can read customer profiles while private pets and OTPs remain protected');
    await request(authEndpoint+'/accounts:update',{method:'POST',body:{localId:manager.user.uid,customAttributes:'{}'}});
    await manager.user.getIdToken(true);
    await denied(updateDoc(doc(manager.db,productPath),{price:80000,updatedAt:serverTimestamp()}));
    pass('Revoked admin claim is rejected after token refresh');
  } catch (error) { failure = error; }
  finally {
    const errors = [];
    for (const path of paths.reverse()) {
      try {await request(firestoreEndpoint+path,{method:'DELETE'});} catch (error) {if (error.status !== 404) errors.push(path);}
    }
    for (const uid of accounts) {
      try {await request('https://identitytoolkit.googleapis.com/v1/accounts:delete',{method:'POST',body:{targetProjectId:project,localId:uid}});} catch (_) {errors.push('temporary account '+uid);}
    }
    for (const app of apps) {await terminate(getFirestore(app));await deleteApp(app);}
    if (errors.length) throw new Error('Cleanup incomplete: '+errors.join(', '));
    console.log('PASS: temporary accounts and test data removed');
  }
  if (failure) throw failure;
  fs.mkdirSync('build',{recursive:true});
  fs.writeFileSync('build/admin-verification.json',JSON.stringify({projectId:project,verifiedAt:new Date().toISOString(),checks,cleanup:true},null,2));
}
main().catch(error => {console.error(error.message);process.exitCode=1;});
