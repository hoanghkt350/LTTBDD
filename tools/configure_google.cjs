'use strict';

// Uses the owner's existing Firebase CLI session; never prints OAuth secrets.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { adminClient } = require('./firebase_admin.cjs');

async function main() {
  const sdkPath = path.join(__dirname, '..', 'android', 'app', 'google-services.json');
  const sdk = JSON.parse(fs.readFileSync(sdkPath, 'utf8'));
  const project = sdk.project_info.project_id;
  const appId = sdk.client[0].client_info.mobilesdk_app_id;
  const request = await adminClient(project);
  const base = `https://firebase.googleapis.com/v1beta1/projects/${project}/androidApps/${appId}`;
  const keytool = process.env.JAVA_HOME
    ? path.join(process.env.JAVA_HOME, 'bin', 'keytool.exe')
    : path.join(process.env.ProgramFiles, 'Android', 'Android Studio', 'jbr', 'bin', 'keytool.exe');
  const keystore = path.join(process.env.USERPROFILE, '.android', 'debug.keystore');
  const fingerprintText = execFileSync(keytool, [
    '-list', '-v', '-keystore', keystore, '-alias', 'androiddebugkey', '-storepass', 'android',
  ], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  const fingerprints = [
    { type: 'SHA_1', hash: fingerprintText.match(/SHA1:\s*([A-F0-9:]+)/i)?.[1] },
    { type: 'SHA_256', hash: fingerprintText.match(/SHA256:\s*([A-F0-9:]+)/i)?.[1] },
  ];
  if (fingerprints.some(row => !row.hash)) throw new Error('Cannot read Android signing fingerprints.');
  const normalize = value => value.replace(/:/g, '').toUpperCase();
  const existing = (await request(`${base}/sha`)).certificates || [];
  for (const fingerprint of fingerprints) {
    if (!existing.some(row => normalize(row.shaHash) === normalize(fingerprint.hash))) {
      await request(`${base}/sha`, {
        method: 'POST', body: { shaHash: fingerprint.hash, certType: fingerprint.type },
      });
    }
  }
  let provider;
  try {
    provider = await request(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/defaultSupportedIdpConfigs/google.com`);
  } catch (error) {
    if (error.status !== 404) throw error;
  }
  if (!provider?.enabled || !provider.clientId) {
    console.log(JSON.stringify({ project, androidSigningRegistered: true, googleEnabled: false, sdkUpdated: false }));
    console.log(`Enable Google and choose a support email at https://console.firebase.google.com/project/${project}/authentication/providers then run this command again.`);
    process.exitCode = 2;
    return;
  }
  const response = await request(`${base}/config`);
  const contents = Buffer.from(response.configFileContents, 'base64').toString('utf8');
  const refreshed = JSON.parse(contents);
  const client = refreshed.client.find(row => row.client_info.mobilesdk_app_id === appId);
  if (!client?.oauth_client?.some(row => row.client_type === 3)) {
    throw new Error('Firebase SDK configuration does not yet contain a web OAuth client. Retry after enabling Google.');
  }
  fs.writeFileSync(sdkPath, contents);
  console.log(JSON.stringify({ project, androidSigningRegistered: true, googleEnabled: true, sdkUpdated: true }));
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
