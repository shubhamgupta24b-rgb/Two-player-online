const { GameError } = require('../../errors');

// Games whose rules run on the host's phone (the same code as the one-device version).
// The server just relays: guests' inputs go to the host, the host's state goes to everyone.
const RELAY_GAMES = [
  { id: 'colour_clash', min: 2, max: 6 },
  { id: 'ludo', min: 2, max: 4 },
  { id: 'ludo_teams', min: 4, max: 4 },
  { id: 'snakes_ladders', min: 2, max: 6 },
  { id: 'dots_boxes', min: 2, max: 4 },
  { id: 'tic_tac_toe', min: 2, max: 2 },
  { id: 'connect_four', min: 2, max: 2 },
  { id: 'truth_dare', min: 2, max: 6 },
  { id: 'math_duel', min: 2, max: 4 },
  { id: 'reaction_tap', min: 2, max: 6 },
  { id: 'air_hockey', min: 2, max: 2 },
  { id: 'ping_pong', min: 2, max: 2 },
  { id: 'snake_duel', min: 2, max: 2 },
  { id: 'penalty', min: 2, max: 2 },
  { id: 'find_spy', min: 3, max: 6 },
  { id: 'undercover', min: 3, max: 6 },
  { id: 'mafia', min: 4, max: 6 },
  { id: 'charades', min: 2, max: 6 },
  { id: 'heads_up', min: 2, max: 6 },
  { id: 'draw_guess', min: 2, max: 6 },
  { id: 'most_likely', min: 3, max: 6 },
  { id: 'would_rather', min: 2, max: 6 },
  { id: 'hand_cricket', min: 2, max: 2 },
  { id: 'quiz_battle', min: 2, max: 4 },
  { id: 'basketball_hoops', min: 2, max: 4 },
  { id: 'rock_paper_scissors', min: 2, max: 6 },
  { id: 'fruit_merge_battle', min: 2, max: 4 },
];

const MAX_STATE_BYTES = 64 * 1024;
const MAX_QUEUE = 200;
const NAME_RE = /^[a-zA-Z][a-zA-Z0-9_]{0,23}$/;

function createRelayGame({ id, min, max }) {
  return {
    id, minPlayers: min, maxPlayers: max, implemented: true, relay: true,

    create(room) {
      if (room.players.length < min || room.players.length > max) throw new GameError('NOT_ENOUGH_PLAYERS');
      const players = room.players.map(p => p.userId);
      return {
        players,
        names: Object.fromEntries(room.players.map(p => [p.userId, p.username])),
        host: players.includes(room.hostId) ? room.hostId : players[0],
        state: null, version: 0,
        inputs: [], inputSeq: 0,
        finished: false, scores: null,
      };
    },

    onAction(s, uid, { type, payload }) {
      if (!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if (s.finished) throw new GameError('BAD_PHASE');
      const p = payload || {};
      if (type === 'relay:state') {
        if (uid !== s.host) throw new GameError('NOT_HOST');
        if (typeof p.state !== 'object' || p.state === null || Array.isArray(p.state)) throw new GameError('INVALID_PAYLOAD');
        if (JSON.stringify(p.state).length > MAX_STATE_BYTES) throw new GameError('INVALID_PAYLOAD', 'state too large');
        s.state = p.state;
        s.version++;
        if (Number.isInteger(p.ack)) s.inputs = s.inputs.filter(i => i.seq > p.ack);
        return { version: s.version };
      }
      if (type === 'relay:input') {
        if (typeof p.name !== 'string' || !NAME_RE.test(p.name) || !Array.isArray(p.args) || p.args.length > 8) throw new GameError('INVALID_PAYLOAD');
        if (!p.args.every(a => a === null || ['number', 'string', 'boolean'].includes(typeof a))) throw new GameError('INVALID_PAYLOAD');
        s.inputs.push({ seq: ++s.inputSeq, from: uid, name: p.name, args: p.args });
        if (s.inputs.length > MAX_QUEUE) s.inputs.splice(0, s.inputs.length - MAX_QUEUE);
        return { seq: s.inputSeq };
      }
      if (type === 'relay:finish') {
        if (uid !== s.host) throw new GameError('NOT_HOST');
        const scores = p.scores;
        if (!Array.isArray(scores) || scores.length !== s.players.length || !scores.every(Number.isInteger)) throw new GameError('INVALID_PAYLOAD');
        s.scores = Object.fromEntries(s.players.map((u, i) => [u, scores[i]]));
        s.finished = true;
        return {};
      }
      throw new GameError('INVALID_ACTION');
    },

    getPublicState(s, uid) {
      return {
        gameType: id, relay: true, host: s.host,
        players: s.players.map(u => ({ userId: u, username: s.names[u] })),
        state: s.state, version: s.version,
        // Only the host needs the input queue.
        inputs: uid === s.host ? s.inputs : [],
        finished: s.finished,
      };
    },

    isFinished: s => s.finished,

    getResult(s) {
      const ranking = s.players.map(u => ({ userId: u, username: s.names[u], score: s.scores[u] })).sort((a, b) => b.score - a.score);
      let rank = 0;
      ranking.forEach((r, i) => { if (i === 0 || r.score < ranking[i - 1].score) rank = i + 1; r.rank = rank; });
      return { gameType: id, scores: s.scores, ranking, winners: ranking.filter(r => r.rank === 1).map(r => r.userId) };
    },
  };
}

module.exports = { RELAY_GAMES, createRelayGame, games: RELAY_GAMES.map(createRelayGame) };
