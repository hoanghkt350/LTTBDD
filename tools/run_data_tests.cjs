// Run from the repository root: node tools/run_data_tests.cjs
// Requires the Android test emulator emulator-5554 and an owner Firebase CLI session.
const fs=require('node:fs');
const path=require('node:path');
const {spawn}=require('node:child_process');

async function main() {
  const root=path.resolve(__dirname,'..');
  process.chdir(root);
  const project=JSON.parse(fs.readFileSync('.firebaserc','utf8')).projects.default;
  const config=JSON.parse(fs.readFileSync('android/app/google-services.json','utf8'));
  if(!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project) || config.project_info.project_id!==project) {
    throw new Error('The default Firebase project must match google-services.json.');
  }
  const resume=process.argv.includes('--retry-failed') && fs.existsSync('build/data-tests/latest.json')
    ? JSON.parse(fs.readFileSync('build/data-tests/latest.json','utf8')) : null;
  if(resume && resume.projectId!==project) throw new Error('Cannot reuse results from a different Firebase project.');
  const attemptAt=new Date().toISOString();
  const startedAt=resume?.startedAt || attemptAt;
  const runDir=path.join('build','data-tests',attemptAt.replaceAll(':','-').replaceAll('.','-'));
  fs.mkdirSync(runDir,{recursive:true});
  const stages=[];
  async function execute(name,command,args,extraEnv={}) {
    if(resume && ['flutter-unit','firebase-live','emulator-checks','android-live'].includes(name)) {
      const previous=resume.stages.find(stage=>stage.name===name && stage.passed);
      if(previous && fs.existsSync(previous.log)) {
        const result={...previous,reused:true,output:fs.readFileSync(previous.log,'utf8')};
        stages.push(result);
        console.log('\n=== '+name+' (previous PASS retained) ===');
        return result;
      }
    }
    const log=path.join(runDir,name+'.log');
    console.log('\n=== '+name+' ===');
    const file=fs.createWriteStream(log);
    let output='';
    const started=Date.now();
    let exitCode;
    try {
      exitCode=await new Promise((resolve,reject)=>{
        const child=spawn(command,args,{cwd:root,env:{...process.env,DEBUG:'',...extraEnv},stdio:['ignore','pipe','pipe']});
        const write=data=>{const text=data.toString();output+=text;file.write(text);process.stdout.write(text);};
        child.stdout.on('data',write);child.stderr.on('data',write);
        child.on('error',reject);child.on('close',resolve);
      });
    } catch(error) { output+='\n'+error.message;file.write('\n'+error.message);exitCode=-1; }
    await new Promise(resolve=>file.end(resolve));
    const result={name,passed:exitCode===0,exitCode,durationSeconds:Math.round((Date.now()-started)/1000),log,output};
    stages.push(result);
    return result;
  }
  const shell=(name,command)=>execute(name,process.env.ComSpec || 'cmd.exe',['/d','/s','/c',command]);
  await shell('flutter-unit','flutter test --no-pub --reporter expanded');
  await shell('firebase-live','node tools/verify_firebase.cjs '+project);
  const firebaseCli=process.env.PATH.split(path.delimiter)
    .map(directory=>path.join(directory,'node_modules','firebase-tools','lib','bin','firebase.js'))
    .find(candidate=>fs.existsSync(candidate));
  if(!firebaseCli) throw new Error('Firebase CLI Node entry point was not found on PATH.');
  let reuseFirestore=false;
  try {
    // Windows can leave the owned Java emulator alive after the CLI exits.
    // Reuse its explicitly isolated demo namespace instead of stopping processes.
    const response=await fetch('http://127.0.0.1:8180/v1/projects/demo-pawpals/databases/(default)/documents:listCollectionIds',{
      method:'POST',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(1500)});
    const data=await response.json();
    reuseFirestore=response.ok && (data.collectionIds===undefined || Array.isArray(data.collectionIds));
  } catch(_) { /* No compatible local Firestore emulator is running. */ }
  if(reuseFirestore) console.log('Reusing the local Firestore demo emulator on port 8180.');
  // Pass the emulator script as one argument, without nested cmd.exe quoting.
  await execute('emulator-checks',process.execPath,[firebaseCli,'emulators:exec','--config','firebase.integration.json',
    '--project','demo-pawpals','--only',reuseFirestore ? 'auth' : 'firestore,auth','node tools/run_emulator_checks.cjs'],
    reuseFirestore ? {FIRESTORE_EMULATOR_HOST:'127.0.0.1:8180'} : {});
  await shell('android-live','flutter test integration_test/live_firebase_test.dart --no-pub -d emulator-5554 --dart-define=LIVE_FIREBASE_PROJECT='+project);

  // Return the test device to the normal application, rather than leaving a test APK installed.
  const touchedAndroid=stages.some(stage=>!stage.reused && ['emulator-checks','android-live'].includes(stage.name)
    && stage.output.includes("Running Gradle task 'assembleDebug'"));
  const build=touchedAndroid ? await shell('restore-build','flutter build apk --debug --no-pub') : null;
  if(build?.passed) {
    const sdk=process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME || path.join(process.env.LOCALAPPDATA,'Android','sdk');
    const adb=path.join(sdk,'platform-tools','adb.exe');
    const install=await execute('restore-install',adb,['-s','emulator-5554','install','-r',path.join(root,'build/app/outputs/flutter-apk/app-debug.apk')]);
    if(install.passed) await execute('restore-launch',adb,['-s','emulator-5554','shell','am','start','-n','vn.edu.hutech.pawpals_app/.MainActivity']);
  }
  function flutterCount(name) {
    const result=stages.find(s=>s.name===name);
    if(!result?.passed) return 0;
    return Number([...result.output.matchAll(/\+(\d+): All tests passed!/g)].at(-1)?.[1] || 0);
  }
  const emulator=stages.find(s=>s.name==='emulator-checks');
  const counts={flutterUnit:flutterCount('flutter-unit'),firestoreRules:emulator?.passed ? Number(emulator.output.match(/tests (\d+)/)?.[1] || 0) : 0,
    androidEmulator:flutterCount('emulator-checks'),androidLive:flutterCount('android-live')};
  let cloud;
  if(stages.find(s=>s.name==='firebase-live')?.passed) {
    cloud=JSON.parse(fs.readFileSync('build/firebase-verification.json','utf8'));
    if(cloud.projectId!==project || cloud.verifiedAt<startedAt) throw new Error('The Firebase verification report is stale.');
  }
  const report={projectId:project,startedAt,finishedAt:new Date().toISOString(),passed:stages.every(s=>s.passed),
    counts,totalTests:Object.values(counts).reduce((a,b)=>a+b,0),liveDataChecks:cloud?.checks || [],temporaryCloudDataRemoved:cloud?.cleanup===true,
    stages:stages.map(({output,...summary})=>summary)};
  const json=JSON.stringify(report,null,2);
  fs.writeFileSync(path.join(runDir,'report.json'),json);
  fs.writeFileSync('build/data-tests/latest.json',json);
  const lines=['# PawPals — kết quả kiểm thử dữ liệu','',
    'Project: '+project,'','Kết quả: **'+(report.passed ? 'PASS' : 'FAIL')+'**','',
    '| Nhóm | Số test qua |','| --- | ---: |',
    '| Flutter | '+counts.flutterUnit+' |','| Firestore Rules | '+counts.firestoreRules+' |',
    '| Android với emulator Firebase | '+counts.androidEmulator+' |','| Android với Firebase thật | '+counts.androidLive+' |','',
    'Tổng: '+report.totalTests+' test.','',
    'Dọn tài khoản/dữ liệu kiểm thử trên Firebase thật: '+(report.temporaryCloudDataRemoved ? 'đã hoàn tất' : 'chưa xác nhận')+'.','',
    ...report.liveDataChecks.map(check=>'- '+check),'',
    'Báo cáo JSON và log từng bước: '+runDir.replaceAll('\\','/')+'.'];
  fs.writeFileSync('build/data-tests/latest.md',lines.join('\n'));
  console.log('\nDATA TESTS: '+(report.passed ? 'PASS' : 'FAIL')+' — '+report.totalTests+' tests. Report: build/data-tests/latest.md');
  if(!report.passed) process.exitCode=1;
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
