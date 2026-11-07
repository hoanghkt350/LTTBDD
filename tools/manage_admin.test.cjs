const {test} = require('node:test');
const assert = require('node:assert/strict');
const {changeAdmin} = require('./manage_admin.cjs');

function fixture(user = {localId:'alice',email:'alice@gmail.com',emailVerified:false,customAttributes:'{"otherFeature":true}'}) {
  const writes = [];
  const request = async (url, options) => {
    if (url.endsWith('accounts:lookup')) return {users:user ? [user] : []};
    writes.push(options.body);
    return {};
  };
  return {request, writes};
}
test('grants only the named existing account, preserves claims and does not verify its email', async () => {
  const f = fixture();
  const result = await changeAdmin({...f,project:'demo-pawpals',email:'alice@gmail.com',enabled:true});
  assert.deepEqual(JSON.parse(f.writes[0].customAttributes), {otherFeature:true,admin:true});
  assert.deepEqual(Object.keys(f.writes[0]).sort(), ['customAttributes','localId']);
  assert.equal(result.emailVerified, false);
});
test('revoke removes only the admin claim', async () => {
  const f = fixture({localId:'alice',email:'alice@gmail.com',customAttributes:'{"admin":true,"otherFeature":true}'});
  await changeAdmin({...f,project:'demo-pawpals',email:'alice@gmail.com',enabled:false});
  assert.deepEqual(JSON.parse(f.writes[0].customAttributes), {otherFeature:true});
});
test('unknown, disabled or mismatched accounts cannot receive privileges', async () => {
  for (const user of [null,{localId:'bob',email:'bob@gmail.com'},{localId:'alice',email:'alice@gmail.com',disabled:true}]) {
    const f = fixture(user);
    await assert.rejects(changeAdmin({...f,project:'demo-pawpals',email:'alice@gmail.com',enabled:true}));
    assert.equal(f.writes.length, 0);
  }
});
