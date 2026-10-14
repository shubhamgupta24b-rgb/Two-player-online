const config = require('../config');
let User = null;
async function connectDb() {
  if (!config.mongoUri) { console.log('[db] MONGO_URI not set, profiles disabled'); return; }
  const mongoose = require('mongoose');
  await mongoose.connect(config.mongoUri);
  const stats = () => ({ played: { type: Number, default: 0 }, won: { type: Number, default: 0 }, best: { type: Number, default: 0 } });
  const games = ['guess_person', 'crush_it', 'basketball_hoops', 'fruit_duel', 'memory', 'paint_fight'];
  User = mongoose.models.User || mongoose.model('User', new mongoose.Schema({
    _id: String, username: String, avatar: String,
    gamesPlayed: { type: Number, default: 0 }, gamesWon: { type: Number, default: 0 },
    stats: Object.fromEntries(games.map(g => [g, stats()])),
  }, { timestamps: { createdAt: 'createdAt', updatedAt: false } }));
  console.log('[db] connected');
}
async function upsertUser({ userId, username, avatar }) {
  if (!User) return;
  await User.updateOne({ _id: userId }, { $setOnInsert: { username, avatar } }, { upsert: true });
}

/** Adds one finished online game. Winners each get a win; everyone who played gets a game. */
async function recordMatch(players, winnerIds) {
  if (!User || !players.length) return false;
  const winners = new Set(winnerIds);
  for (const p of players) {
    await User.updateOne(
      { _id: p.userId },
      { $set: { username: p.username || 'Player' }, $inc: { gamesPlayed: 1, gamesWon: winners.has(p.userId) ? 1 : 0 } },
      { upsert: true },
    );
  }
  return true;
}

/** Top players by wins, then games played, then name. Null when the database is off. */
async function leaderboard(limit = 20) {
  if (!User) return null;
  const rows = await User.find({ gamesPlayed: { $gt: 0 } })
    .sort({ gamesWon: -1, gamesPlayed: -1, username: 1 })
    .limit(limit)
    .lean();
  return rows.map(r => ({
    userId: String(r._id),
    username: r.username || 'Player',
    wins: r.gamesWon || 0,
    played: r.gamesPlayed || 0,
  }));
}

module.exports = { connectDb, upsertUser, recordMatch, leaderboard };
