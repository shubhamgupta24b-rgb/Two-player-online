const test = require('node:test');
const assert = require('node:assert');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');
const { createRajaMantri, pointsFor, ROLES } = require('../src/games/raja_mantri');

const room = { players: ['a', 'b', 'c', 'd'].map(u => ({ userId: u, username: u.toUpperCase() })) };
// a = Raja, b = Mantri, c = Sipahi, d = Chor unless a test deals differently.
const fixed = () => ['raja', 'mantri', 'sipahi', 'chor'];
const guess = (g, s, u, targetId, now = 0) => g.onAction(s, u, { type: 'raja_mantri:guess', payload: { targetId } }, now);
/** Ticks from dealing to guessing. */
function toGuessing(g, s, t0 = 0) {
  g.onTick(s, t0 + 7000); // dealing -> raja
  g.onTick(s, t0 + 7000 + 3500); // raja -> guessing
  assert.strictEqual(s.phase, 'guessing');
  return t0 + 10500;
}

test('Raja Mantri: points table', () => {
  assert.deepStrictEqual(ROLES.map(r => pointsFor(r, true)), [1000, 500, 300, 0]);
  assert.deepStrictEqual(ROLES.map(r => pointsFor(r, false)), [1000, 0, 300, 500]);
});

test('Raja Mantri: exactly 4 players', () => {
  const g = createRajaMantri();
  assert.throws(() => g.create({ players: room.players.slice(0, 3) }), e => e.code === 'NOT_ENOUGH_PLAYERS');
  const srv = createServer();
  const rm = srv.rooms;
  rm.createRoom({ userId: 'h', username: 'H' }, { gameType: 'raja_mantri', maxPlayers: 6 });
  const code = rm.roomOf('h').code;
  for (const u of ['p', 'q']) { rm.joinRoom({ userId: u, username: u }, code); rm.setReady(u, true); }
  assert.throws(() => rm.startGame('h'), e => e.code === 'NOT_ENOUGH_PLAYERS', '3 players');
  rm.joinRoom({ userId: 'r', username: 'r' }, code); rm.setReady('r', true);
  assert.strictEqual(rm.startGame('h').status, 'playing');
  srv.io.close(); srv.httpServer.close();
});

test('Raja Mantri: every round deals each role exactly once', () => {
  const g = createRajaMantri({ rounds: 50, dealMs: 1, rajaMs: 1, guessMs: 1, revealMs: 1 });
  const s = g.create(room, 0);
  const seen = new Set();
  for (let t = 1; s.phase !== 'finished'; t++) {
    if (s.phase === 'dealing') {
      assert.deepStrictEqual(Object.values(s.roles).sort(), [...ROLES].sort());
      seen.add(JSON.stringify(s.roles));
    }
    g.onTick(s, t);
  }
  assert.ok(seen.size > 5, 'roles really are shuffled between rounds');
});

test('Raja Mantri: cards stay private until announced', () => {
  const g = createRajaMantri({ deal: fixed });
  const s = g.create(room, 0);
  for (const u of ['a', 'b', 'c', 'd']) {
    const v = g.getPublicState(s, u);
    assert.strictEqual(v.phase, 'dealing');
    assert.deepStrictEqual(Object.keys(v.roles), [u], `${u} sees only their own card while dealing`);
    assert.strictEqual(v.yourRole, s.roles[u]);
    assert.strictEqual(v.result, null);
  }
  g.onTick(s, 7000);
  assert.strictEqual(s.phase, 'raja');
  const c = g.getPublicState(s, 'c');
  assert.deepStrictEqual(c.roles, { a: 'raja', b: 'mantri', c: 'sipahi' }, 'Raja and Mantri announced, Chor hidden');
  assert.deepStrictEqual(g.getPublicState(s, 'b').roles, { a: 'raja', b: 'mantri' }, 'Mantri does not know the Chor');
});

test('Raja Mantri: Mantri catches the Chor: 1800 points handed out', () => {
  const g = createRajaMantri({ deal: fixed });
  const s = g.create(room, 0);
  assert.throws(() => guess(g, s, 'b', 'd'), e => e.code === 'BAD_PHASE');
  const t = toGuessing(g, s);
  assert.throws(() => guess(g, s, 'a', 'd', t), e => e.code === 'NOT_YOUR_TURN', 'only the Mantri guesses');
  for (const bad of ['a', 'b', 'zz', undefined]) {
    assert.throws(() => guess(g, s, 'b', bad, t), e => e.code === 'INVALID_PAYLOAD', String(bad));
  }
  assert.deepStrictEqual(guess(g, s, 'b', 'd', t), { caught: true });
  assert.strictEqual(s.phase, 'reveal');
  assert.deepStrictEqual(s.scores, { a: 1000, b: 500, c: 300, d: 0 });
  const v = g.getPublicState(s, 'c');
  assert.deepStrictEqual(v.roles, { a: 'raja', b: 'mantri', c: 'sipahi', d: 'chor' });
  assert.deepStrictEqual(v.result, { guess: 'd', chorId: 'd', caught: true, timedOut: false,
    points: { a: 1000, b: 500, c: 300, d: 0 }, roles: { a: 'raja', b: 'mantri', c: 'sipahi', d: 'chor' } });
  assert.throws(() => guess(g, s, 'b', 'd', t), e => e.code === 'BAD_PHASE', 'one guess per round');
});

test('Raja Mantri: wrong guess or timeout lets the Chor escape', () => {
  const g = createRajaMantri({ deal: fixed });
  const s = g.create(room, 0);
  let t = toGuessing(g, s);
  guess(g, s, 'b', 'c', t);
  assert.deepStrictEqual(s.scores, { a: 1000, b: 0, c: 300, d: 500 });
  assert.strictEqual(s.result.caught, false);

  g.onTick(s, t + 7000); // next round
  assert.strictEqual(s.phase, 'dealing'); assert.strictEqual(g.getPublicState(s, 'a').round, 2);
  t = toGuessing(g, s, t + 7000);
  assert.strictEqual(g.onTick(s, t + 9999), false, 'still time left');
  assert.strictEqual(g.onTick(s, t + 10000), true);
  assert.strictEqual(s.phase, 'reveal');
  assert.deepStrictEqual(s.result.guess, null); assert.strictEqual(s.result.timedOut, true);
  assert.deepStrictEqual(s.scores, { a: 2000, b: 0, c: 600, d: 1000 }, 'scores add up across rounds');
});

test('Raja Mantri: 20 rounds then finished with a ranking', () => {
  const g = createRajaMantri({ deal: fixed });
  const s = g.create(room, 0);
  let t = 0;
  for (let r = 1; r <= 20; r++) {
    assert.strictEqual(g.getPublicState(s, 'a').round, r);
    t = toGuessing(g, s, t);
    guess(g, s, 'b', 'd', t);
    g.onTick(s, t += 7000);
  }
  assert.ok(g.isFinished(s));
  assert.strictEqual(g.getPublicState(s, 'a').phase, 'finished');
  const res = g.getResult(s);
  assert.deepStrictEqual(res.ranking.map(r => [r.userId, r.score, r.rank]), [['a', 20000, 1], ['b', 10000, 2], ['c', 6000, 3], ['d', 0, 4]]);
  assert.deepStrictEqual(res.winners, ['a']);
  assert.strictEqual(g.onTick(s, t + 99999), false);
});

const connect = (port, n) => new Promise((res, rej) => {
  const s = io(`http://localhost:${port}`, { auth: { token: `dev:${n}:${n}` }, transports: ['websocket'], reconnection: false });
  s.once('connect', () => res(s)); s.once('connect_error', rej);
});
const emit = (s, ev, p) => new Promise(r => s.emit(ev, p, r));
const waitFor = (s, ev, pred = () => true) => new Promise(r => { const h = d => { if (pred(d)) { s.off(ev, h); r(d); } }; s.on(ev, h); });

test('Raja Mantri over sockets: 4 phones, each sees only their own card', async t => {
  const srv = createServer();
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const names = ['h', 'p', 'q', 'r'];
  const socks = await Promise.all(names.map(n => connect(port, n)));
  t.after(() => { socks.forEach(s => s.close()); srv.io.close(); srv.httpServer.close(); });
  const { room: created } = await emit(socks[0], 'create_room', { gameType: 'raja_mantri', maxPlayers: 4 });
  for (const s of socks.slice(1)) { await emit(s, 'join_room', { code: created.code }); await emit(s, 'player_ready'); }
  const states = socks.map(s => waitFor(s, 'game_state'));
  assert.ok((await emit(socks[0], 'start_game')).ok);
  const views = await Promise.all(states);
  const roles = views.map((v, i) => {
    assert.strictEqual(v.phase, 'dealing'); assert.strictEqual(v.totalRounds, 20);
    assert.deepStrictEqual(Object.keys(v.roles), [names[i]]);
    return v.yourRole;
  });
  assert.deepStrictEqual(roles.sort(), [...ROLES].sort());
});
