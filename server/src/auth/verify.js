const config = require('../config');
let admin;
async function verifyToken(token) {
  if (typeof token !== 'string' || !token) throw new Error('no token');
  if (config.authMode === 'dev') {
    const m = /^dev:([A-Za-z0-9_-]{1,40})(?::(.{1,20}))?$/.exec(token);
    if (!m) throw new Error('bad dev token');
    return { uid: m[1], name: m[2] || `Guest-${m[1].slice(0, 4)}`, picture: null };
  }
  if (!admin) {
    admin = require('firebase-admin');
    if (!admin.apps.length) admin.initializeApp();
  }
  const d = await admin.auth().verifyIdToken(token);
  return { uid: d.uid, name: d.name || `Guest-${d.uid.slice(0, 4)}`, picture: d.picture || null };
}
module.exports = { verifyToken };
