const test = require('node:test');
const assert = require('node:assert');
const { io } = require('socket.io-client');
const { createServer } = require('../src/index');
const registry = require('../src/games/registry');
const { game: nitro, validateSnapshot, validInputArgs } = require('../src/games/nitro_knockout');

const room = (n, hostId = 'a') => ({
  hostId,
  players: 'abcdefghijk'.slice(0, n).split('').map(u => ({ userId: u, username: u.toUpperCase() })),
});
const act = (s, u, type, payload) => nitro.onAction(s, u, { type, payload });

/** A valid 3-seat snapshot, overridable per field. */
const snapshot = (over = {}) => ({
  time: 90000, seats: 3, over: 0,
  karts: [
    [1000, 0, -2000, 157, 100, 0, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 85, 2, 1, 1, 12, 0, 100, 50],
    [-30000, 500, 30000, -314, 40, 1, 0, 5, 1, 100, 0, 0],
  ],
  shots: [[5000, 500, 5000, 20000, 0, 0]],
  mines: [[-1000, 1000, 1]],
  crates: [1, 0, 1, 1, 0, 0],
  feed: null,
  ...over,
});

test('Nitro: registered with 2-10 seats', () => {
  const g = registry.get('nitro_knockout');
  assert.ok(g, 'registered');
  assert.deepStrictEqual([g.minPlayers, g.maxPlayers], [2, 10]);
  assert.strictEqual(g.relay, true);
});

test('Nitro: room size limits', () => {
  assert.throws(() => nitro.create(room(1)), e => e.code === 'NOT_ENOUGH_PLAYERS');
  assert.throws(() => nitro.create(room(11)), e => e.code === 'NOT_ENOUGH_PLAYERS');
  for (const n of [2, 3, 5, 8, 10]) {
    const s = nitro.create(room(n));
    assert.strictEqual(s.seats, n);
    assert.strictEqual(s.host, 'a');
  }
  assert.strictEqual(nitro.create(room(3, 'zz')).host, 'a', 'host not in game: first player');
});

test('Nitro: only the host publishes snapshots; seats must match the room', () => {
  const s = nitro.create(room(3));
  assert.throws(() => act(s, 'b', 'nitro:state', { state: snapshot() }), e => e.code === 'NOT_HOST');
  assert.throws(() => act(s, 'zz', 'nitro:state', { state: snapshot() }), e => e.code === 'NOT_IN_GAME');
  assert.throws(() => act(s, 'a', 'nitro:state', { state: snapshot({ seats: 4 }) }), e => e.code === 'INVALID_PAYLOAD');
  assert.deepStrictEqual(act(s, 'a', 'nitro:state', { state: snapshot() }), { version: 1, gameOnly: true });
  assert.strictEqual(s.version, 1);
  // Ack drops queued inputs.
  act(s, 'b', 'nitro:input', { args: [100, 0, 0, 0] });
  act(s, 'a', 'nitro:state', { state: snapshot(), ack: 1 });
  assert.deepStrictEqual(s.inputs, []);
});

test('Nitro: snapshot structure is validated (karts/shots/mines/crates/feed)', () => {
  const s = nitro.create(room(3));
  const bad = [
    ['missing state', {}], ['null', { state: null }], ['array state', { state: [] }],
    ['bad time', snapshot({ time: -1 })], ['float time', snapshot({ time: 1.5 })], ['huge time', snapshot({ time: 6e7 })],
    ['bad over', snapshot({ over: 2 })],
    ['kart row too short', snapshot({ karts: [[1, 2, 3], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]] })],
    ['kart row too long', snapshot({ karts: [new Array(13).fill(0), snapshot().karts[1], snapshot().karts[2]] })],
    ['kart NaN', snapshot({ karts: [snapshot().karts[0].map((v, i) => (i === 4 ? NaN : v)), snapshot().karts[1], snapshot().karts[2]] })],
    ['kart out of arena', snapshot({ karts: [snapshot().karts[0].map((v, i) => (i === 0 ? 200000 : v)), snapshot().karts[1], snapshot().karts[2]] })],
    ['kart hp 101', snapshot({ karts: [snapshot().karts[0].map((v, i) => (i === 4 ? 101 : v)), snapshot().karts[1], snapshot().karts[2]] })],
    ['kart score float', snapshot({ karts: [snapshot().karts[0].map((v, i) => (i === 5 ? 1.5 : v)), snapshot().karts[1], snapshot().karts[2]] })],
    ['kart alive=2', snapshot({ karts: [snapshot().karts[0].map((v, i) => (i === 6 ? 2 : v)), snapshot().karts[1], snapshot().karts[2]] })],
    ['kart weapon 6', snapshot({ karts: [snapshot().karts[0].map((v, i) => (i === 7 ? 6 : v)), snapshot().karts[1], snapshot().karts[2]] })],
    ['kart count mismatch', snapshot({ karts: snapshot().karts.slice(0, 2) })],
    ['too many shots', snapshot({ shots: new Array(65).fill([0, 0, 0, 0, 0, 0]) })],
    ['bad shot kind', snapshot({ shots: [[0, 0, 0, 0, 0, 5]] })],
    ['bad shot bounds', snapshot({ shots: [[999999, 0, 0, 0, 0, 0]] })],
    ['bad shot speed', snapshot({ shots: [[0, 0, 0, 200000, 0, 0]] })],
    ['too many mines', snapshot({ mines: new Array(13).fill([0, 0, 0]) })],
    ['mine owner out of range', snapshot({ mines: [[0, 0, 7]] })],
    ['crate not 0/1', snapshot({ crates: [1, 2, 0] })],
    ['bad feed', snapshot({ feed: ['a'] })],
    ['feed too long', snapshot({ feed: ['x'.repeat(65), 'y'] })],
    ['feed with markup', snapshot({ feed: ['<img src=x onerror=alert(1)>', 'y'] })],
  ];
  for (const [name, payload] of bad) {
    // Bare snapshots go inside { state }, so each case reaches the rule it is about.
    const p = payload && payload.seats !== undefined ? { state: payload } : payload;
    assert.throws(() => act(s, 'a', 'nitro:state', p), e => e.code === 'INVALID_PAYLOAD', name);
  }
  // Valid edge values pass.
  act(s, 'a', 'nitro:state', { state: snapshot({ feed: ['NOVA', 'BOLT'], crates: [], shots: [], mines: [] }) });
  assert.strictEqual(s.version, 1);
});

test('Nitro: guest inputs are validated and queued silently', () => {
  const s = nitro.create(room(3));
  for (const bad of [
    [101, 0, 0, 0], [-101, 0, 0, 0], [1.5, 0, 0, 0], ['100', 0, 0, 0],
    [0, 101, 0, 0], [0, 0, 2, 0], [0, 0, 0, -1], 'no', [1, 2, 3], [], [1, 2, 3, 4, 5],
  ]) {
    assert.throws(() => act(s, 'b', 'nitro:input', { args: bad }), e => e.code === 'INVALID_PAYLOAD', JSON.stringify(bad));
  }
  assert.throws(() => act(s, 'zz', 'nitro:input', { args: [0, 0, 0, 0] }), e => e.code === 'NOT_IN_GAME');
  // Valid inputs queue with a seq; the response is marked silent (no broadcast).
  const r1 = act(s, 'b', 'nitro:input', { args: [100, -40, 1, 1] });
  const r2 = act(s, 'c', 'nitro:input', { args: [-100, 100, 0, 0] });
  assert.deepStrictEqual([r1.seq, r1.silent, r2.seq, r2.silent], [1, true, 2, true]);
  assert.deepStrictEqual(s.inputs.map(i => [i.seq, i.from]), [[1, 'b'], [2, 'c']]);
  assert.strictEqual(s.version, 0, 'inputs never bump the snapshot version');
  // The host sees the queue; guests do not.
  assert.strictEqual(nitro.getPublicState(s, 'a').inputs.length, 2);
  assert.deepStrictEqual(nitro.getPublicState(s, 'b').inputs, []);
  // The queue is capped.
  for (let i = 0; i < 250; i++) act(s, 'b', 'nitro:input', { args: [0, 0, 0, 0] });
  assert.strictEqual(s.inputs.length, 200);
});

test('Nitro: only the host finishes; scores must cover every seat', () => {
  const s = nitro.create(room(3));
  act(s, 'a', 'nitro:state', { state: snapshot() });
  assert.throws(() => act(s, 'b', 'nitro:finish', { scores: [5, 5, 5] }), e => e.code === 'NOT_HOST');
  assert.throws(() => act(s, 'a', 'nitro:finish', { scores: [5, 5] }), e => e.code === 'INVALID_PAYLOAD');
  assert.throws(() => act(s, 'a', 'nitro:finish', { scores: [5, 5.5, 5] }), e => e.code === 'INVALID_PAYLOAD');
  assert.throws(() => act(s, 'a', 'nitro:finish', { scores: [-1, 0, 0] }), e => e.code === 'INVALID_PAYLOAD');
  act(s, 'a', 'nitro:finish', { scores: [7, 3, 3] });
  assert.strictEqual(s.finished, true);
  assert.deepStrictEqual(s.scores, { a: 7, b: 3, c: 3 });
  // After the finish nothing is accepted (RoomManager rejects it too once the room is finished).
  assert.throws(() => act(s, 'b', 'nitro:input', { args: [0, 0, 0, 0] }), e => e.code === 'BAD_PHASE');
  assert.throws(() => act(s, 'a', 'nitro:state', { state: snapshot() }), e => e.code === 'BAD_PHASE');
  const result = nitro.getResult(s);
  assert.deepStrictEqual(result.winners, ['a']);
  assert.deepStrictEqual(result.ranking.map(r => [r.userId, r.rank]), [['a', 1], ['b', 2], ['c', 2]]);
});

test('Nitro: ranking orders by score with tied ranks', () => {
  const s = nitro.create(room(3));
  act(s, 'a', 'nitro:state', { state: snapshot() });
  act(s, 'a', 'nitro:finish', { scores: [10, 10, 4] });
  const result = nitro.getResult(s);
  assert.deepStrictEqual(result.ranking.map(r => [r.userId, r.rank]), [['a', 1], ['b', 1], ['c', 3]]);
  assert.deepStrictEqual(result.winners, ['a', 'b']);
});

test('Nitro: unknown actions are rejected', () => {
  const s = nitro.create(room(2));
  assert.throws(() => act(s, 'a', 'relay:state', { state: {} }), e => e.code === 'INVALID_ACTION');
  assert.throws(() => act(s, 'a', 'nope', {}), e => e.code === 'INVALID_ACTION');
});

test('Nitro: standalone validators agree with the action paths', () => {
  assert.strictEqual(validInputArgs([100, -100, 1, 0]), true);
  assert.strictEqual(validInputArgs([100.5, 0, 0, 0]), false);
  assert.strictEqual(validateSnapshot({ state: snapshot() }, 3).seats, 3);
  assert.throws(() => validateSnapshot({ state: snapshot({ seats: 5 }) }, 3));
});

test('Nitro: rooms up to 10 players, full online lifecycle over the socket', async () => {
  const srv = createServer({ graceMs: 60000 });
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  const clients = [];
  try {
    const connect = name => new Promise((res, rej) => {
      const s = io(`http://localhost:${port}`, { auth: { token: `dev:${name}:${name}` }, transports: ['websocket'], reconnection: false });
      s.once('connect', () => res(s)); s.once('connect_error', rej);
    });
    const sockets = await Promise.all('abcdefghij'.split('').map(connect));
    clients.push(...sockets);

    // Host creates a 10-player nitro room.
    const created = await sockets[0].emitWithAck('create_room', { gameType: 'nitro_knockout', maxPlayers: 10 });
    assert.strictEqual(created.ok, true, created.error);
    const code = created.room.code;
    await Promise.all(sockets.slice(1).map(s => s.emitWithAck('join_room', { code })));

    // Invalid code / duplicate join / full room are rejected.
    assert.strictEqual((await sockets[0].emitWithAck('join_room', { code: 'ZZZZ99' })).ok, false);
    assert.strictEqual((await sockets[0].emitWithAck('join_room', { code })).ok, false, 'duplicate join rejected');

    const joiners = sockets.slice(1);
    // An 11th client finds the room full.
    const k = await connect('k');
    clients.push(k);
    assert.strictEqual((await k.emitWithAck('join_room', { code })).ok, false);
    assert.strictEqual((await k.emitWithAck('join_room', { code })).error, 'ROOM_FULL');

    // Everyone readies and the host starts.
    await Promise.all(joiners.map(s => s.emitWithAck('player_ready', {})));
    const started = await sockets[0].emitWithAck('start_game', {});
    assert.strictEqual(started.ok, true, started.error);

    // Host publishes a 10-kart snapshot; every guest receives it.
    const snap = snapshot({ seats: 10, karts: Array.from({ length: 10 }, (_, i) => [i * 1000, 0, 0, 0, 100, 0, 1, 0, 0, 0, 0, 0]), shots: [], mines: [], crates: [] });
    // Skip the start_game broadcast (its state is null) and wait for the snapshot frame.
    const gotStates = Promise.all(sockets.map(s => new Promise(resolve => s.on('game_state', function h(d) { if (d.state) { s.off('game_state', h); resolve(d); } }))));
    await sockets[0].emitWithAck('game_action', { type: 'nitro:state', payload: { state: snap }, seq: 1 });
    const states = await gotStates;
    for (const st of states) {
      assert.strictEqual(st.nitro, true);
      assert.strictEqual(st.state.seats, 10);
      assert.strictEqual(st.karts, undefined);
    }
    // Guests see no input queue; host does (inputs arrive with the host's own game_state).

    // Guest input: acked silently, then visible in the host's next game_state.
    await sockets[1].emitWithAck('game_action', { type: 'nitro:input', payload: { args: [80, -20, 0, 1] }, seq: 2 });
    const hostSeesInputs = new Promise(resolve => sockets[0].once('game_state', st => resolve(st.inputs)));
    await sockets[0].emitWithAck('game_action', { type: 'nitro:state', payload: { state: snap, ack: 1 }, seq: 3 });
    const inputs = await hostSeesInputs;
    assert.strictEqual(inputs.length, 0, 'acked input dropped');
    await sockets[2].emitWithAck('game_action', { type: 'nitro:input', payload: { args: [0, 50, 1, 0] }, seq: 4 });
    const inputs2 = await (new Promise(resolve => {
      sockets[0].once('game_state', st => resolve(st.inputs));
      sockets[0].emitWithAck('game_action', { type: 'nitro:state', payload: { state: snap, ack: 0 }, seq: 5 });
    }));
    assert.deepStrictEqual(inputs2.map(i => i.from), ['c']);

    // Host finishes; everyone gets game_finished with a ranking.
    const finished = new Promise(resolve => sockets[3].once('game_finished', resolve));
    await sockets[0].emitWithAck('game_action', { type: 'nitro:finish', payload: { scores: [9, ...new Array(9).fill(0)] }, seq: 6 });
    const result = await finished;
    assert.strictEqual(result.winners[0], 'a');
    assert.strictEqual(result.ranking.length, 10);

    // Rematch: back to lobby and start again works with the same room.
    await sockets[0].emitWithAck('return_to_lobby', {});
    await Promise.all(joiners.map(s => s.emitWithAck('player_ready', {})));
    const again = await sockets[0].emitWithAck('start_game', {});
    assert.strictEqual(again.ok, true, 'rematch works');

    for (const s of sockets) s.close();
  } finally {
    srv.io.close();
    srv.httpServer.close();
  }
});

test('Nitro: room capacity 7-10 is allowed at the room level', async () => {
  const srv = createServer({ graceMs: 60000 });
  await new Promise(r => srv.httpServer.listen(0, r));
  const port = srv.httpServer.address().port;
  try {
    const s = await new Promise((res, rej) => {
      const c = io(`http://localhost:${port}`, { auth: { token: 'dev:a:a' }, transports: ['websocket'], reconnection: false });
      c.once('connect', () => res(c)); c.once('connect_error', rej);
    });
    for (const size of [2, 7, 10]) {
      const r = await s.emitWithAck('create_room', { gameType: 'nitro_knockout', maxPlayers: size });
      assert.strictEqual(r.ok, true, `size ${size}: ${r.error}`);
      await s.emitWithAck('leave_room', {});
    }
    assert.strictEqual((await s.emitWithAck('create_room', { gameType: 'nitro_knockout', maxPlayers: 11 })).ok, false);
    assert.strictEqual((await s.emitWithAck('create_room', { gameType: 'nitro_knockout', maxPlayers: 1 })).ok, false);
    s.close();
  } finally {
    srv.io.close();
    srv.httpServer.close();
  }
});

test('Nitro: when the host leaves mid-match, everyone gets game_state naming the new host', () => {
  const { RoomManager } = require('../src/rooms/RoomManager');
  const rm = new RoomManager();
  const u = id => ({ userId: id, username: id, avatar: null });
  const room = rm.createRoom(u('a'), { gameType: 'nitro_knockout', maxPlayers: 3 });
  rm.joinRoom(u('b'), room.code);
  rm.joinRoom(u('c'), room.code);
  rm.setReady('b', true);
  rm.setReady('c', true);
  rm.startGame('a');
  const updates = [];
  rm.on('game_updated', code => updates.push(code));
  rm.leave('a');
  assert.strictEqual(room.status, 'playing');
  assert.strictEqual(room.game.host, 'b');
  assert.deepStrictEqual(updates, [room.code], 'the new host must be told through game_state');
});

test('Relay games that run on the host end the match when the host leaves (no frozen game)', () => {
  const { RoomManager } = require('../src/rooms/RoomManager');
  const rm = new RoomManager();
  const u = id => ({ userId: id, username: id, avatar: null });
  const room = rm.createRoom(u('a'), { gameType: 'mini_golf', maxPlayers: 3 });
  rm.joinRoom(u('b'), room.code);
  rm.joinRoom(u('c'), room.code);
  rm.setReady('b', true);
  rm.setReady('c', true);
  rm.startGame('a');
  const aborted = [];
  rm.on('game_aborted', code => aborted.push(code));
  rm.leave('a');
  assert.strictEqual(room.status, 'lobby');
  assert.strictEqual(room.hostId, 'b');
  assert.deepStrictEqual(aborted, [room.code]);
});

test('Nitro: real in-game states pass: a kart falling off the edge, a long name in the kill feed', () => {
  const s = nitro.create(room(3));
  // The game only knocks a kart out below y = -5 units (-5000 mm) and parks it there to respawn.
  const falling = snapshot().karts[0].map((v, i) => (i === 1 ? -5400 : v));
  act(s, 'a', 'nitro:state', { state: snapshot({ karts: [falling, snapshot().karts[1], snapshot().karts[2]] }) });
  act(s, 'a', 'nitro:state', { state: snapshot({ feed: ['Christopher Alexander Montgomery', 'ARENA'] }) });
  assert.strictEqual(s.version, 2);
});

test('Host frames broadcast game_state only, not room_state', () => {
  const { RoomManager } = require('../src/rooms/RoomManager');
  const rm = new RoomManager();
  const u = id => ({ userId: id, username: id, avatar: null });
  const r = rm.createRoom(u('a'), { gameType: 'nitro_knockout', maxPlayers: 2 });
  rm.joinRoom(u('b'), r.code);
  rm.setReady('b', true);
  rm.startGame('a');
  const events = [];
  rm.on('room_changed', () => events.push('room'));
  rm.on('game_updated', () => events.push('game'));
  rm.gameAction('a', { type: 'nitro:state', payload: { state: snapshot({ seats: 2, karts: snapshot().karts.slice(0, 2) }) }, seq: 1 });
  assert.deepStrictEqual(events, ['game']);
});
