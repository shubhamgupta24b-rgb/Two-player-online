const test = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const http = require('node:http');
const { createServer } = require('../src/index');

const cwd = require('node:path').resolve(__dirname, '..');

test('health endpoint responds with ok=true', async t => {
  const srv = createServer();
  await new Promise(r => srv.httpServer.listen(0, r));
  t.after(() => { srv.io.close(); srv.httpServer.close(); });
  const port = srv.httpServer.address().port;
  const body = await new Promise((resolve, reject) => {
    http.get(`http://127.0.0.1:${port}/health`, res => {
      let data = '';
      res.on('data', c => { data += c; });
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
  assert.deepStrictEqual(JSON.parse(body), { ok: true });
});

test('production rejects dev auth unless explicitly allowed', () => {
  const blocked = spawnSync(process.execPath, ['-e', "require('./src/config')"], {
    cwd,
    env: { ...process.env, NODE_ENV: 'production', AUTH_MODE: 'dev' },
  });
  assert.notStrictEqual(blocked.status, 0);

  const allowed = spawnSync(process.execPath, ['-e', "require('./src/config')"], {
    cwd,
    env: { ...process.env, NODE_ENV: 'production', AUTH_MODE: 'dev', ALLOW_DEV_AUTH: 'true' },
  });
  assert.strictEqual(allowed.status, 0);
});
