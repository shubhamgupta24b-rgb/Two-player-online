const crypto = require('crypto');
const { GameError } = require('../../errors');
const { PEOPLE } = require('./people');
const { isCorrect } = require('./matcher');

const DEFAULTS = { rounds: 5, clueMs: 8000, revealMs: 6000, maxAttempts: 3, firstBonus: 20, people: PEOPLE, shuffle: true };

const shuffle = a => { const r = [...a]; for (let i = r.length - 1; i > 0; i--) { const j = crypto.randomInt(i + 1); [r[i], r[j]] = [r[j], r[i]]; } return r; };

// All players guess at the same time every round. Clues unlock over time; earlier correct guesses score more.
function createGuessPerson(opts = {}) {
  const cfg = { ...DEFAULTS, ...opts };

  const cluesShown = (s, now) => Math.min(s.person.clues.length, 1 + Math.floor(Math.max(0, now - s.roundStartedAt) / cfg.clueMs));
  const allDone = s => s.players.every(u => s.solved[u] !== undefined || s.attempts[u] >= cfg.maxAttempts);

  function startRound(s, now) {
    s.person = s.people[s.round];
    s.phase = 'round';
    s.roundStartedAt = now;
    s.roundEndsAt = now + s.person.clues.length * cfg.clueMs;
    s.lastShown = 1;
    s.attempts = Object.fromEntries(s.players.map(u => [u, 0]));
    s.solved = {};
  }
  function endRound(s, now) {
    s.phase = 'reveal';
    s.reveal = { answer: s.person.name, gained: { ...s.solved } };
    s.revealEndsAt = now + cfg.revealMs;
  }

  return {
    id: 'guess_person', minPlayers: 2, maxPlayers: 4, implemented: true,

    create(room, now = Date.now()) {
      const people = cfg.shuffle ? shuffle(cfg.people) : cfg.people;
      const s = {
        players: room.players.map(p => p.userId),
        names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
        people: people.slice(0, cfg.rounds), round: 0,
        scores: Object.fromEntries(room.players.map(p => [p.userId, 0])), reveal: null,
      };
      startRound(s, now);
      return s;
    },

    onAction(s, uid, { type, payload }, now = Date.now()) {
      if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if (type !== 'guess_person:answer') throw new GameError('INVALID_ACTION');
      const text = payload && payload.text;
      if (typeof text !== 'string' || !text.trim() || text.length > 60) throw new GameError('INVALID_PAYLOAD');
      if (s.phase !== 'round' || now >= s.roundEndsAt) throw new GameError('BAD_PHASE');
      if (s.solved[uid] !== undefined) throw new GameError('ALREADY_SOLVED');
      if (s.attempts[uid] >= cfg.maxAttempts) throw new GameError('NO_ATTEMPTS');
      s.attempts[uid]++;
      let response;
      if (isCorrect(text, s.person)) {
        const n = s.person.clues.length, shown = cluesShown(s, now);
        let pts = Math.round(100 - (80 * (shown - 1)) / Math.max(1, n - 1));
        if (Object.keys(s.solved).length === 0) pts += cfg.firstBonus;
        s.solved[uid] = pts;
        s.scores[uid] += pts;
        response = { correct: true, points: pts };
      } else {
        response = { correct: false, attemptsLeft: cfg.maxAttempts - s.attempts[uid] };
      }
      if (allDone(s)) endRound(s, now);
      return response;
    },

    // Called by the server clock. Returns true when state changed and must be broadcast.
    onTick(s, now) {
      if (s.phase === 'finished') return false;
      if (s.phase === 'round') {
        if (now >= s.roundEndsAt) { endRound(s, now); return true; }
        const shown = cluesShown(s, now);
        if (shown !== s.lastShown) { s.lastShown = shown; return true; }
        return false;
      }
      if (now < s.revealEndsAt) return false;
      if (s.round + 1 >= s.people.length) s.phase = 'finished';
      else { s.round++; startRound(s, now); }
      return true;
    },

    getPublicState(s, uid) {
      const inRound = s.phase === 'round';
      return {
        gameType: 'guess_person', phase: s.phase, round: s.round + 1, totalRounds: s.people.length,
        clues: inRound || s.phase === 'reveal' ? s.person.clues.slice(0, inRound ? s.lastShown : s.person.clues.length) : [],
        totalClues: s.person.clues.length,
        nextClueAt: inRound && s.lastShown < s.person.clues.length ? s.roundStartedAt + s.lastShown * cfg.clueMs : null,
        roundEndsAt: s.roundEndsAt, revealEndsAt: s.phase === 'reveal' ? s.revealEndsAt : null,
        scores: s.scores,
        players: s.players.map(u => ({ userId: u, username: s.names[u] })),
        solvedBy: Object.keys(s.solved),
        you: { attemptsLeft: cfg.maxAttempts - (s.attempts[uid] ?? 0), solved: s.solved[uid] !== undefined },
        reveal: s.phase === 'round' ? null : s.reveal,   // the answer is only sent after the round ends
      };
    },

    isFinished: s => s.phase === 'finished',

    getResult(s) {
      const ranking = s.players.map(u => ({ userId: u, username: s.names[u], score: s.scores[u] }))
        .sort((a, b) => b.score - a.score);
      let rank = 0;
      ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
      return { gameType: 'guess_person', scores: s.scores, ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
    },
  };
}
module.exports = { game: createGuessPerson(), createGuessPerson };
