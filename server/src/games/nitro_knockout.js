const { GameError } = require('../errors');

// Nitro Knockout (3D kart combat, WASM/Three.js/Rapier in a WebView).
// The room host's WebView runs the authoritative simulation (Rapier physics) for every
// seat and publishes compact snapshots ~12 times a second; guests send centi-unit inputs
// and render the host's frames with interpolation. The server is the authority on the
// room lifecycle and validates every frame, input and result before relaying it:
//   - only the host may publish snapshots or finish the match
//   - snapshots must match the NetSnapshot contract (seat count, array shapes, bounds)
//   - inputs must be integers inside the throttle/steer ranges the game accepts
//   - final scores must be integers, one per seat
// Guests never write state: a malicious or buggy client can at most drive its own kart.

const MAX_STATE_BYTES = 32 * 1024;          // hard cap for one snapshot (~1-3 KB in practice)
const MAX_QUEUE = 200;                      // input queue cap, same as the generic relay
const MIN_SEATS = 2, MAX_SEATS = 10;
const ARENA_MM = 90000;                     // largest arena is 68 units; 90 units of head-room
const MAX_SHOTS = 64;                       // GAME_CONFIG.MAX_PROJECTILES
const MAX_MINES = 12;                       // GAME_CONFIG.MAX_MINES
const MAX_CRATES = 32;                      // pickup spots per arena
const MAX_TIME_MS = 10 * 60 * 1000;         // matches are 90s; generous ceiling
const WEAPON_INDEX_MAX = 5;                 // 0 = none, 1..5 = blaster/rocket/mine/shockwave/shield

const num = v => typeof v === 'number' && Number.isFinite(v);
const int = v => Number.isInteger(v);

/** Validates one kart row: [x,y,z,yaw,hp,score,alive,weapon,ammo,shield,boost,invuln]. */
function validKartRow(row) {
  if (!Array.isArray(row) || row.length !== 12 || !row.every(num)) return false;
  const [x, y, z, , hp, score, alive, weapon, ammo, shield, boost, invuln] = row;
  if (Math.abs(x) > ARENA_MM || Math.abs(z) > ARENA_MM || y < -2000 || y > ARENA_MM) return false;
  if (hp < 0 || hp > 100) return false;
  if (!int(score) || score < 0 || score > 100000) return false;
  if (alive !== 0 && alive !== 1) return false;
  if (!int(weapon) || weapon < 0 || weapon > WEAPON_INDEX_MAX) return false;
  if (!int(ammo) || ammo < 0 || ammo > 99) return false;
  if (shield < 0 || boost < 0 || invuln < 0) return false;
  return true;
}

/** Validates the host's snapshot against the NetSnapshot contract. */
function validateSnapshot(p, seats) {
  const s = p && p.state;
  if (!s || typeof s !== 'object' || Array.isArray(s)) throw new GameError('INVALID_PAYLOAD');
  if (JSON.stringify(s).length > MAX_STATE_BYTES) throw new GameError('INVALID_PAYLOAD', 'state too large');
  if (!int(s.time) || s.time < 0 || s.time > MAX_TIME_MS) throw new GameError('INVALID_PAYLOAD', 'bad time');
  if (s.over !== 0 && s.over !== 1) throw new GameError('INVALID_PAYLOAD', 'bad over flag');
  if (!int(s.seats) || s.seats !== seats) throw new GameError('INVALID_PAYLOAD', 'seat count mismatch');
  if (!Array.isArray(s.karts) || s.karts.length !== seats || !s.karts.every(validKartRow)) {
    throw new GameError('INVALID_PAYLOAD', 'bad karts');
  }
  if (!Array.isArray(s.shots) || s.shots.length > MAX_SHOTS) throw new GameError('INVALID_PAYLOAD', 'bad shots');
  for (const shot of s.shots) {
    if (!Array.isArray(shot) || shot.length !== 6 || !shot.every(num)) throw new GameError('INVALID_PAYLOAD', 'bad shot');
    const [x, y, z, vx, vz, kind] = shot;
    if (Math.abs(x) > ARENA_MM || Math.abs(z) > ARENA_MM || y < -2000 || y > ARENA_MM) throw new GameError('INVALID_PAYLOAD', 'shot out of bounds');
    if (Math.abs(vx) > 100000 || Math.abs(vz) > 100000) throw new GameError('INVALID_PAYLOAD', 'shot speed out of bounds');
    if (kind !== 0 && kind !== 1) throw new GameError('INVALID_PAYLOAD', 'bad shot kind');
  }
  if (!Array.isArray(s.mines) || s.mines.length > MAX_MINES) throw new GameError('INVALID_PAYLOAD', 'bad mines');
  for (const mine of s.mines) {
    if (!Array.isArray(mine) || mine.length !== 3 || !num(mine[0]) || !num(mine[1]) || !int(mine[2])) throw new GameError('INVALID_PAYLOAD', 'bad mine');
    if (Math.abs(mine[0]) > ARENA_MM || Math.abs(mine[1]) > ARENA_MM) throw new GameError('INVALID_PAYLOAD', 'mine out of bounds');
    if (mine[2] < -1 || mine[2] >= seats) throw new GameError('INVALID_PAYLOAD', 'bad mine owner');
  }
  if (!Array.isArray(s.crates) || s.crates.length > MAX_CRATES || !s.crates.every(c => c === 0 || c === 1)) {
    throw new GameError('INVALID_PAYLOAD', 'bad crates');
  }
  if (s.feed !== null && s.feed !== undefined) {
    if (!Array.isArray(s.feed) || s.feed.length !== 2 || !s.feed.every(n => typeof n === 'string' && n.length <= 24)) {
      throw new GameError('INVALID_PAYLOAD', 'bad feed');
    }
  }
  return s;
}

/** Guest input: [throttle, steer, drift, fire] — the exact tuple the game's decodeInput accepts. */
function validInputArgs(args) {
  if (!Array.isArray(args) || args.length !== 4) return false;
  const [throttle, steer, drift, fire] = args;
  if (!int(throttle) || throttle < -100 || throttle > 100) return false;
  if (!int(steer) || steer < -100 || steer > 100) return false;
  if (drift !== 0 && drift !== 1) return false;
  if (!int(fire) || fire < 0 || fire > 1000000) return false;
  return true;
}

const game = {
  id: 'nitro_knockout', minPlayers: MIN_SEATS, maxPlayers: MAX_SEATS, implemented: true, relay: true,
  // Only when a host picks it, never at random (Quick Play, party mode): app versions
  // from before Nitro can't open it.
  optIn: true,

  create(room) {
    if (room.players.length < MIN_SEATS || room.players.length > MAX_SEATS) throw new GameError('NOT_ENOUGH_PLAYERS');
    const players = room.players.map(p => p.userId);
    return {
      players,
      names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
      host: players.includes(room.hostId) ? room.hostId : players[0],
      seats: players.length,
      state: null, version: 0,
      inputs: [], inputSeq: 0,
      finished: false, scores: null,
    };
  },

  onAction(s, uid, { type, payload }) {
    if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
    if (s.finished && type !== 'nitro:state') throw new GameError('BAD_PHASE');
    const p = payload || {};
    if (type === 'nitro:state') {
      if (uid !== s.host) throw new GameError('NOT_HOST');
      s.state = validateSnapshot(p, s.seats);
      s.version++;
      if (Number.isInteger(p.ack)) s.inputs = s.inputs.filter(i => i.seq > p.ack);
      return { version: s.version };
    }
    if (type === 'nitro:input') {
      if (!validInputArgs(p.args)) throw new GameError('INVALID_PAYLOAD');
      // Silent: no room/game broadcast. The host pulls the queue with its own snapshots.
      s.inputs.push({ seq: ++s.inputSeq, from: uid, args: p.args });
      if (s.inputs.length > MAX_QUEUE) s.inputs.splice(0, s.inputs.length - MAX_QUEUE);
      return { seq: s.inputSeq, silent: true };
    }
    if (type === 'nitro:finish') {
      if (uid !== s.host) throw new GameError('NOT_HOST');
      const scores = p.scores;
      if (!Array.isArray(scores) || scores.length !== s.seats || !scores.every(n => int(n) && n >= 0 && n <= 100000)) {
        throw new GameError('INVALID_PAYLOAD');
      }
      s.scores = Object.fromEntries(s.players.map((u, i) => [u, scores[i]]));
      s.finished = true;
      return {};
    }
    throw new GameError('INVALID_ACTION');
  },

  getPublicState(s, uid) {
    return {
      gameType: 'nitro_knockout', relay: true, nitro: true, host: s.host, seats: s.seats,
      players: s.players.map(u => ({ userId: u, username: s.names[u] })),
      state: s.state, version: s.version,
      // Only the host needs the input queue.
      inputs: uid === s.host ? s.inputs : [],
      finished: s.finished,
    };
  },

  isFinished: s => s.finished,

  getResult(s) {
    const ranking = s.players.map(u => ({ userId: u, username: s.names[u], score: s.scores[u] })).sort((a, b) => b.score - a.score);
    let rank = 0;
    ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
    return { gameType: 'nitro_knockout', scores: s.scores, ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
  },
};

module.exports = { game, validateSnapshot, validInputArgs };
