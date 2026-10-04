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

/// Puts kart [p] somewhere open, facing [angle].
void place(SmashKartsLogic g, int p, double x, double y, [double angle = 0]) {
  g.karts[p]
    ..x = x
    ..y = y
    ..angle = angle
    ..speed = 0;
}

void main() {
  test('a kart drives where the stick points and stays inside the park', () {
    final g = SmashKartsLogic(players: 2, random: Random(1));
    final start = g.karts[0].y;
    g.steer(0, -pi / 2, 1); // up the screen
    run(g, 0, 1200);
    expect(g.karts[0].y, lessThan(start - 0.3));
    g.steer(0, pi, 1); // left, into the fence
    run(g, 1200, 6000);
    final k = g.karts[0];
    expect(k.x, greaterThanOrEqualTo(SmashKartsLogic.kartR - 1e-9));
    expect(k.y, inInclusiveRange(0, KartMap.size));
  });

  test('karts never end up inside a crate, wall or tree', () {
    final g = SmashKartsLogic(players: 4, random: Random(2));
    final rng = Random(3);
    var t = 0;
    for (var i = 0; i < 80; i++) {
      for (var p = 0; p < 4; p++) {
        g.steer(p, rng.nextDouble() * 2 * pi, 1);
      }
      t = run(g, t, 300);
      for (final k in g.karts) {
        for (final (l, top, r, b) in KartMap.blocks) {
          expect(k.x > l + 0.005 && k.x < r - 0.005 && k.y > top + 0.005 && k.y < b - 0.005, isFalse);
        }
        for (final (x, y, r) in KartMap.trees) {
          expect(sqrt((k.x - x) * (k.x - x) + (k.y - y) * (k.y - y)), greaterThan(r - 0.005));
        }
      }
    }
  });

  test('a mystery box gives a power-up and comes back later', () {
    final g = SmashKartsLogic(players: 2, random: Random(4));
    final box = g.boxes.first;
    place(g, 0, box.x, box.y + 0.25, -pi / 2);
    g.steer(0, -pi / 2, 1);
    var t = run(g, 0, 1000);
    expect(g.karts[0].weapon, isNot(Weapon.none));
    expect(g.boxReady(box), isFalse);
    t = run(g, t, SmashKartsLogic.boxRespawnMs + 100);
    expect(g.boxReady(box), isTrue);
  });

  test('a boost pad speeds you up', () {
    final g = SmashKartsLogic(players: 2, random: Random(5));
    final (px, py, _) = KartMap.pads.first;
    place(g, 0, px - 0.2, py, 0);
    g.steer(0, 0, 1);
    run(g, 0, 700);
    expect(g.boosted(0), isTrue);
  });

  test('a rocket wrecks the kart ahead: a point, a wreck, then a respawn with a shield', () {
    final g = SmashKartsLogic(players: 2, random: Random(6));
    place(g, 0, 1.2, 2.25, -pi / 2);
    place(g, 1, 1.2, 1.85);
    g.karts[0].weapon = Weapon.rocket;
    g.fire(0);
    var t = run(g, 0, 500);
    expect(g.kills, [1, 0]);
    expect(g.wrecked(1), isTrue);
    expect(g.feed.single.weapon, Weapon.rocket);
    expect(g.lastEvent[0], '+1 SMASH!');
    t = run(g, t, SmashKartsLogic.wreckMs + 100);
    expect(g.wrecked(1), isFalse);
    expect(g.karts[1].hp, SmashKartsLogic.maxHp);
    expect(g.shielded(1), isTrue, reason: 'shielded right after respawning');
  });

  test('machine-gun bullets take 1 HP each; three hits wreck', () {
    final g = SmashKartsLogic(players: 2, random: Random(7));
    place(g, 0, 1.2, 2.25, -pi / 2);
    place(g, 1, 1.2, 1.95);
    g.karts[0].weapon = Weapon.gun;
    g.fire(0);
    run(g, 0, 1200);
    expect(g.wrecked(1) || g.karts[1].hp < SmashKartsLogic.maxHp, isTrue);
  });

  test('a shield blocks hits; a triple rocket fires three', () {
    final g = SmashKartsLogic(players: 2, random: Random(8));
    place(g, 0, 1.2, 2.25, -pi / 2);
    place(g, 1, 1.2, 1.85);
    g.karts[1].weapon = Weapon.shield;
    g.fire(1);
    g.karts[0].weapon = Weapon.triple;
    g.fire(0);
    expect(g.shots.length, 3);
    run(g, 0, 600);
    expect(g.kills, [0, 0]);
    expect(g.karts[1].hp, SmashKartsLogic.maxHp);
  });

  test('a mine arms after a moment; your own mine scores nothing', () {
    final g = SmashKartsLogic(players: 2, random: Random(9));
    place(g, 0, 0.3, 0.8, 0);
    g.karts[0].weapon = Weapon.mine;
    g.fire(0);
    final mine = g.mines.single;
    place(g, 1, mine.x, mine.y - 0.2, pi / 2);
    var t = run(g, 0, SmashKartsLogic.mineArmMs + 50);
    g.steer(1, pi / 2, 1);
    t = run(g, t, 1000);
    expect(g.mines, isEmpty);
    expect(g.kills[0], 1);
    final h = SmashKartsLogic(players: 2, random: Random(10));
    h.mines.add(Mine(h.karts[0].x, h.karts[0].y, 0, -10000));
    run(h, 0, 100);
    expect(h.wrecked(0), isTrue);
    expect(h.kills, [0, 0]);
  });

  test('bots collect power-ups and wreck each other over a match', () {
    final g = SmashKartsLogic(players: 4, random: Random(11));
    final bots = [for (var i = 0; i < 4; i++) BotSeat(i, Random(i + 20))];
    final turn = smashKartsInfo.bot!;
    run(g, 0, 120000, (t) {
      for (final b in bots) {
        turn(g, b, t);
      }
    });
    expect(g.finished, isTrue);
    expect(g.kills.reduce((a, b) => a + b), greaterThan(0), reason: 'the bots smash each other');
  });

  test('online: the host state loads into a guest; only your own kart takes your inputs', () {
    final spec = smashKartsInfo.online!;
    final host = spec.create(3) as SmashKartsLogic;
    place(host, 0, 1.2, 2.25, -pi / 2);
    place(host, 1, 1.2, 1.85);
    host.karts[0].weapon = Weapon.rocket;
    host.fire(0);
    run(host, 0, 500);
    final guest = spec.create(3) as SmashKartsLogic;
    spec.load(guest, spec.save(host), 2);
    expect(guest.karts[1].x, closeTo(host.karts[1].x, 0.002));
    expect(guest.karts[1].hp, host.karts[1].hp);
    expect(guest.kills, host.kills);
    expect(guest.feed.length, host.feed.length);
    expect(guest.wrecked(1), host.wrecked(1));
    expect(spec.continuous, contains('steer'));
    spec.apply(host, 1, 'steer', [2, 1.0, 1.0]); // player 1 trying to drive player 3's kart
    expect(host.karts[2].stickPower, 0);
    spec.apply(host, 2, 'steer', [2, 1.0, 1.0]);
    expect(host.karts[2].stickPower, 1);
    expect(spec.save(host).toString().length, lessThan(20000));
  });
}
