import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/solo/slot_cars.dart';

void main() {
  group('Slot Cars', () {
    test('is available in the local game collection as a solo game', () {
      final game = localGames.firstWhere((g) => g.id == 'slot_cars');
      expect(game.title, 'Slot Cars');
      expect(game.minPlayers, 1);
      expect(game.maxPlayers, 1);
      expect(game.play, isNotNull);
    });

    test('steering stays within the three lanes', () {
      final g = SlotCarsLogic(random: Random(1));
      expect(g.lane, 1);
      g.steer(-1);
      expect(g.lane, 0);
      g.steer(-1);
      expect(g.lane, 0);
      g.steer(1);
      expect(g.lane, 1);
      g.steer(1);
      expect(g.lane, 2);
      g.steer(1);
      expect(g.lane, 2);
    });

    test('time trial ends at 45 seconds and awards survival points', () {
      final g = SlotCarsLogic(random: Random(7));
      for (var t = 0; t <= SlotCarsLogic.durationMs + 1300; t += 16) {
        g.update(t);
      }
      g.update(SlotCarsLogic.durationMs + 1300);
      expect(g.over, isTrue);
      expect(g.finished, isTrue);
      expect(g.score, greaterThanOrEqualTo(0));
      expect(g.msLeft, 0);
    });

    test('obstacles are spawned during a run', () {
      final g = SlotCarsLogic(random: Random(4));
      for (var t = 0; t <= 2400; t += 16) {
        g.update(t);
      }
      expect(g.obstacles, isNotEmpty);
    });
  });
}
