const test = require('node:test');
const assert = require('node:assert');
const { createServer } = require('../src');

test('/privacy serves the privacy policy page', async () => {
  const { httpServer, io } = createServer();
  await new Promise(r => httpServer.listen(0, r));
  try {
    const res = await fetch(`http://localhost:${httpServer.address().port}/privacy`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /text\/html/);
    const html = await res.text();
    assert.match(html, /Privacy Policy/);
    assert.match(html, /player name/);
    assert.match(html, /Delete my data on this phone/);
  } finally {
    io.close();
    httpServer.close();
  }
});
