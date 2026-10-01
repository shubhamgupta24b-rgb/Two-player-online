// In-memory store. Swap for a Redis-backed class with the same interface to scale out.
class MemoryRoomStore {
  constructor() { this.rooms = new Map(); }
  get(code) { return this.rooms.get(code); }
  set(code, room) { this.rooms.set(code, room); }
  delete(code) { this.rooms.delete(code); }
  values() { return this.rooms.values(); }
  has(code) { return this.rooms.has(code); }
}
module.exports = { MemoryRoomStore };
