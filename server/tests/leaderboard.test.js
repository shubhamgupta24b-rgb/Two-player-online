const test = require('node:test');
const assert = require('node:assert');
const { RoomManager } = require('../src/rooms/RoomManager');
const { noteResult, memoryTop, playingNow, resetBoard } = require('../src/stats/board');

test('leaderboard ranks by wins, then win rate, then games played, then name', () => {
  resetBoard();
  noteResult(
    { players: [{ userId: 'zed', username: 'Zed' }, { userId: 'amy', username: 'Amy' }] },
    { winners: ['zed'] },
  );
  noteResult(
    { players: [{ userId: 'bea', username: 'Bea' }, { userId: 'amy', username: 'Amy' }] },
    { winners: ['bea'] },
  );
  noteResult(
    { players: [{ userId: 'ned', username: 'Ned' }, { userId: 'amy', username: 'Amy' }] },
    { winners: ['ned'] },
  );
  // Amy played 3 and won 0. Bea and Ned each won 1 from 1 game. Zed won 1 from 1 game.
  // More played does not outrank a win. Same wins and played: Amy is not in that tie.
  // Bea, Ned, Zed all have 1 win and 1 played except Zed is 1/1, Bea 1/1, Ned 1/1.
  const names = memoryTop(10).map(p => p.username);
  assert.deepStrictEqual(names.slice(0, 3), ['Bea', 'Ned', 'Zed']);
  assert.strictEqual(names[3], 'Amy');
  assert.strictEqual(memoryTop(10).find(p => p.username === 'Amy').played, 3);
  assert.strictEqual(memoryTop(10).find(p => p.username === 'Amy').wins, 0);
});

test('a tied finish gives every winner a win, and a higher win rate ranks above more games played', () => {
  resetBoard();
  noteResult(
    { players: [{ userId: 'a', username: 'Ann' }, { userId: 'b', username: 'Bo' }] },
    { winners: ['a', 'b'] },
  );
  noteResult(
    { players: [{ userId: 'a', username: 'Ann' }, { userId: 'c', username: 'Cy' }] },
    { winners: ['c'] },
  );
  // Ann: 1 win from 2 (50%). Bo and Cy: 1 win from 1 (100%). Same rate and played: name order.
  assert.deepStrictEqual(memoryTop(10).map(p => p.username), ['Bo', 'Cy', 'Ann']);
  assert.strictEqual(memoryTop(10).find(p => p.username === 'Ann').losses, 1);
  assert.strictEqual(memoryTop(10).find(p => p.username === 'Bo').losses, 0);
});

test('the same match is recorded once, and a match with no winner is ignored', () => {
  resetBoard();
  const room = {
    matchId: 'm1',
    gameType: 'ludo',
    players: [{ userId: 'a', username: 'Ada' }, { userId: 'b', username: 'Bo' }],
  };
  assert.strictEqual(noteResult(room, { winners: ['a'] }), true);
  assert.strictEqual(noteResult(room, { winners: ['b'] }), false);
  assert.strictEqual(noteResult({ players: room.players }, null), false);
  assert.strictEqual(noteResult({ players: room.players }, { winners: [] }), false);
  const top = memoryTop(10);
  assert.strictEqual(top.find(p => p.username === 'Ada').wins, 1);
  assert.strictEqual(top.find(p => p.username === 'Ada').played, 1);
  assert.strictEqual(top.find(p => p.username === 'Ada').games.ludo.wins, 1);
  assert.strictEqual(top.find(p => p.username === 'Bo').wins, 0);
  assert.strictEqual(top.find(p => p.username === 'Bo').losses, 1);
});

test('leaving a game before it finishes does not record a win', () => {
  resetBoard();
  const rooms = new RoomManager({ graceMs: 1000 });
  const room = rooms.createRoom({ userId: 'a', username: 'Ada' }, { gameType: 'tic_tac_toe', maxPlayers: 2 });
  rooms.joinRoom({ userId: 'b', username: 'Bo' }, room.code);
  rooms.setReady('b', true);
  rooms.startGame('a');
  rooms.leave('a');
  assert.deepStrictEqual(memoryTop(10), []);
});

test('playing now counts only connected players in live games', () => {
  resetBoard();
  const rooms = new RoomManager({ graceMs: 1000 });
  const lobby = rooms.createRoom({ userId: 'h', username: 'Host' }, { gameType: 'memory', maxPlayers: 2 });
  assert.strictEqual(playingNow(rooms).total, 0);
  rooms.joinRoom({ userId: 'g', username: 'Guest' }, lobby.code);
  rooms.setReady('g', true);
  rooms.startGame('h');
  const live = playingNow(rooms);
  assert.strictEqual(live.total, 2);
  assert.deepStrictEqual(live.games, [{ id: 'memory', playing: 2 }]);
});

test('finishing a relay game records the higher score as the win', () => {
  resetBoard();
  const rooms = new RoomManager({ graceMs: 1000 });
  const room = rooms.createRoom({ userId: 'a', username: 'Ada' }, { gameType: 'tic_tac_toe', maxPlayers: 2 });
  rooms.joinRoom({ userId: 'b', username: 'Bo' }, room.code);
  rooms.setReady('b', true);
  rooms.startGame('a');
  rooms.gameAction('a', { type: 'relay:finish', payload: { scores: [2, 5] }, seq: 1 });
  const top = memoryTop(10);
  assert.deepStrictEqual(top.map(p => ({ username: p.username, wins: p.wins, played: p.played })), [
    { username: 'Bo', wins: 1, played: 1 },
    { username: 'Ada', wins: 0, played: 1 },
  ]);
  assert.strictEqual(playingNow(rooms).total, 0);
});
