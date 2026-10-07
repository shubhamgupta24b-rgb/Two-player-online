const test = require('node:test');
const assert = require('node:assert');
const { RoomManager } = require('../src/rooms/RoomManager');

const u = id => ({ userId: id, username: id, avatar: null });

test('quick play opens a public room, and the next quick player joins it', () => {
  const rm = new RoomManager();
  const a = rm.quickPlay(u('a'));
  assert.strictEqual(a.isPublic, true);
  assert.strictEqual(a.maxPlayers, 6);
  assert.strictEqual(rm.publicRoom(a).isPublic, true);
  const b = rm.quickPlay(u('b'));
  assert.strictEqual(b.code, a.code);
  assert.deepStrictEqual(b.players.map(p => p.userId), ['a', 'b']);
});

test('rooms made with a code are private: quick play never joins them', () => {
  const rm = new RoomManager();
  const priv = rm.createRoom(u('host'), { gameType: 'ludo', maxPlayers: 4 });
  const q = rm.quickPlay(u('x'));
  assert.notStrictEqual(q.code, priv.code);
  assert.strictEqual(rm.publicRoom(priv).isPublic, false);
});

test('quick play for one game only joins rooms set to that game', () => {
  const rm = new RoomManager();
  const ludo = rm.quickPlay(u('a'), { gameType: 'ludo' });
  assert.strictEqual(ludo.gameType, 'ludo');
  const bingo = rm.quickPlay(u('b'), { gameType: 'bingo' });
  assert.notStrictEqual(bingo.code, ludo.code);
  assert.strictEqual(rm.quickPlay(u('c'), { gameType: 'ludo' }).code, ludo.code);
  assert.strictEqual(rm.quickPlay(u('d')).code, ludo.code, 'any game: the fullest open room');
});

test('full, playing or abandoned rooms are skipped', () => {
  const rm = new RoomManager();
  const r = rm.quickPlay(u('p0'));
  for (let i = 1; i < 6; i++) rm.quickPlay(u(`p${i}`));
  assert.strictEqual(r.players.length, 6);
  assert.notStrictEqual(rm.quickPlay(u('late')).code, r.code, 'full');

  const rm2 = new RoomManager();
  const s = rm2.quickPlay(u('h'), { gameType: 'tic_tac_toe' });
  rm2.quickPlay(u('g'), { gameType: 'tic_tac_toe' });
  rm2.setReady('g', true);
  rm2.startGame('h');
  assert.notStrictEqual(rm2.quickPlay(u('x'), { gameType: 'tic_tac_toe' }).code, s.code, 'playing');

  const rm3 = new RoomManager();
  const gone = rm3.quickPlay(u('h'));
  gone.players[0].connected = false;
  assert.notStrictEqual(rm3.quickPlay(u('y')).code, gone.code, 'nobody connected');
});

test('unknown games and players already in a room are refused', () => {
  const rm = new RoomManager();
  const code = c => e => e.code === c;
  assert.throws(() => rm.quickPlay(u('a'), { gameType: 'nope' }), code('INVALID_PAYLOAD'));
  assert.throws(() => rm.quickPlay(u('a'), { gameType: 'guess_person' }), code('INVALID_PAYLOAD'));
  rm.quickPlay(u('a'));
  assert.throws(() => rm.quickPlay(u('a')), code('ALREADY_IN_ROOM'));
});
