const { recordMatch, leaderboard } = require('../database');

/** Wins recorded on this process. Used when Mongo is off, and as a live copy when it is on. */
const memory = new Map();

function resetBoard() {
  memory.clear();
}

function winnerIds(result) {
  if (!result) return [];
  if (Array.isArray(result.winners)) return result.winners.filter(id => typeof id === 'string');
  if (!Array.isArray(result.ranking)) return [];
  return result.ranking.filter(r => r && r.rank === 1 && typeof r.userId === 'string').map(r => r.userId);
}

function byWins(a, b) {
  return b.wins - a.wins || b.played - a.played || String(a.username).localeCompare(String(b.username));
}

/** Counts a finished game. Tied winners each receive a win. */
function noteResult(room, result) {
  if (!room || !result || !Array.isArray(room.players) || !room.players.length) return;
  const winners = new Set(winnerIds(result));
  const players = room.players
    .filter(p => p && typeof p.userId === 'string')
    .map(p => ({ userId: p.userId, username: p.username || 'Player' }));
  for (const p of players) {
    const row = memory.get(p.userId) || { userId: p.userId, username: p.username, wins: 0, played: 0 };
    row.username = p.username || row.username;
    row.played += 1;
    if (winners.has(p.userId)) row.wins += 1;
    memory.set(p.userId, row);
  }
  recordMatch(players, [...winners]).catch(e => console.error('[db] record match failed', e.message));
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
  return { source: 'memory', players: memoryTop(limit) };
}

module.exports = { noteResult, memoryTop, playingNow, ranked, resetBoard, byWins };
