const { GameError } = require('../../errors');

function createBasketballHoops(opts = {}) {
  const durationMs = opts.durationMs ?? 30000;
  const shotCooldownMs = opts.shotCooldownMs ?? 500;
  const targetCycleMs = opts.targetCycleMs ?? 1200;
  return {
    id: 'basketball_hoops', minPlayers: 2, maxPlayers: 4, implemented: true,
    create(room, now = Date.now()) {
      return {
        players: room.players.map(p => p.userId),
        names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
        score: Object.fromEntries(room.players.map(p => [p.userId, 0])),
        shots: Object.fromEntries(room.players.map(p => [p.userId, 0])),
        lastShotAt: Object.fromEntries(room.players.map(p => [p.userId, -Infinity])),
        startedAt: now, endsAt: now + durationMs, targetCycleMs, phase: 'playing',
      };
    },
    onAction(s, uid, { type, payload }, now = Date.now()) {
      if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if (type !== 'basketball:shoot') throw new GameError('INVALID_ACTION');
      if (s.phase !== 'playing' || now >= s.endsAt) throw new GameError('BAD_PHASE');
      if (now - s.lastShotAt[uid] < shotCooldownMs) throw new GameError('SHOT_COOLDOWN');
      const timing = Number(payload?.timing);
      if (!Number.isFinite(timing) || timing < 0 || timing > 100) throw new GameError('INVALID_PAYLOAD');
      const cycle = Math.floor((now - s.startedAt) / s.targetCycleMs);
      const target = (cycle * 37 + 23) % 101;
      const distance = Math.abs(timing - target);
      const points = distance <= 7 ? 3 : distance <= 18 ? 2 : distance <= 32 ? 1 : 0;
      s.lastShotAt[uid] = now; s.shots[uid]++; s.score[uid] += points;
      return { points, target, score: s.score[uid] };
    },
    onTick(s, now) {
      if (s.phase === 'playing' && now >= s.endsAt) { s.phase = 'finished'; return true; }
      return false;
    },
    getPublicState(s, uid, now = Date.now()) {
      const cycle = Math.floor(Math.max(0, now - s.startedAt) / s.targetCycleMs);
      return {
        gameType: 'basketball_hoops', phase: s.phase, startedAt: s.startedAt, endsAt: s.endsAt,
        targetCycleMs: s.targetCycleMs, target: (cycle * 37 + 23) % 101,
        players: s.players.map(userId => ({ userId, username: s.names[userId], score: s.score[userId], shots: s.shots[userId] })),
        yourScore: s.score[uid] ?? 0, yourShots: s.shots[uid] ?? 0,
        // -Infinity would arrive as null in JSON: "can shoot now" is just "since the start".
        nextShotAt: Math.max(s.startedAt, (s.lastShotAt[uid] ?? -Infinity) + shotCooldownMs),
      };
    },
    isFinished: s => s.phase === 'finished',
    getResult(s) {
      const ranking = s.players.map(userId => ({ userId, username: s.names[userId], score: s.score[userId], shots: s.shots[userId] }))
        .sort((a, b) => b.score - a.score || b.shots - a.shots);
      let rank = 0;
      ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
      return { gameType: 'basketball_hoops', scores: Object.fromEntries(s.players.map(u => [u, s.score[u]])), ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
    },
  };
}
module.exports = { game: createBasketballHoops(), createBasketballHoops };
