const test = require('node:test');
const assert = require('node:assert');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');
const registry = require('../src/games/registry');
const { createGuessPerson } = require('../src/games/guess_person');
const { isCorrect } = require('../src/games/guess_person/matcher');
const { PEOPLE } = require('../src/games/guess_person/people');

const T = [
  { id: 'a', name: 'Ada Lovelace', aliases: ['Lovelace'], clues: ['c1', 'c2', 'c3'] },
  { id: 'b', name: 'Alan Turing', aliases: ['Turing'], clues: ['d1', 'd2', 'd3'] },
];
registry.register(createGuessPerson({ rounds: 2, clueMs: 500, revealMs: 300, maxAttempts: 2, people: T, shuffle: false }));

const connect = (port, n) => new Promise((res, rej) => {
  const s = io(`http://localhost:${port}`, { auth: { token: `dev:${n}:${n}` }, transports: ['websocket'], reconnection: false });
  s.once('connect', () => res(s)); s.once('connect_error', rej);
});
const emit = (s, ev, p) => new Promise(r => s.emit(ev, p, r));
const waitFor = (s, ev, pred = () => true) => new Promise(r => { const h = d => { if (pred(d)) { s.off(ev, h); r(d); } }; s.on(ev, h); });
let seq = 0;
const guess = (s, text) => emit(s, 'game_action', { type: 'guess_person:answer', payload: { text }, seq: ++seq });

test('matcher: case, accents, aliases, one typo on long answers only', () => {
  const p = PEOPLE.find(x => x.name === 'Pelé');
  assert.ok(isCorrect('pele', p) && isCorrect('PELÉ', p));
  assert.ok(isCorrect('ada  lovelace!', T[0]) && isCorrect('Lovelace', T[0]) && isCorrect('ada lovelac', T[0]));
  assert.ok(!isCorrect('ada', T[0]) && !isCorrect('', T[0]) && !isCorrect('Lovelaces and more', T[0]));
  const ali = PEOPLE.find(x => x.name === 'Muhammad Ali');
  assert.ok(!isCorrect('all', ali));
  for (const x of PEOPLE) assert.strictEqual(x.clues.length, 5, x.name);
});

test('full Guess the Person game over sockets', async t => {
  const srv = createServer();
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const h = await connect(port, 'h'), p = await connect(port, 'p');
  t.after(() => { h.close(); p.close(); srv.io.close(); srv.httpServer.close(); });

  const { room } = await emit(h, 'create_room', { gameType: 'guess_person', maxPlayers: 2 });
  await emit(p, 'join_room', { code: room.code }); await emit(p, 'player_ready');
  const first = waitFor(p, 'game_state');
  assert.ok((await emit(h, 'start_game')).ok);

  // Round 1: no answer leaks, clues unlock over time
  const s1 = await first;
  assert.strictEqual(s1.phase, 'round'); assert.strictEqual(s1.clues.length, 1);
  assert.ok(!JSON.stringify(s1).includes('Lovelace'));
  const two = await waitFor(p, 'game_state', s => s.clues && s.clues.length === 2);
  assert.ok(two.nextClueAt > Date.now() - 1000);

  // Wrong guesses are limited
  let r = await guess(p, 'Babbage'); assert.deepStrictEqual(r.response, { correct: false, attemptsLeft: 1 });
  r = await guess(p, 'Hopper');      assert.deepStrictEqual(r.response, { correct: false, attemptsLeft: 0 });
  assert.strictEqual((await guess(p, 'Ada')).error, 'NO_ATTEMPTS');
  assert.strictEqual((await emit(h, 'game_action', { type: 'hack', payload: {}, seq: ++seq })).error, 'INVALID_ACTION');
  assert.strictEqual((await guess(h, '')).error, 'INVALID_PAYLOAD');

  // Correct guess scores; everyone done -> round ends early with reveal
  const reveal = waitFor(h, 'game_state', s => s.phase === 'reveal');
  r = await guess(h, 'ada lovelace');
  assert.ok(r.response.correct && r.response.points >= 60);
  const rv = await reveal;
  assert.strictEqual(rv.reveal.answer, 'Ada Lovelace');
  assert.strictEqual(rv.scores.h, r.response.points);
  assert.strictEqual((await guess(h, 'ada lovelace')).error, 'BAD_PHASE');

  // Round 2: a typo is tolerated; p never answers, timer ends the round and then the game
  const r2 = await waitFor(h, 'game_state', s => s.phase === 'round' && s.round === 2);
  assert.ok(!JSON.stringify(r2).includes('Turing'));
  const fin = waitFor(h, 'game_finished');
  assert.ok((await guess(h, 'alan turin')).response.correct);
  const result = await fin;
  assert.deepStrictEqual(result.winners, ['h']);
  assert.strictEqual(result.ranking[0].rank, 1); assert.strictEqual(result.ranking[1].score, 0);
  assert.strictEqual((await emit(h, 'resume_session')).room.status, 'finished');
  assert.ok((await emit(h, 'return_to_lobby')).ok);
});
