const {spawn}=require('node:child_process');

async function run(command) {
  await new Promise((resolve,reject)=>{
    const child=spawn(process.env.ComSpec || 'cmd.exe',['/d','/s','/c',command],{stdio:'inherit'});
    child.on('error',reject);
    child.on('close',code=>code===0 ? resolve() : reject(new Error('Emulator checks failed: '+command)));
  });
}
(async()=>{
  // Rules tests clear the demo database. They must finish before seeding and Android tests.
  await run('npm --prefix tools run test:rules');
  await run('node tools/android_smoke.cjs');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
