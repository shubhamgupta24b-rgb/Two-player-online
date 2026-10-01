const http = require('http');
const express = require('express');
const { Server } = require('socket.io');
const config = require('./config');
const { RoomManager } = require('./rooms/RoomManager');
const { attachSockets } = require('./sockets');
const { connectDb } = require('./database');

function createServer({ graceMs = config.graceMs } = {}) {
  const app = express();
  app.get('/health', (_req, res) => res.json({ ok: true }));
  const httpServer = http.createServer(app);
  const io = new Server(httpServer, { cors: { origin: '*' } });
  const rooms = new RoomManager({ graceMs });
  attachSockets(io, rooms);
  const ticker = setInterval(() => rooms.tick(Date.now()), 250);
  ticker.unref();
  httpServer.on('close', () => clearInterval(ticker));
  return { httpServer, io, rooms };
}
module.exports = { createServer };

if (require.main === module) {
  connectDb().catch(e => console.error('[db] failed', e.message)).finally(() => {
    createServer().httpServer.listen(config.port, () => console.log(`server on :${config.port} (auth=${config.authMode})`));
  });
}
