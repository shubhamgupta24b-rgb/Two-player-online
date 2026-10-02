const crypto = require('crypto');
const { GameError } = require('../../errors');
const PEOPLE = require('./people.json');

const DEFAULTS = { rounds: 3, revealMs: 6000, people: PEOPLE, shuffle: true };

const shuffle = a => { const r = [...a]; for (let i = r.length - 1; i > 0; i--) { const j = crypto.randomInt(i + 1); [r[i], r[j]] = [r[j], r[i]]; } return r; };
const ordered = (values, order) => [...new Set(values)].sort((a, b) => (order.indexOf(a) + 1 || 99) - (order.indexOf(b) + 1 || 99));

// Same questions (ids, wording, categories) as the app's pass-and-play version. Questions that
// can't split the board are dropped. Answers are always computed here, from the real secret.
function buildQuestions(people) {
  const q = (id, label, prompt, category, test) => ({ id, label, prompt, category, test });
  const visibleHair = people.filter(p => p.hairStyle !== 'bald');
  const all = [
    q('male', 'MALE', 'Is the person male?', 'gender', p => p.gender === 'male'),
    q('female', 'FEMALE', 'Is the person female?', 'gender', p => p.gender === 'female'),
    ...ordered(people.map(p => p.eyeColor), ['brown', 'blue', 'green']).map(c =>
      q(`eyes_${c}`, c.toUpperCase(), `Does the person have ${c} eyes?`, 'eyes', p => p.eyeColor === c)),
    q('long_hair', 'LONG', 'Does the person have long hair?', 'hair', p => p.hairStyle === 'long'),
    q('short_hair', 'SHORT', 'Does the person have short hair?', 'hair', p => p.hairStyle === 'short' || p.hairStyle === 'spiky'),
    q('curly', 'CURLY', 'Does the person have curly hair?', 'hair', p => p.hairStyle === 'curly'),
    q('bun', 'BUN', "Is the person's hair in a bun?", 'hair', p => p.hairStyle === 'bun'),
    q('spiky', 'SPIKY', 'Does the person have spiky hair?', 'hair', p => p.hairStyle === 'spiky'),
    q('bald', 'BALD', 'Is the person bald?', 'hair', p => p.hairStyle === 'bald'),
    ...ordered(visibleHair.map(p => p.hairColor), ['black', 'brown', 'blonde', 'red', 'gray']).map(c =>
      q(`hair_${c}`, c.toUpperCase(), `Does the person have ${c} hair?`, 'hair_color', p => p.hairStyle !== 'bald' && p.hairColor === c)),
    ...ordered(people.map(p => p.skinTone), ['light', 'tan', 'brown', 'dark']).map(c =>
      q(`skin_${c}`, c.toUpperCase(), `Does the person have ${c} skin?`, 'skin', p => p.skinTone === c)),
    q('glasses', 'GLASSES', 'Does the person wear glasses?', 'accessories', p => p.hasGlasses),
    q('hat', 'HAT', 'Is the person wearing a hat or cap?', 'accessories', p => p.hat !== 'none'),
    q('acc_earrings', 'EARRINGS', 'Is the person wearing earrings?', 'accessories', p => p.accessory === 'earrings'),
    q('acc_necklace', 'NECKLACE', 'Is the person wearing a necklace?', 'accessories', p => p.accessory === 'necklace'),
    q('acc_bowtie', 'BOW TIE', 'Is the person wearing a bow tie?', 'accessories', p => p.accessory === 'bowtie'),
    q('beard', 'BEARD', 'Does the person have a beard?', 'facial_hair', p => p.facialHair === 'beard'),
    // Beards are drawn with a mustache, so they count.
    q('mustache', 'MUSTACHE', 'Does the person have a mustache?', 'facial_hair', p => p.facialHair !== 'none'),
  ];
  return all.filter(x => { const yes = people.filter(x.test).length; return yes > 0 && yes < people.length; });
}

// Classic two-phone Guess Who. Each round both players secretly pick a person; then they take
// turns either asking one yes/no question about the opponent's person or making a final guess.
// A correct guess wins the round, a wrong guess gives the round to the opponent.
function createGuessWho(opts = {}) {
  const cfg = { ...DEFAULTS, ...opts };
  const questions = buildQuestions(cfg.people);
  const byId = new Map(cfg.people.map(p => [p.id, p]));
  const qById = new Map(questions.map(q => [q.id, q]));
  const other = (s, uid) => s.players.find(u => u !== uid);

  function startRound(s) {
    s.phase = 'choosing';
    s.board = cfg.shuffle ? shuffle(cfg.people.map(p => p.id)) : cfg.people.map(p => p.id);
    s.secrets = {};
    s.history = Object.fromEntries(s.players.map(u => [u, []]));
    s.turn = null;
    s.reveal = null;
    s.revealEndsAt = null;
  }

  function personId(payload) {
    const id = payload && payload.personId;
    if (!Number.isInteger(id) || !byId.has(id)) throw new GameError('INVALID_PAYLOAD');
    return id;
  }

  return {
    id: 'guess_who', minPlayers: 2, maxPlayers: 2, implemented: true,

    create(room) {
      if (room.players.length !== 2) throw new GameError('NOT_ENOUGH_PLAYERS');
      const s = {
        players: room.players.map(p => p.userId),
        names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
        scores: Object.fromEntries(room.players.map(p => [p.userId, 0])),
        round: 0, totalRounds: cfg.rounds,
      };
      startRound(s);
      return s;
    },

    onAction(s, uid, { type, payload }, now = Date.now()) {
      if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if (type === 'guess_who:choose') {
        if (s.phase !== 'choosing') throw new GameError('BAD_PHASE');
        s.secrets[uid] = personId(payload); // can change until both have chosen
        if (s.players.every(u => s.secrets[u] !== undefined)) {
          s.phase = 'playing';
          s.turn = s.players[s.round % 2]; // starting player alternates each round
        }
        return { chosen: s.secrets[uid] };
      }
      if (type === 'guess_who:ask') {
        if (s.phase !== 'playing') throw new GameError('BAD_PHASE');
        if (s.turn !== uid) throw new GameError('NOT_YOUR_TURN');
        const q = qById.get(payload && payload.questionId);
        if (!q) throw new GameError('INVALID_PAYLOAD');
        if (s.history[uid].some(h => h.questionId === q.id)) throw new GameError('ALREADY_ASKED');
        const answer = q.test(byId.get(s.secrets[other(s, uid)]));
        s.history[uid].push({ questionId: q.id, answer });
        s.turn = other(s, uid);
        return { questionId: q.id, answer };
      }
      if (type === 'guess_who:guess') {
        if (s.phase !== 'playing') throw new GameError('BAD_PHASE');
        if (s.turn !== uid) throw new GameError('NOT_YOUR_TURN');
        const guess = personId(payload);
        const opp = other(s, uid);
        const correct = guess === s.secrets[opp];
        const winner = correct ? uid : opp;
        s.scores[winner]++;
        s.phase = 'reveal';
        s.turn = null;
        s.reveal = { secrets: { ...s.secrets }, winner, guessedBy: uid, guess, correct };
        s.revealEndsAt = now + cfg.revealMs;
        return { correct, answer: s.secrets[opp] };
      }
      throw new GameError('INVALID_ACTION');
    },

    onTick(s, now) {
      if (s.phase !== 'reveal' || now < s.revealEndsAt) return false;
      if (s.round + 1 >= s.totalRounds) { s.phase = 'finished'; return true; }
      s.round++;
      startRound(s);
      return true;
    },

    getPublicState(s, uid) {
      const opp = other(s, uid);
      const showReveal = s.phase === 'reveal' || s.phase === 'finished';
      return {
        gameType: 'guess_who', phase: s.phase, round: s.round + 1, totalRounds: s.totalRounds,
        board: s.board,
        questions: questions.map(({ id, label, prompt, category }) => ({ id, label, prompt, category })),
        players: s.players.map(u => ({ userId: u, username: s.names[u], chosen: s.secrets[u] !== undefined })),
        scores: s.scores, turn: s.turn,
        // Your own secret only; the opponent's is never sent until the round is over.
        you: { secretId: s.secrets[uid] ?? null, asked: s.history[uid] ?? [] },
        opponentAsked: opp ? s.history[opp] : [],
        reveal: showReveal ? s.reveal : null,
        revealEndsAt: s.phase === 'reveal' ? s.revealEndsAt : null,
      };
    },

    isFinished: s => s.phase === 'finished',

    getResult(s) {
      const ranking = s.players.map(u => ({ userId: u, username: s.names[u], score: s.scores[u] })).sort((a, b) => b.score - a.score);
      let rank = 0;
      ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
      return { gameType: 'guess_who', scores: s.scores, ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
    },
  };
}
module.exports = { game: createGuessWho(), createGuessWho, buildQuestions, PEOPLE };
