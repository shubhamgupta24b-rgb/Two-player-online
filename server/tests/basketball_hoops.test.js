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

const room = (...ids) => ({ players: ids.map(userId => ({ userId, username: userId.toUpperCase() })) });
const shoot = (g, s, u, timing, now) => g.onAction(s, u, { type: 'basketball:shoot', payload: { timing } }, now);

test('Basketball Hoops target moves every cycle using the fixed formula', () => {
  const game = createBasketballHoops({ targetCycleMs: 1000 });
  const s = game.create(room('a', 'b'), 0);
  for (let cycle = 0; cycle < 5; cycle++) {
    assert.strictEqual(game.getPublicState(s, 'a', cycle * 1000 + 500).target, (cycle * 37 + 23) % 101);
  }
  assert.strictEqual(game.getPublicState(s, 'a', -50).target, 23, 'clock skew before start clamps to cycle 0');
});

test('Basketball Hoops points tiers at their exact boundaries', () => {
  const game = createBasketballHoops({ targetCycleMs: 100000, shotCooldownMs: 0 });
  const s = game.create(room('a', 'b'), 0); // target stays 23
  const cases = [[23, 3], [30, 3], [16, 3], [31, 2], [41, 2], [42, 1], [55, 1], [56, 0], [0, 1], [100, 0]];
  let total = 0, t = 1;
  for (const [timing, pts] of cases) {
    assert.strictEqual(shoot(game, s, 'a', timing, t++).points, pts, `timing ${timing}`);
    total += pts;
  }
  assert.strictEqual(s.score.a, total);
  assert.strictEqual(s.shots.a, cases.length);
});

test('Basketball Hoops rejects bad input and enforces the per-player cooldown', () => {
  const game = createBasketballHoops({ durationMs: 5000, shotCooldownMs: 500 });
  const s = game.create(room('a', 'b'), 0);
  for (const timing of [undefined, 'abc', -1, 101, NaN, Infinity]) {
    assert.throws(() => shoot(game, s, 'a', timing, 10), e => e.code === 'INVALID_PAYLOAD', String(timing));
  }
  assert.throws(() => game.onAction(s, 'a', { type: 'basketball:shoot' }, 10), e => e.code === 'INVALID_PAYLOAD');
  assert.throws(() => shoot(game, s, 'x', 50, 10), e => e.code === 'NOT_IN_GAME');
  assert.throws(() => game.onAction(s, 'a', { type: 'crush_it:tap', payload: {} }, 10), e => e.code === 'INVALID_ACTION');
  assert.strictEqual(s.shots.a, 0, 'rejected shots do not count');

  shoot(game, s, 'a', 50, 1000);
  assert.throws(() => shoot(game, s, 'a', 50, 1499), e => e.code === 'SHOT_COOLDOWN');
  assert.doesNotThrow(() => shoot(game, s, 'b', 50, 1499), 'cooldown is per player');
  assert.doesNotThrow(() => shoot(game, s, 'a', 50, 1500));
  assert.strictEqual(game.getPublicState(s, 'a', 1500).nextShotAt, 2000);
});

test('Basketball Hoops accepts numeric strings and rejects shots after time', () => {
  const game = createBasketballHoops({ durationMs: 1000 });
  const s = game.create(room('a', 'b'), 0);
  assert.strictEqual(shoot(game, s, 'a', '23', 10).points, 3);
  assert.throws(() => shoot(game, s, 'b', 23, 1000), e => e.code === 'BAD_PHASE');
  game.onTick(s, 1000);
  assert.throws(() => shoot(game, s, 'b', 23, 1001), e => e.code === 'BAD_PHASE');
  assert.strictEqual(game.onTick(s, 2000), false);
});

test('Basketball Hoops ties on points share first place', () => {
  const game = createBasketballHoops({ durationMs: 1000, shotCooldownMs: 0, targetCycleMs: 100000 });
  const s = game.create(room('a', 'b', 'c'), 0);
  shoot(game, s, 'a', 90, 1); // 0 pts, 1 shot
  game.onTick(s, 1000);
  const r = game.getResult(s);
  assert.deepStrictEqual(r.winners, ['a', 'b', 'c']);
  assert.strictEqual(r.ranking[0].userId, 'a', 'more shots sorts first among equal scores');
  assert.ok(r.ranking.every(x => x.rank === 1));
});
