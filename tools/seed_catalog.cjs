// Use the locally authenticated Firebase CLI. No service-account key is needed.
// Existing products are intentionally left unchanged (including their stock).
const { adminClient } = require('./firebase_admin.cjs');
const fs = require('node:fs');
const path = require('node:path');

async function main() {
  const project = process.argv[2];
  if(!project || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project) || project.startsWith('demo-')) {
    throw Error('Usage: node tools/seed_catalog.cjs YOUR_REAL_PROJECT_ID');
  }
  const api = await adminClient(project);
  function value(v) {
    if(v===null) return {nullValue:null};
    if(typeof v==='boolean') return {booleanValue:v};
    if(typeof v==='number') return Number.isInteger(v) ? {integerValue:String(v)} : {doubleValue:v};
    if(typeof v==='string') return {stringValue:v};
    if(Array.isArray(v)) return {arrayValue:{values:v.map(value)}};
    return {mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,value(x)]))}};
  }
  const catalog=JSON.parse(fs.readFileSync(path.join(__dirname,'catalog.json'),'utf8'));
  const base='https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)/documents';
  for(const product of catalog) {
    const url=base+'/products/'+product.id;
    try {
      await api(url);
      console.log('Kept existing product: '+product.id);
      continue;
    } catch(error) { if(error.status!==404) throw error; }
    const fields=Object.fromEntries(Object.entries(product).map(([k,v])=>[k,value(v)]));
    await api(url+'?currentDocument.exists=false',{method:'PATCH',body:{fields}});
    console.log('Created product: '+product.id);
  }
  console.log('Catalog ready. Prices and images are demonstration data for the coursework.');
}
main().catch(error=>{ console.error(error.message || 'Catalog import failed.'); process.exitCode=1; });
