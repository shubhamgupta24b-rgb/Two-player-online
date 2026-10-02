const test = require('node:test');
const assert = require('node:assert');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');
const { createGuessWho, buildQuestions, PEOPLE } = require('../src/games/guess_who');

const room = { players: [{ userId: 'a', username: 'A' }, { userId: 'b', username: 'B' }] };
const act = (g, s, u, type, payload, now = 0) => g.onAction(s, u, { type: `guess_who:${type}`, payload }, now);
const person = name => PEOPLE.find(p => p.name === name);
/** Starts a round with a choosing `aPick` and b choosing `bPick`. */
function playing(g, s, aPick = 'Tom', bPick = 'Lucy') {
  act(g, s, 'a', 'choose', { personId: person(aPick).id });
  act(g, s, 'b', 'choose', { personId: person(bPick).id });
}

test('Guess Who: 30 people, every pair can be told apart, questions cover all categories', () => {
  assert.strictEqual(PEOPLE.length, 30);
  assert.strictEqual(new Set(PEOPLE.map(p => p.id)).size, 30);
  const qs = buildQuestions(PEOPLE);
  for (let i = 0; i < PEOPLE.length; i++)
    for (let j = i + 1; j < PEOPLE.length; j++)
      assert.ok(qs.some(q => q.test(PEOPLE[i]) !== q.test(PEOPLE[j])), `${PEOPLE[i].name} vs ${PEOPLE[j].name}`);
  assert.deepStrictEqual([...new Set(qs.map(q => q.category))].sort(),
    ['accessories', 'eyes', 'facial_hair', 'gender', 'hair', 'hair_color', 'skin']);
  assert.strictEqual(new Set(qs.map(q => q.id)).size, qs.length, 'unique question ids');
});

test('Guess Who: starts in choosing with a 30-card board and no secrets', () => {
  const g = createGuessWho({ shuffle: false }); const s = g.create(room);
  assert.strictEqual(s.phase, 'choosing'); assert.strictEqual(s.board.length, 30);
  const pub = g.getPublicState(s, 'a');
  assert.strictEqual(pub.round, 1); assert.strictEqual(pub.totalRounds, 3);
  assert.deepStrictEqual(pub.you, { secretId: null, asked: [] });
  assert.ok(pub.players.every(p => p.chosen === false));
  assert.ok(pub.questions.every(q => q.id && q.label && q.prompt && q.category && !('test' in q)));
  assert.throws(() => g.create({ players: [room.players[0]] }), e => e.code === 'NOT_ENOUGH_PLAYERS');
});

test('Guess Who: choosing validates the person, can change, and starts play once both pick', () => {
  const g = createGuessWho(); const s = g.create(room);
  for (const personId of [undefined, 0, 31, '1', 1.5]) {
    assert.throws(() => act(g, s, 'a', 'choose', { personId }), e => e.code === 'INVALID_PAYLOAD', String(personId));
  }
  assert.throws(() => act(g, s, 'a', 'ask', { questionId: 'male' }), e => e.code === 'BAD_PHASE');
  act(g, s, 'a', 'choose', { personId: 1 });
  act(g, s, 'a', 'choose', { personId: 2 });
  assert.strictEqual(g.getPublicState(s, 'a').you.secretId, 2, 'last pick wins');
  assert.strictEqual(g.getPublicState(s, 'b').players.find(p => p.userId === 'a').chosen, true);
  assert.strictEqual(s.phase, 'choosing');
  act(g, s, 'b', 'choose', { personId: 3 });
  assert.strictEqual(s.phase, 'playing'); assert.strictEqual(s.turn, 'a');
  assert.throws(() => act(g, s, 'a', 'choose', { personId: 4 }), e => e.code === 'BAD_PHASE', 'locked in');
});

test('Guess Who: the opponent secret is never in your state until the reveal', () => {
  const g = createGuessWho(); const s = g.create(room);
  playing(g, s, 'Tom', 'Lucy');
  const aView = g.getPublicState(s, 'a'), bView = g.getPublicState(s, 'b');
  assert.strictEqual(aView.you.secretId, person('Tom').id);
  assert.strictEqual(bView.you.secretId, person('Lucy').id);
  assert.strictEqual(aView.reveal, null); assert.strictEqual(bView.reveal, null);
  assert.ok(!JSON.stringify(aView).includes(`"secretId":${person('Lucy').id}`));
  assert.ok(!('secrets' in aView));
});

test('Guess Who: questions are answered from the real secret, turns alternate, no repeats', () => {
  const g = createGuessWho(); const s = g.create(room);
  playing(g, s, 'Tom', 'Lucy'); // a must find Lucy (female, hat, earrings), b must find Tom (bald, glasses)
  assert.deepStrictEqual(act(g, s, 'a', 'ask', { questionId: 'female' }), { questionId: 'female', answer: true });
  assert.throws(() => act(g, s, 'a', 'ask', { questionId: 'hat' }), e => e.code === 'NOT_YOUR_TURN');
  assert.deepStrictEqual(act(g, s, 'b', 'ask', { questionId: 'bald' }), { questionId: 'bald', answer: true });
  assert.strictEqual(act(g, s, 'a', 'ask', { questionId: 'glasses' }).answer, false);
  assert.strictEqual(act(g, s, 'b', 'ask', { questionId: 'mustache' }).answer, true);
  assert.throws(() => act(g, s, 'a', 'ask', { questionId: 'female' }), e => e.code === 'ALREADY_ASKED');
  assert.throws(() => act(g, s, 'a', 'ask', { questionId: 'nope' }), e => e.code === 'INVALID_PAYLOAD');
  assert.throws(() => act(g, s, 'a', 'ask', undefined), e => e.code === 'INVALID_PAYLOAD');
  const aView = g.getPublicState(s, 'a');
  assert.deepStrictEqual(aView.you.asked.map(h => h.questionId), ['female', 'glasses']);
  assert.deepStrictEqual(aView.opponentAsked.map(h => [h.questionId, h.answer]), [['bald', true], ['mustache', true]]);
  assert.strictEqual(aView.turn, 'a');
});

test('Guess Who: a correct guess wins the round; a wrong guess gives it away', () => {
  const g = createGuessWho({ revealMs: 1000 }); const s = g.create(room);
  playing(g, s, 'Tom', 'Lucy');
  assert.throws(() => act(g, s, 'b', 'guess', { personId: person('Tom').id }), e => e.code === 'NOT_YOUR_TURN');
  assert.throws(() => act(g, s, 'a', 'guess', { personId: 99 }), e => e.code === 'INVALID_PAYLOAD');
  assert.deepStrictEqual(act(g, s, 'a', 'guess', { personId: person('Lucy').id }, 100), { correct: true, answer: person('Lucy').id });
  assert.deepStrictEqual(s.scores, { a: 1, b: 0 });
  assert.strictEqual(s.phase, 'reveal');
  const rv = g.getPublicState(s, 'b').reveal;
  assert.deepStrictEqual(rv, { secrets: { a: person('Tom').id, b: person('Lucy').id }, winner: 'a', guessedBy: 'a', guess: person('Lucy').id, correct: true });
  assert.throws(() => act(g, s, 'b', 'ask', { questionId: 'male' }), e => e.code === 'BAD_PHASE');

  // Round 2: b starts; b guesses wrong, so a scores.
  assert.strictEqual(g.onTick(s, 1099), false);
  assert.strictEqual(g.onTick(s, 1100), true);
  assert.strictEqual(s.phase, 'choosing'); assert.strictEqual(s.round, 1);
  assert.deepStrictEqual(g.getPublicState(s, 'a').you, { secretId: null, asked: [] }, 'fresh round');
  playing(g, s, 'Ben', 'Mila');
  assert.strictEqual(s.turn, 'b', 'starting player alternates');
  assert.strictEqual(act(g, s, 'b', 'guess', { personId: person('Tom').id }, 2000).correct, false);
  assert.deepStrictEqual(s.scores, { a: 2, b: 0 });
  assert.strictEqual(s.reveal.winner, 'a');
});

test('Guess Who: finishes after the last round and ranks players; rejects outsiders and unknown actions', () => {
  const g = createGuessWho({ rounds: 1, revealMs: 0 }); const s = g.create(room);
  assert.throws(() => act(g, s, 'x', 'choose', { personId: 1 }), e => e.code === 'NOT_IN_GAME');
  assert.throws(() => g.onAction(s, 'a', { type: 'memory:flip', payload: {} }), e => e.code === 'INVALID_ACTION');
  playing(g, s, 'Tom', 'Lucy');
  act(g, s, 'a', 'guess', { personId: person('Lucy').id }, 50);
  assert.strictEqual(g.onTick(s, 50), true);
  assert.strictEqual(g.isFinished(s), true);
  assert.strictEqual(g.onTick(s, 60), false);
  assert.notStrictEqual(g.getPublicState(s, 'a').reveal, null, 'final reveal stays visible');
  assert.deepStrictEqual(g.getResult(s).winners, ['a']);
});

test('Guess Who: only 2 players per room', () => {
  const srv = createServer();
  const rm = srv.rooms;
  assert.throws(() => rm.createRoom({ userId: 'h', username: 'H' }, { gameType: 'guess_who', maxPlayers: 3 }), e => e.code === 'INVALID_PAYLOAD');
  assert.ok(rm.createRoom({ userId: 'h', username: 'H' }, { gameType: 'guess_who', maxPlayers: 2 }));
  srv.io.close(); srv.httpServer.close();
});

const connect = (port, n) => new Promise((res, rej) => {
  const s = io(`http://localhost:${port}`, { auth: { token: `dev:${n}:${n}` }, transports: ['websocket'], reconnection: false });
  s.once('connect', () => res(s)); s.once('connect_error', rej);
});
const emit = (s, ev, p) => new Promise(r => s.emit(ev, p, r));
const waitFor = (s, ev, pred = () => true) => new Promise(r => { const h = d => { if (pred(d)) { s.off(ev, h); r(d); } }; s.on(ev, h); });
let seq = 0;
const gw = (s, type, payload) => emit(s, 'game_action', { type: `guess_who:${type}`, payload, seq: ++seq });

test('Guess Who over sockets: two phones choose, ask, guess; secrets never leak', async t => {
  const srv = createServer();
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const h = await connect(port, 'h'), p = await connect(port, 'p');
  t.after(() => { h.close(); p.close(); srv.io.close(); srv.httpServer.close(); });
  const leaks = [];
  p.on('game_state', st => { if (st.phase === 'playing' && JSON.stringify(st).includes(`"secretId":${person('Tom').id}`)) leaks.push(st); });

  const { room } = await emit(h, 'create_room', { gameType: 'guess_who', maxPlayers: 2 });
  await emit(p, 'join_room', { code: room.code }); await emit(p, 'player_ready');
  const first = waitFor(p, 'game_state');
  assert.ok((await emit(h, 'start_game')).ok);
  assert.strictEqual((await first).phase, 'choosing');

  assert.ok((await gw(h, 'choose', { personId: person('Tom').id })).ok);
  const play = waitFor(p, 'game_state', s => s.phase === 'playing');
  assert.ok((await gw(p, 'choose', { personId: person('Lucy').id })).ok);
  const st = await play;
  assert.strictEqual(st.turn, 'h'); assert.strictEqual(st.you.secretId, person('Lucy').id);

  assert.strictEqual((await gw(p, 'ask', { questionId: 'bald' })).error, 'NOT_YOUR_TURN');
  assert.deepStrictEqual((await gw(h, 'ask', { questionId: 'female' })).response, { questionId: 'female', answer: true });
  assert.strictEqual((await gw(p, 'ask', { questionId: 'bald' })).response.answer, true);
  const reveal = waitFor(p, 'game_state', s => s.phase === 'reveal');
  assert.strictEqual((await gw(h, 'guess', { personId: person('Lucy').id })).response.correct, true);
  const rv = await reveal;
  assert.strictEqual(rv.reveal.winner, 'h'); assert.strictEqual(rv.scores.h, 1);
  assert.strictEqual(rv.reveal.secrets.h, person('Tom').id, 'revealed only after the round');
  assert.deepStrictEqual(leaks, [], 'Tom was never sent to the opponent during play');
});
