const { EventEmitter } = require('events');
const crypto = require('crypto');
const { GameError } = require('../errors');
const registry = require('../games/registry');
const { MemoryRoomStore } = require('./RoomStore');

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

class RoomManager extends EventEmitter {
  constructor({ store = new MemoryRoomStore(), graceMs = 60000 } = {}) {
    super();
    this.store = store;
    this.graceMs = graceMs;
    this.userRoom = new Map();   // userId -> room code
    this.timers = new Map();     // userId -> grace timer
  }

  _code() {
    for (let i = 0; i < 50; i++) {
      const b = crypto.randomBytes(6);
      const code = Array.from(b, x => CHARS[x % CHARS.length]).join('');
      if (!this.store.has(code)) return code;
    }
    throw new GameError('INTERNAL', 'could not allocate code');
  }
  get(code) { return this.store.get(code); }
  roomOf(userId) { const c = this.userRoom.get(userId); return c ? this.store.get(c) : null; }
  _mustRoom(userId) {
    const r = this.roomOf(userId);
    if (!r) throw new GameError('NOT_IN_ROOM');
    return r;
  }
  _changed(room) { this.emit('room_changed', room.code); }

  createRoom(user, { gameType, maxPlayers }) {
    if (this.userRoom.has(user.userId)) throw new GameError('ALREADY_IN_ROOM');
    const game = registry.get(gameType);
    if (!game) throw new GameError('INVALID_PAYLOAD', 'unknown gameType');
    if (![2, 3, 4].includes(maxPlayers) || maxPlayers < game.minPlayers || maxPlayers > game.maxPlayers)
      throw new GameError('INVALID_PAYLOAD', 'maxPlayers must be 2, 3 or 4 and supported by the game');
    const code = this._code();
    const room = { code, gameType, maxPlayers, hostId: user.userId, status: 'lobby', players: [], game: null, seqs: {}, createdAt: Date.now() };
    room.players.push({ ...user, ready: true, connected: true });
    this.store.set(code, room);
    this.userRoom.set(user.userId, code);
    return room;
  }

  joinRoom(user, code) {
    if (this.userRoom.has(user.userId)) throw new GameError('ALREADY_IN_ROOM');
    const room = this.store.get(code);
    if (!room) throw new GameError('ROOM_NOT_FOUND');
    if (room.status !== 'lobby') throw new GameError('GAME_IN_PROGRESS');
    if (room.players.length >= room.maxPlayers) throw new GameError('ROOM_FULL');
    room.players.push({ ...user, ready: false, connected: true });
    this.userRoom.set(user.userId, code);
    this._changed(room);
    return room;
  }

  leave(userId) {
    this._mustRoom(userId);
    this._removePlayer(userId);
  }

  _removePlayer(userId) {
    const room = this.roomOf(userId);
    clearTimeout(this.timers.get(userId)); this.timers.delete(userId);
    this.userRoom.delete(userId);
    if (!room) return;
    room.players = room.players.filter(p => p.userId !== userId);
    delete room.seqs[userId];
    if (room.players.length === 0) { this.store.delete(room.code); this.emit('room_closed', room.code); return; }
    if (room.hostId === userId) {
      room.hostId = (room.players.find(p => p.connected) || room.players[0]).userId;
      room.players.find(p => p.userId === room.hostId).ready = true;
    }
    if (room.status !== 'lobby' && room.players.length < 2) {
      this._toLobby(room);
      this.emit('game_aborted', room.code);
    }
    this._changed(room);
  }

  _toLobby(room) {
    room.status = 'lobby'; room.game = null; room.seqs = {};
    for (const p of room.players) p.ready = p.userId === room.hostId;
  }

  setReady(userId, ready) {
    const room = this._mustRoom(userId);
    if (room.status !== 'lobby') throw new GameError('BAD_PHASE');
    if (userId === room.hostId) return room;           // host is always ready
    room.players.find(p => p.userId === userId).ready = !!ready;
    this._changed(room);
    return room;
  }

  startGame(userId) {
    const room = this._mustRoom(userId);
    if (room.hostId !== userId) throw new GameError('NOT_HOST');
    if (room.status !== 'lobby') throw new GameError('BAD_PHASE');
    const game = registry.get(room.gameType);
    if (!game.implemented) throw new GameError('GAME_NOT_AVAILABLE');
    if (room.players.length < Math.max(2, game.minPlayers)) throw new GameError('NOT_ENOUGH_PLAYERS');
    if (!room.players.every(p => p.ready && p.connected)) throw new GameError('PLAYERS_NOT_READY');
    room.status = 'playing';
    room.game = game.create(room);
    room.seqs = {};
    this._changed(room);
    return room;
  }

  gameAction(userId, { type, payload, seq }) {
    const room = this._mustRoom(userId);
    if (room.status !== 'playing') throw new GameError('BAD_PHASE');
    if ((room.seqs[userId] ?? -1) >= seq) throw new GameError('DUPLICATE_ACTION');
    room.seqs[userId] = seq;
    const game = registry.get(room.gameType);
    const response = game.onAction(room.game, userId, { type, payload }, Date.now());   // throws GameError if invalid
    let result = null;
    if (game.isFinished(room.game)) {
      room.status = 'finished';
      result = game.getResult(room.game);
    }
    this._changed(room);
    this.emit('game_updated', room.code, result);
    return { room, result, response };
  }

  // Server clock: advances timed phases (clue reveals, round ends). Called every ~250ms.
  tick(now = Date.now()) {
    for (const room of this.store.values()) {
      if (room.status !== 'playing') continue;
      const game = registry.get(room.gameType);
      try {
        if (!game.onTick || !game.onTick(room.game, now)) continue;
        let result = null;
        if (game.isFinished(room.game)) { room.status = 'finished'; result = game.getResult(room.game); this._changed(room); }
        this.emit('game_updated', room.code, result);
      } catch (e) { console.error('[tick]', room.code, e); }
    }
  }

  returnToLobby(userId) {
    const room = this._mustRoom(userId);
    if (room.hostId !== userId) throw new GameError('NOT_HOST');
    if (room.status === 'lobby') throw new GameError('BAD_PHASE');
    this._toLobby(room);
    this._changed(room);
    return room;
  }

  markDisconnected(userId) {
    const room = this.roomOf(userId);
    if (!room) return;
    room.players.find(p => p.userId === userId).connected = false;
    this.emit('player_disconnected', room.code, userId);
    this._changed(room);
    const t = setTimeout(() => { this.timers.delete(userId); this._removePlayer(userId); }, this.graceMs);
    t.unref();
    this.timers.set(userId, t);
  }

  reconnect(userId) {
    const room = this.roomOf(userId);
    if (!room) return null;
    clearTimeout(this.timers.get(userId)); this.timers.delete(userId);
    room.players.find(p => p.userId === userId).connected = true;
    this.emit('player_reconnected', room.code, userId);
    this._changed(room);
    return room;
  }

  publicRoom(room) {
    return {
      code: room.code, gameType: room.gameType, maxPlayers: room.maxPlayers, hostId: room.hostId, status: room.status,
      players: room.players.map(({ userId, username, avatar, ready, connected }) => ({ userId, username, avatar, ready, connected })),
    };
  }
}
module.exports = { RoomManager };
