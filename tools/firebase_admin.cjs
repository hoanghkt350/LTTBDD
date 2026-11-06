// Owner-only setup utilities. OAuth credentials stay in memory and are never logged.
const { execFileSync } = require('node:child_process');

function cliJson(command) {
  const options = {encoding:'utf8',stdio:['ignore','pipe','pipe'],env:{...process.env,DEBUG:''}};
  let output;
  for(let attempt=0;attempt<3;attempt++) {
    try {
      output = process.platform === 'win32'
        ? execFileSync(process.env.ComSpec || 'cmd.exe',['/d','/s','/c','firebase '+command],options)
        : execFileSync('firebase',command.split(' '),options);
      break;
    } catch(error) {
      // Retry only a native Windows process crash, never a rejected login or API call.
      // Both callers are read-only CLI commands.
      if(process.platform !== 'win32' || (Number(error.status) >>> 0) < 0x80000000 || attempt===2) throw error;
    }
  }
  const parsed = JSON.parse(output.slice(output.indexOf('{')));
  if(parsed.status !== 'success') throw new Error('Firebase CLI failed.');
  return parsed.result;
}

async function adminClient(project) {
  if(!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project)) throw new Error('Invalid Firebase project ID.');
  let token;
  try {
    const projects = cliJson('projects:list --json'); // Refresh the locally cached OAuth token.
    if(!projects.some(p => p.projectId === project)) throw new Error('Project not accessible.');
    const accounts = cliJson('login:list --json');
    token = accounts.find(a => a.tokens?.access_token)?.tokens.access_token;
    if(!token) throw new Error('No Firebase CLI account.');
  } catch (error) {
    const reason = error instanceof SyntaxError ? 'CLI response could not be parsed'
      : error.status ? 'CLI exit '+error.status : error.name;
    throw new Error('Cannot read the Firebase CLI session ('+reason+'). Check the connection and CLI login.');
  }
  return async function request(url, options = {}) {
    const response = await fetch(url, {
      method:options.method || 'GET',
      headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},
      ...(options.body === undefined ? {} : {body:JSON.stringify(options.body)}),
      signal:AbortSignal.timeout(30000),
    });
    const raw = await response.text();
    const data = raw ? JSON.parse(raw) : {};
    if(!response.ok) {
      const error = new Error('HTTP '+response.status+': '+(data.error?.message || response.statusText));
      error.status = response.status;
      throw error;
    }
    return data;
  };
}
module.exports = {adminClient};
