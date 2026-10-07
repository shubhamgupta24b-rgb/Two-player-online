// Checks a running server end to end, e.g. right after deploying:
//   npm run smoke -- https://your-server.onrender.com
// Two guests connect, make a room, start a game, and the host's game state and result
// must reach the other player. A sleeping free server may take a minute to answer.
const { io } = require('socket.io-client');

const url = (process.argv[2] || 'http://localhost:3000').replace(/\/$/, '');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const client = (uid, name) => new Promise((res, rej) => {
  const s = io(url, { transports: ['websocket'], auth: { token: `dev:${uid}:${name}` }, reconnection: false, timeout: 90000 });
  s.on('connect', () => res(s));
  s.on('connect_error', e => rej(new Error(`${name} could not connect: ${e.message}`)));
});
const req = (s, ev, p = {}) => new Promise(r => s.emit(ev, p, r));
const must = (r, what) => {
  if (!r || !r.ok) throw new Error(`${what}: ${JSON.stringify(r)}`);
  return r;
};

(async () => {
  const t0 = Date.now();
  const ms = () => `${Date.now() - t0}ms`;
  const health = await fetch(`${url}/health`, { signal: AbortSignal.timeout(90000) }).then(r => r.text());
  console.log(`health ${health} (${ms()})`);
  const id = Date.now().toString(36);
  const a = await client(`smokeA${id}`, 'Host'), b = await client(`smokeB${id}`, 'Guest');
  console.log(`two players connected (${ms()})`);

  let states = 0, finished = null;
  b.on('game_state', () => states++);
  b.on('game_finished', r => (finished = r));

  const { room } = must(await req(a, 'create_room', { gameType: 'tic_tac_toe', maxPlayers: 4 }), 'create_room');
  const joined = must(await req(b, 'join_room', { code: room.code.toLowerCase() }), 'join_room');
  console.log(`room ${room.code}: ${joined.room.playable.length} games playable with 2 players`);
  must(await req(a, 'player_ready'), 'host ready');
  must(await req(b, 'player_ready'), 'guest ready');
  must(await req(a, 'select_game', { gameType: 'connect_four' }), 'select_game');
  must(await req(a, 'start_game'), 'start_game');
  must(await req(a, 'game_action', { type: 'relay:state', seq: 1, payload: { state: { v: 1 } } }), 'relay state');
  must(await req(a, 'game_action', { type: 'relay:finish', seq: 2, payload: { scores: [1, 0] } }), 'relay finish');
  await sleep(500);
  a.close();
  b.close();

  if (!states || !finished) throw new Error(`guest got ${states} states, result ${finished ? 'yes' : 'no'}`);
  console.log(`SMOKE OK: online play works (${ms()})`);
  process.exit(0);
})().catch(e => {
  console.error('SMOKE FAILED:', e.message);
  process.exit(1);
});
