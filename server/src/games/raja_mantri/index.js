const crypto = require('crypto');
const { GameError } = require('../../errors');

const ROLES = ['raja', 'mantri', 'sipahi', 'chor'];
const DEFAULTS = { rounds: 20, dealMs: 7000, rajaMs: 3500, guessMs: 10000, revealMs: 7000, deal: null };

const shuffle = a => { const r = [...a]; for (let i = r.length - 1; i > 0; i--) { const j = crypto.randomInt(i + 1); [r[i], r[j]] = [r[j], r[i]]; } return r; };

/** Points for one round. Raja and Sipahi always score; Mantri and Chor depend on the guess. */
function pointsFor(role, caught) {
  if (role === 'raja') return 1000;
  if (role === 'sipahi') return 300;
  if (role === 'mantri') return caught ? 500 : 0;
  return caught ? 0 : 500; // chor
}

// Raja Mantri Chor Sipahi for exactly 4 phones. Each round the server deals the four roles;
// every player sees only their own card. Phases: dealing (look at your card) -> raja (Raja and
// Mantri are revealed) -> guessing (Mantri has guessMs to name the Chor) -> reveal -> next round.
function createRajaMantri(opts = {}) {
  const cfg = { ...DEFAULTS, ...opts };
  const roleOf = (s, uid) => s.roles[uid];
  const holder = (s, role) => s.players.find(u => s.roles[u] === role);

  function startRound(s, now) {
    const roles = cfg.deal ? cfg.deal(s.round) : shuffle(ROLES);
    s.roles = Object.fromEntries(s.players.map((u, i) => [u, roles[i]]));
    s.phase = 'dealing';
    s.phaseEndsAt = now + cfg.dealMs;
    s.result = null;
  }

  function resolve(s, guess, now) {
    const chor = holder(s, 'chor');
    const caught = guess === chor;
    const points = Object.fromEntries(s.players.map(u => [u, pointsFor(s.roles[u], caught)]));
    for (const u of s.players) s.scores[u] += points[u];
    s.result = { guess, chorId: chor, caught, timedOut: guess === null, points, roles: { ...s.roles } };
    s.phase = 'reveal';
    s.phaseEndsAt = now + cfg.revealMs;
  }

  return {
    id: 'raja_mantri', minPlayers: 4, maxPlayers: 4, implemented: true,

    create(room, now = Date.now()) {
      if (room.players.length !== 4) throw new GameError('NOT_ENOUGH_PLAYERS');
      const s = {
        players: room.players.map(p => p.userId),
        names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
        scores: Object.fromEntries(room.players.map(p => [p.userId, 0])),
        round: 0, totalRounds: cfg.rounds, guessMs: cfg.guessMs,
      };
      startRound(s, now);
      return s;
    },

    onAction(s, uid, { type, payload }, now = Date.now()) {
      if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if (type !== 'raja_mantri:guess') throw new GameError('INVALID_ACTION');
      if (s.phase !== 'guessing') throw new GameError('BAD_PHASE');
      if (roleOf(s, uid) !== 'mantri') throw new GameError('NOT_YOUR_TURN');
      const target = payload && payload.targetId;
      const suspects = s.players.filter(u => s.roles[u] === 'sipahi' || s.roles[u] === 'chor');
      if (!suspects.includes(target)) throw new GameError('INVALID_PAYLOAD');
      resolve(s, target, now);
      return { caught: s.result.caught };
    },

    onTick(s, now) {
      if (s.phase === 'finished' || now < s.phaseEndsAt) return false;
      if (s.phase === 'dealing') { s.phase = 'raja'; s.phaseEndsAt = now + cfg.rajaMs; return true; }
      if (s.phase === 'raja') { s.phase = 'guessing'; s.phaseEndsAt = now + cfg.guessMs; return true; }
      if (s.phase === 'guessing') { resolve(s, null, now); return true; } // time up: Chor escapes
      if (s.round + 1 >= s.totalRounds) { s.phase = 'finished'; return true; }
      s.round++;
      startRound(s, now);
      return true;
    },

    getPublicState(s, uid) {
      const over = s.phase === 'reveal' || s.phase === 'finished';
      // Your own card always; Raja and Mantri once announced; everything after the guess.
      const visible = {};
      for (const u of s.players) {
        const r = s.roles[u];
        if (u === uid || over || (s.phase !== 'dealing' && (r === 'raja' || r === 'mantri'))) visible[u] = r;
      }
      return {
        gameType: 'raja_mantri', phase: s.phase, round: s.round + 1, totalRounds: s.totalRounds,
        players: s.players.map(u => ({ userId: u, username: s.names[u] })),
        scores: s.scores, yourRole: s.roles[uid] ?? null, roles: visible,
        phaseEndsAt: s.phase === 'finished' ? null : s.phaseEndsAt, guessMs: s.guessMs,
        result: over ? s.result : null,
      };
    },

    isFinished: s => s.phase === 'finished',

    getResult(s) {
      const ranking = s.players.map(u => ({ userId: u, username: s.names[u], score: s.scores[u] })).sort((a, b) => b.score - a.score);
      let rank = 0;
      ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
      return { gameType: 'raja_mantri', scores: s.scores, ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
    },
  };
}
module.exports = { game: createRajaMantri(), createRajaMantri, pointsFor, ROLES };
