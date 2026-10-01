// Game plugin contract:
// { id, minPlayers, maxPlayers, implemented,
//   create(room) -> state, onAction(state, userId, {type,payload}), getPublicState(state, userId),
//   isFinished(state), getResult(state) }
const games = new Map();
const REQUIRED = ['create', 'onAction', 'getPublicState', 'isFinished', 'getResult'];
function register(mod) {
  if (mod.implemented) for (const f of REQUIRED) if (typeof mod[f] !== 'function') throw new Error(`game ${mod.id} missing ${f}`);
  games.set(mod.id, mod);
}
const get = id => games.get(id);
const has = id => games.has(id);
for (const id of ['crush_it', 'basketball_hoops', 'fruit_duel', 'paint_fight']) {
  register({ id, minPlayers: 2, maxPlayers: 4, implemented: false });
}
register(require('./guess_person').game);
register(require('./memory').game);
module.exports = { register, get, has };