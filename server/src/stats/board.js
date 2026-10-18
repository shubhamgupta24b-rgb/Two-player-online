const { recordMatch, leaderboard } = require('../database');

/** Wins recorded on this process. Used when Mongo is off, and as a live copy when it is on. */
const memory = new Map();
/** Match ids already counted. Stops one finished game from being recorded twice. */
const seen = new Set();

function resetBoard() {
  memory.clear();
  seen.clear();
}

function winnerIds(result) {
  if (!result) return [];
  if (Array.isArray(result.winners)) return result.winners.filter(id => typeof id === 'string' && id);
  if (!Array.isArray(result.ranking)) return [];
  return result.ranking.filter(r => r && r.rank === 1 && typeof r.userId === 'string' && r.userId).map(r => r.userId);
}

function winRate(row) {
  return row.played ? row.wins / row.played : 0;
}

/** Wins, then win rate, then games played, then name. */
function byWins(a, b) {
  if (b.wins !== a.wins) return b.wins - a.wins;
  const rate = winRate(b) - winRate(a);
  if (rate) return rate;
  return b.played - a.played || String(a.username).localeCompare(String(b.username));
}

function bumpGame(row, gameType, won, lost) {
  if (!gameType) return;
  row.games = row.games || {};
  const game = row.games[gameType] || { played: 0, wins: 0, losses: 0 };
  game.played += 1;
  if (won) game.wins += 1;
  if (lost) game.losses += 1;
  row.games[gameType] = game;
}

/**
 * Counts one finished match. A valid winner (or tied winners) is required.
 * The same matchId is ignored after the first call. Abandoned games never reach here.
 * Returns false when nothing was recorded.
 */
function noteResult(room, result) {
  if (!room || !result || !Array.isArray(room.players) || !room.players.length) return false;
  const winners = new Set(winnerIds(result));
  if (!winners.size) return false;
  const players = room.players
    .filter(p => p && typeof p.userId === 'string' && p.userId)
    .map(p => ({ userId: p.userId, username: p.username || 'Player' }));
  if (!players.length) return false;
  if (room.matchId) {
    if (seen.has(room.matchId)) return false;
    seen.add(room.matchId);
  }
  for (const p of players) {
    const row = memory.get(p.userId) || { userId: p.userId, username: p.username, wins: 0, played: 0, losses: 0, games: {} };
    row.username = p.username || row.username;
    row.losses = row.losses || 0;
    row.played += 1;
    const won = winners.has(p.userId);
    if (won) row.wins += 1;
    else row.losses += 1;
    bumpGame(row, room.gameType, won, !won);
    memory.set(p.userId, row);
  }
  recordMatch(players, [...winners]).catch(e => console.error('[db] record match failed', e.message));
  return true;
}

function memoryTop(limit = 20) {
  return [...memory.values()].sort(byWins).slice(0, limit);
}

/** Connected players in games that are actually in progress, grouped by game. */
function playingNow(rooms) {
  const counts = new Map();
  let total = 0;
  const list = rooms && rooms.store && typeof rooms.store.values === 'function' ? rooms.store.values() : [];
  for (const room of list) {
    if (!room || room.status !== 'playing') continue;
    const n = (room.players || []).filter(p => p && p.connected !== false).length;
    if (!n) continue;
    counts.set(room.gameType, (counts.get(room.gameType) || 0) + n);
    total += n;
  }
  const games = [...counts.entries()]
    .map(([id, playing]) => ({ id, playing }))
    .sort((a, b) => b.playing - a.playing || a.id.localeCompare(b.id));
  return { total, games };
}

/** Database ranking when it has rows; otherwise the in-memory board. Never invents players. */
async function ranked(limit = 20) {
  try {
    const rows = await leaderboard(limit);
    if (rows && rows.length) return { source: 'database', players: rows };
  } catch (e) {
    console.error('[db] leaderboard failed', e.message);
  }
  const players = memoryTop(limit).map(row => ({
    ...row,
    winRate: winRate(row),
  }));
  return { source: 'memory', players };
}

module.exports = { noteResult, memoryTop, playingNow, ranked, resetBoard, byWins };
