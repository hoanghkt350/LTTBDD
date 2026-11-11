const { initializeTestEnvironment }=require('@firebase/rules-unit-testing');
const { doc,setDoc }=require('firebase/firestore');
const { execFileSync, spawn }=require('node:child_process');
const fs=require('node:fs');
const path=require('node:path');

async function main() {
  const env=await initializeTestEnvironment({projectId:'demo-pawpals',firestore:{host:'127.0.0.1',port:8180,rules:fs.readFileSync(path.join(__dirname,'..','firestore.rules'),'utf8')}});
  try {
    // The preceding rules tests use deliberately minimal product fixtures.
    // Reset only this demo emulator namespace before loading the full app catalog.
    await env.clearFirestore();
    const catalog=JSON.parse(fs.readFileSync(__dirname+'/catalog.json','utf8'));
    await env.withSecurityRulesDisabled(async ctx=>{
      for(const p of catalog) await setDoc(doc(ctx.firestore(),'products',p.id),p);
    });
  } finally { await env.cleanup(); }
  const target=process.argv.includes('--features') ? 'integration_test/features_test.dart' : 'integration_test/backend_test.dart';
  const command=`flutter test ${target} --no-pub -d emulator-5554 --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 --dart-define=FIRESTORE_EMULATOR_PORT=8180 --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9199`;
  const sdk=process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME || path.join(process.env.LOCALAPPDATA,'Android','sdk');
  const adb=path.join(sdk,'platform-tools','adb.exe');
  // A device can appear in adb before Android's package service is ready.
  let ready=false;
  for(let attempt=0;attempt<120;attempt++) {
    try {
      const boot=execFileSync(adb,['-s','emulator-5554','shell','getprop','sys.boot_completed'],{encoding:'utf8',stdio:['ignore','pipe','ignore'],timeout:5000}).trim();
      const framework=execFileSync(adb,['-s','emulator-5554','shell','pm','path','android'],{encoding:'utf8',stdio:['ignore','pipe','ignore'],timeout:5000});
      if(boot==='1' && framework.startsWith('package:')) { ready=true; break; }
    } catch (_) { /* Wait for the emulator to finish starting. */ }
    await new Promise(resolve=>setTimeout(resolve,1000));
  }
  if(!ready) throw new Error('Android emulator-5554 did not finish booting.');
  // Grant only the app's notification permission on the dedicated test emulator,
  // once the APK with the permission declaration has been installed.
  const grant=setInterval(()=>{
    try {
      execFileSync(adb,['-s','emulator-5554','shell','pm','grant','vn.edu.hutech.pawpals_app','android.permission.POST_NOTIFICATIONS'],{stdio:'ignore'});
      clearInterval(grant);
    } catch (_) { /* APK is not installed yet. */ }
  },1000);
  try {
    await new Promise((resolve,reject)=>{
      const child=spawn(process.env.ComSpec || 'cmd.exe',['/d','/s','/c',command],{stdio:'inherit',env:{...process.env,DEBUG:''}});
      child.on('error',reject);
      child.on('close',code=>code===0 ? resolve() : reject(new Error('Flutter integration test failed.')));
    });
  } finally { clearInterval(grant); }
}
main().catch(()=>{console.error('Android integration test failed.'); process.exitCode=1;});
