import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/smash_karts/smash_karts_game.dart';

/// Runs the world for [ms] from [from] in 16 ms frames.
int run(SmashKartsLogic g, int from, int ms, [void Function(int t)? each]) {
  for (var t = from; t <= from + ms; t += 16) {
    g.update(t);
    each?.call(t);
  }
  return from + ms;
}

void main() {
  test('a kart drives where the stick points and stays inside the arena', () {
    final g = SmashKartsLogic(players: 2, random: Random(1));
    final start = g.karts[0].y;
    g.steer(0, -pi / 2, 1); // up
    run(g, 0, 1500);
    expect(g.karts[0].y, lessThan(start - 0.2));
    g.steer(0, pi, 1); // left, into the wall
    run(g, 1500, 5000);
    final k = g.karts[0];
    expect(k.x, greaterThanOrEqualTo(SmashKartsLogic.kartR - 1e-9));
    expect(k.y, inInclusiveRange(0, SmashKartsLogic.height));
  });

  test('karts never end up inside a crate', () {
    final g = SmashKartsLogic(players: 4, random: Random(2));
    final rng = Random(3);
    var t = 0;
    for (var i = 0; i < 60; i++) {
      for (var p = 0; p < 4; p++) {
        g.steer(p, rng.nextDouble() * 2 * pi, 1);
      }
      t = run(g, t, 300);
      for (final k in g.karts) {
        for (final (l, top, r, b) in SmashKartsLogic.obstacles) {
          final inside = k.x > l + 0.005 && k.x < r - 0.005 && k.y > top + 0.005 && k.y < b - 0.005;
          expect(inside, isFalse);
        }
      }
    }
  });

  test('driving over a box gives a power-up and the box comes back later', () {
    final g = SmashKartsLogic(players: 2, random: Random(4));
    final box = g.boxes.first;
    g.karts[0]
      ..x = box.x
      ..y = box.y + 0.2;
    g.steer(0, -pi / 2, 1);
    var t = run(g, 0, 1200);
    expect(g.karts[0].weapon, isNot(Weapon.none));
    expect(g.boxReady(box), isFalse);
    t = run(g, t, SmashKartsLogic.boxRespawnMs + 100);
    expect(g.boxReady(box), isTrue);
  });

  test('a rocket hits the kart ahead: a point, a spin-out, then a shield', () {
    final g = SmashKartsLogic(players: 2, random: Random(5));
    g.karts[0]
      ..x = 0.5
      ..y = 1.3
      ..angle = -pi / 2
      ..weapon = Weapon.rocket;
    g.karts[1]
      ..x = 0.5
      ..y = 1.0;
    g.fire(0);
    expect(g.karts[0].weapon, Weapon.none);
    run(g, 0, 600);
    expect(g.hits, [1, 0]);
    expect(g.stunned(1), isTrue);
    expect(g.lastEvent[0], '+1 SMASH!');
    // A second rocket during the shield does nothing.
    g.karts[0].weapon = Weapon.rocket;
    g.fire(0);
    run(g, 600, 600);
    expect(g.hits, [1, 0]);
  });

  test('a mine arms after a moment; driving into it is a hit (no point for yourself)', () {
    final g = SmashKartsLogic(players: 2, random: Random(6));
    g.karts[0]
      ..x = 0.2
      ..y = 0.6
      ..angle = 0
      ..weapon = Weapon.mine;
    g.fire(0);
    final mine = g.mines.single;
    // The rival drives over it after it's armed.
    g.karts[1]
      ..x = mine.x
      ..y = mine.y - 0.15;
    var t = run(g, 0, SmashKartsLogic.mineArmMs + 50);
    g.steer(1, pi / 2, 1);
    t = run(g, t, 1000);
    expect(g.mines, isEmpty);
    expect(g.hits[0], 1);
    // Your own mine hurts you but scores nothing.
    final h = SmashKartsLogic(players: 2, random: Random(7));
    h.mines.add(Mine(h.karts[0].x, h.karts[0].y, 0, -10000));
    run(h, 0, 100);
    expect(h.stunned(0), isTrue);
    expect(h.hits, [0, 0]);
  });

  test('bots pick up boxes and score hits over a match', () {
    final g = SmashKartsLogic(players: 4, random: Random(8));
    final bots = [for (var i = 0; i < 4; i++) BotSeat(i, Random(i + 10))];
    final turn = smashKartsInfo.bot!;
    run(g, 0, 120000, (t) {
      for (final b in bots) {
        turn(g, b, t);
      }
    });
    expect(g.finished, isTrue);
    expect(g.hits.reduce((a, b) => a + b), greaterThan(0), reason: 'the bots smash each other');
  });

  test('online: the host state loads into a guest; only your own kart takes your inputs', () {
    final spec = smashKartsInfo.online!;
    final host = spec.create(3) as SmashKartsLogic;
    host.karts[0].weapon = Weapon.rocket;
    host.fire(0);
    run(host, 0, 300);
    final guest = spec.create(3) as SmashKartsLogic;
    spec.load(guest, spec.save(host), 2);
    expect(guest.karts[0].x, closeTo(host.karts[0].x, 0.002));
    expect(guest.rockets.length, host.rockets.length);
    expect(guest.elapsedMs, host.elapsedMs);
    expect(spec.continuous, contains('steer'));
    spec.apply(host, 1, 'steer', [2, 1.0, 1.0]); // player 1 trying to drive player 3's kart
    expect(host.karts[2].stickPower, 0);
    spec.apply(host, 2, 'steer', [2, 1.0, 1.0]);
    expect(host.karts[2].stickPower, 1);
    expect(spec.save(host).toString().length, lessThan(20000));
  });
}
