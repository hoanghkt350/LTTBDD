// Owner-only CLI. Never ship this script or OAuth credentials in the Flutter app.
const { adminClient } = require('./firebase_admin.cjs');

async function changeAdmin({ request, project, email, enabled }) {
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project)) throw new Error('Invalid project ID.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Invalid email.');
  if (typeof enabled !== 'boolean') throw new Error('An explicit grant or revoke action is required.');
  const endpoint = 'https://identitytoolkit.googleapis.com/v1/projects/' + project;
  const lookup = await request(endpoint + '/accounts:lookup', {method:'POST', body:{email:[email]}});
  const user = lookup.users?.find(item => item.email?.toLowerCase() === email.toLowerCase());
  if (!user) throw new Error('Account not found. Register this email in PawPals first.');
  if (enabled && user.disabled) throw new Error('Cannot grant an administrator role to a disabled account.');
  const claims = JSON.parse(user.customAttributes || '{}');
  if (enabled) claims.admin = true;
  else delete claims.admin;
  const attributes = JSON.stringify(claims);
  if (Buffer.byteLength(attributes, 'utf8') > 1000) throw new Error('Custom claims exceed the Firebase limit.');
  await request(endpoint + '/accounts:update', {method:'POST', body:{localId:user.localId, customAttributes:attributes}});
  // Revocation also removes a grant approved inside the app.
  if (!enabled) {
    const document = 'https://firestore.googleapis.com/v1/projects/' + project
      + '/databases/(default)/documents/admin_requests/' + encodeURIComponent(user.localId);
    let existing;
    try { existing = await request(document); }
    catch (error) { if (error.status !== 404) throw error; }
    if (existing?.fields?.status?.stringValue === 'approved') {
      const now = new Date().toISOString();
      const fields = {
        status:{stringValue:'revoked'}, updatedAt:{timestampValue:now}, reviewedAt:{timestampValue:now},
        reviewedBy:{stringValue:'project-owner-cli'},
        reviewNote:{stringValue:'Chủ dự án đã thu hồi quyền qua công cụ quản trị.'},
      };
      const mask = Object.keys(fields).map(key => 'updateMask.fieldPaths=' + key).join('&');
      await request(document + '?' + mask + '&currentDocument.updateTime=' + encodeURIComponent(existing.updateTime),
        {method:'PATCH',body:{fields}});
    }
  }
  return {email:user.email, uid:user.localId, admin:enabled, emailVerified:user.emailVerified === true};
}

async function main() {
  const [project, action, email] = process.argv.slice(2);
  if (!['grant','revoke'].includes(action) || !email) {
    throw new Error('Usage: node tools/manage_admin.cjs PROJECT grant|revoke EMAIL');
  }
  const request = await adminClient(project);
  const result = await changeAdmin({request, project, email, enabled:action === 'grant'});
  console.log(JSON.stringify(result, null, 2));
  console.log('Sign in again or refresh account permissions in PawPals to receive the updated role.');
}

if (require.main === module) main().catch(error => {console.error(error.message); process.exitCode=1;});
module.exports = {changeAdmin};
