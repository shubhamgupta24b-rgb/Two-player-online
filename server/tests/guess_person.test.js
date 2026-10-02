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

// Pure game-logic tests: time is passed in explicitly, so every boundary is exact.
const pure = () => createGuessPerson({ rounds: 2, clueMs: 1000, revealMs: 500, maxAttempts: 2, people: T, shuffle: false });
const room2 = { players: [{ userId: 'a', username: 'A' }, { userId: 'b', username: 'B' }] };
const answer = (g, s, u, text, now) => g.onAction(s, u, { type: 'guess_person:answer', payload: { text } }, now);

test('Guess the Person starts round 1 with one clue and hides the answer', () => {
  const g = pure(); const s = g.create(room2, 0);
  assert.strictEqual(s.phase, 'round'); assert.strictEqual(s.roundEndsAt, 3000);
  const pub = g.getPublicState(s, 'a');
  assert.deepStrictEqual(pub.clues, ['c1']);
  assert.strictEqual(pub.round, 1); assert.strictEqual(pub.totalRounds, 2); assert.strictEqual(pub.totalClues, 3);
  assert.strictEqual(pub.nextClueAt, 1000); assert.strictEqual(pub.reveal, null);
  assert.deepStrictEqual(pub.you, { attemptsLeft: 2, solved: false });
  assert.ok(!JSON.stringify(pub).includes('Lovelace'));
});

test('Guess the Person unlocks clues on the clock', () => {
  const g = pure(); const s = g.create(room2, 0);
  assert.strictEqual(g.onTick(s, 999), false);
  assert.strictEqual(g.onTick(s, 1000), true);
  assert.strictEqual(g.onTick(s, 1500), false, 'no change until the next clue');
  assert.deepStrictEqual(g.getPublicState(s, 'a').clues, ['c1', 'c2']);
  assert.strictEqual(g.onTick(s, 2000), true);
  assert.strictEqual(g.getPublicState(s, 'a').nextClueAt, null, 'all clues shown');
});

test('Guess the Person rejects invalid answers', () => {
  const g = pure(); const s = g.create(room2, 0);
  assert.throws(() => answer(g, s, 'x', 'Ada', 10), e => e.code === 'NOT_IN_GAME');
  assert.throws(() => g.onAction(s, 'a', { type: 'memory:flip', payload: {} }, 10), e => e.code === 'INVALID_ACTION');
  for (const text of [undefined, 5, '', '   ', 'x'.repeat(61)]) {
    assert.throws(() => answer(g, s, 'a', text, 10), e => e.code === 'INVALID_PAYLOAD', String(text));
  }
  assert.throws(() => answer(g, s, 'a', 'Ada Lovelace', 3000), e => e.code === 'BAD_PHASE', 'at roundEndsAt');
  assert.strictEqual(s.attempts.a, 0, 'rejected answers do not use attempts');
});

test('Guess the Person scores by clues shown, first solver bonus, and ends the round when all are done', () => {
  const g = pure(); const s = g.create(room2, 0);
  const a = answer(g, s, 'a', 'lovelace', 1500); // 2 of 3 clues: 100 - 80*1/2 = 60, +20 first bonus
  assert.deepStrictEqual(a, { correct: true, points: 80 });
  assert.throws(() => answer(g, s, 'a', 'Ada Lovelace', 1600), e => e.code === 'ALREADY_SOLVED');
  assert.strictEqual(s.phase, 'round', 'b has not finished yet');
  const b = answer(g, s, 'b', 'Ada Lovelace', 2500); // 3 of 3 clues: 20, no bonus
  assert.deepStrictEqual(b, { correct: true, points: 20 });
  assert.strictEqual(s.phase, 'reveal');
  const pub = g.getPublicState(s, 'a');
  assert.deepStrictEqual(pub.reveal, { answer: 'Ada Lovelace', gained: { a: 80, b: 20 } });
  assert.deepStrictEqual(pub.clues, ['c1', 'c2', 'c3'], 'all clues shown during the reveal');
  assert.strictEqual(pub.revealEndsAt, 3000);
  assert.throws(() => answer(g, s, 'b', 'Ada', 2600), e => e.code === 'BAD_PHASE');
});

test('Guess the Person limits wrong attempts and running out counts as done', () => {
  const g = pure(); const s = g.create(room2, 0);
  assert.deepStrictEqual(answer(g, s, 'a', 'Babbage', 10), { correct: false, attemptsLeft: 1 });
  assert.deepStrictEqual(answer(g, s, 'a', 'Hopper', 20), { correct: false, attemptsLeft: 0 });
  assert.throws(() => answer(g, s, 'a', 'Ada Lovelace', 30), e => e.code === 'NO_ATTEMPTS');
  assert.strictEqual(g.getPublicState(s, 'a').you.attemptsLeft, 0);
  assert.strictEqual(s.phase, 'round');
  answer(g, s, 'b', 'Ada Lovelace', 40);
  assert.strictEqual(s.phase, 'reveal', 'a is out of attempts and b solved');
  assert.deepStrictEqual(s.reveal.gained, { b: 120 });
});

test('Guess the Person runs both rounds on the clock and finishes', () => {
  const g = pure(); const s = g.create(room2, 0);
  answer(g, s, 'a', 'lovelace', 100);
  assert.strictEqual(g.onTick(s, 3000), true); assert.strictEqual(s.phase, 'reveal');
  assert.strictEqual(g.onTick(s, 3499), false);
  assert.strictEqual(g.onTick(s, 3500), true);
  assert.strictEqual(s.phase, 'round'); assert.strictEqual(g.getPublicState(s, 'a').round, 2);
  assert.deepStrictEqual(g.getPublicState(s, 'a').you, { attemptsLeft: 2, solved: false }, 'attempts reset each round');
  assert.ok(!JSON.stringify(g.getPublicState(s, 'a')).includes('Turing'));
  assert.strictEqual(g.onTick(s, 6500), true); assert.strictEqual(s.phase, 'reveal');
  assert.strictEqual(g.onTick(s, 7000), true); assert.strictEqual(g.isFinished(s), true);
  assert.strictEqual(g.onTick(s, 9000), false);
  const r = g.getResult(s);
  assert.deepStrictEqual(r.winners, ['a']); assert.deepStrictEqual(r.scores, { a: 120, b: 0 });
});

test('Guess the Person ties share the win', () => {
  const g = pure(); const s = g.create(room2, 0);
  const r = g.getResult(s);
  assert.deepStrictEqual(r.winners, ['a', 'b']);
  assert.ok(r.ranking.every(x => x.rank === 1));
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
