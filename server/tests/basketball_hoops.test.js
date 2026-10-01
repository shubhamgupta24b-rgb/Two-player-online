const test = require('node:test');
const assert = require('node:assert');
const { createBasketballHoops } = require('../src/games/basketball_hoops');

test('Basketball Hoops scores shots from server timing', () => {
  const game = createBasketballHoops({ durationMs: 5000, targetCycleMs: 1000, shotCooldownMs: 100 });
  const state = game.create({ players: [{ userId: 'a', username: 'A' }, { userId: 'b', username: 'B' }] }, 1000);
  const first = game.onAction(state, 'a', { type: 'basketball:shoot', payload: { timing: 23 } }, 1100);
  assert.strictEqual(first.points, 3);
  assert.strictEqual(first.target, 23);
  assert.strictEqual(state.score.a, 3);
  assert.throws(() => game.onAction(state, 'a', { type: 'basketball:shoot', payload: { timing: 23 } }, 1150), /SHOT_COOLDOWN/);
  const miss = game.onAction(state, 'b', { type: 'basketball:shoot', payload: { timing: 90 } }, 1200);
  assert.strictEqual(miss.points, 0);
  assert.strictEqual(state.score.b, 0);
});
test('Basketball Hoops finishes on server time and ranks players', () => {
  const game = createBasketballHoops({ durationMs: 1000 });
  const state = game.create({ players: [{ userId: 'a', username: 'A' }, { userId: 'b', username: 'B' }] }, 100);
  game.onAction(state, 'a', { type: 'basketball:shoot', payload: { timing: 23 } }, 200);
  assert.strictEqual(game.onTick(state, 1099), false);
  assert.strictEqual(game.onTick(state, 1100), true);
  assert.strictEqual(game.isFinished(state), true);
  assert.deepStrictEqual(game.getResult(state).winners, ['a']);
});
