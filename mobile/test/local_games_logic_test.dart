import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/basketball/basketball_game.dart';
import 'package:multiplayer_game/features/local_games/crush_it/crush_it_game.dart';
import 'package:multiplayer_game/features/local_games/fruit_duel/fruit_duel_game.dart';
import 'package:multiplayer_game/features/local_games/memory/memory_game.dart';
import 'package:multiplayer_game/features/local_games/paint_fight/paint_fight_game.dart';

void main() {
  group('Crush It', () {
    test('counts taps per player and stops at the time limit', () {
      final g = CrushItLogic(durationMs: 10000);
      g.update(100);
      g.tap(0);
      g.tap(0);
      g.tap(1);
      expect(g.scores, [2, 1]);
      expect(g.secondsLeft, 10);
      g.update(10000);
      expect(g.finished, isTrue);
      g.tap(1);
      expect(g.scores, [2, 1]);
    });
  });

  group('Basketball Hoops', () {
    test('points by distance match the online version', () {
      expect(BasketballLogic.pointsFor(0), 3);
      expect(BasketballLogic.pointsFor(7), 3);
      expect(BasketballLogic.pointsFor(8), 2);
      expect(BasketballLogic.pointsFor(18), 2);
      expect(BasketballLogic.pointsFor(32), 1);
      expect(BasketballLogic.pointsFor(33), 0);
    });

    test('meter stays in 0..100 and shots respect the cooldown', () {
      final g = BasketballLogic(random: Random(1));
      for (var t = 0; t < 5000; t += 37) {
        g.update(t);
        expect(g.meter(0), inInclusiveRange(0, 100));
        expect(g.target, inInclusiveRange(15, 85));
      }
      g.update(6000);
      final pts = g.shoot(0);
      expect(pts, isNotNull);
      expect(g.score[0], pts);
      expect(g.shoot(0), isNull, reason: 'cooldown');
      g.update(6400);
      expect(g.shoot(0), isNull, reason: 'still cooling down');
      g.update(6500);
      expect(g.shoot(0), isNotNull);
      expect(g.shots[0], 2);
      expect(g.shots[1], 0);
    });

    test('a shot exactly on target scores 3', () {
      final g = BasketballLogic(random: Random(2));
      // Find a moment when player 1's meter is on the target.
      for (var t = 0; t < 30000; t++) {
        g.update(t);
        if ((g.meter(0) - g.target).abs() < 1) break;
      }
      expect(g.shoot(0), 3);
    });

    test('no shots after time is up', () {
      final g = BasketballLogic();
      g.update(30000);
      expect(g.finished, isTrue);
      expect(g.shoot(0), isNull);
    });
  });

  group('Fruit Duel', () {
    test('first correct slash +2, second +1, wrong lane 0, one try per fruit', () {
      final g = FruitDuelLogic(random: Random(3));
      g.update(10);
      final lane = g.fruitLane;
      final wrong = (lane + 1) % FruitDuelLogic.lanes;
      expect(g.slash(1, lane), 2);
      expect(g.slash(0, wrong), 0);
      expect(g.slash(0, lane), isNull, reason: 'already used this fruit');
      expect(g.scores, [0, 2]);

      // Next fruit: player 1 first this time.
      final before = g.current;
      for (var t = 10; g.current == before; t += 10) {
        g.update(t);
      }
      expect(g.slash(0, g.fruitLane), 2);
      expect(g.slash(1, g.fruitLane), 1);
      expect(g.scores, [2, 3]);
    });

    test('fruits never repeat a lane and speed up', () {
      final g = FruitDuelLogic(random: Random(4));
      var lastLane = -1, lastId = -1, changes = 0;
      for (var t = 0; t < 20000; t += 5) {
        g.update(t);
        if (g.current != lastId) {
          expect(g.fruitLane, isNot(lastLane));
          lastLane = g.fruitLane;
          lastId = g.current;
          changes++;
        }
      }
      // At a steady 1 fruit/second there would be 20; speeding up gives more.
      expect(changes, greaterThanOrEqualTo(24));
      g.update(20000);
      expect(g.finished, isTrue);
      expect(g.slash(0, 0), isNull);
    });
  });

  group('Memory', () {
    test('pairs score and keep the turn, misses pass the turn after a delay', () {
      final g = MemoryLogic(random: Random(5), mismatchMs: 900);
      int pairOf(int id) => g.cards.indexWhere((c) => c.id != id && c.symbol == g.cards[id].symbol);
      int notPairOf(int id) => g.cards.indexWhere((c) => c.id != id && c.symbol != g.cards[id].symbol);

      expect(g.flip(0), isTrue);
      expect(g.flip(pairOf(0)), isTrue);
      expect(g.pairs, [1, 0]);
      expect(g.turn, 0, reason: 'match = go again');

      final a = g.cards.indexWhere((c) => !c.matched);
      final b = g.cards.indexWhere((c) => !c.matched && c.symbol != g.cards[a].symbol);
      expect(notPairOf(a), isNot(-1));
      g.flip(a);
      g.flip(b);
      expect(g.showingMismatch, isTrue);
      expect(g.flip(g.cards.indexWhere((c) => !c.matched && c.id != a && c.id != b)), isFalse, reason: 'board locked during mismatch');
      g.update(899);
      expect(g.turn, 0);
      g.update(900);
      expect(g.turn, 1);
      expect(g.picks, isEmpty);
    });

    test('a full game ends when every pair is found', () {
      final g = MemoryLogic(random: Random(6));
      while (!g.finished) {
        final a = g.cards.firstWhere((c) => !c.matched);
        final b = g.cards.firstWhere((c) => !c.matched && c.id != a.id && c.symbol == a.symbol);
        g.flip(a.id);
        g.flip(b.id);
      }
      expect(g.pairs.reduce((x, y) => x + y), 12);
      expect(g.flip(0), isFalse);
    });

    test('cannot flip the same card twice or an out-of-range card', () {
      final g = MemoryLogic(random: Random(7));
      expect(g.flip(3), isTrue);
      expect(g.flip(3), isFalse);
      expect(g.flip(-1), isFalse);
      expect(g.flip(99), isFalse);
    });
  });

  group('Paint Fight', () {
    test('painting claims and steals cells, scores are cell counts', () {
      final g = PaintFightLogic(cols: 4, rows: 4);
      g.update(10);
      expect(g.paint(0, 0, 0), isTrue);
      expect(g.paint(0, 1, 0), isTrue);
      expect(g.paint(0, 1, 0), isFalse, reason: 'already mine');
      expect(g.paint(1, 1, 0), isTrue, reason: 'steal');
      expect(g.scores, [1, 1]);
      expect(g.paint(1, 9, 9), isFalse, reason: 'out of bounds');
      g.update(25000);
      expect(g.finished, isTrue);
      expect(g.paint(0, 2, 2), isFalse);
      expect(g.scores, [1, 1]);
    });
  });
}
