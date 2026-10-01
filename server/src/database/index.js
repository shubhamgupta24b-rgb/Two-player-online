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
module.exports = { connectDb, upsertUser };
