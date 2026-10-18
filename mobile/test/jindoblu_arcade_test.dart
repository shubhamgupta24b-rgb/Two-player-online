import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/solo/jindoblu_arcade.dart';
import 'package:multiplayer_game/features/local_games/solo/slot_cars.dart';

void main() {
  test('ten new mini-games are registered and selectable', () {
    final ids = [
      'slot_cars', ...ArcadeMode.values.map((m) => 'j_${m.name}'),
    ];
    expect(ids.length, 10);
    for (final id in ids) {
      final matches = localGames.where((g) => g.id == id);
      expect(matches.length, 1, reason: 'Missing or duplicate game: $id');
      expect(matches.single.minPlayers, 1);
      expect(matches.single.maxPlayers, 1);
    }
  });

  test('each arcade game responds to taps and ends after 30 seconds', () {
    for (final mode in ArcadeMode.values) {
      final g = ArcadeLogic(mode, random: Random(5));
      final initial = g.score;
      final target = switch (mode) {
        ArcadeMode.hotPotato => g.cursor,
        ArcadeMode.flappyDunk => 0,
        ArcadeMode.ringToss => 0,
        ArcadeMode.fireworks || ArcadeMode.knifeHit => 0,
        _ => g.target,
      };
      g.hit(target);
      expect(g.taps, 1, reason: mode.name);
      expect(g.score, greaterThanOrEqualTo(initial), reason: mode.name);
      g.update(30000);
      expect(g.over, isTrue, reason: mode.name);
      g.update(31500);
      expect(g.finished, isTrue, reason: mode.name);
    }
  });

  test('knife hits reject repeated target and fireworks clear a board', () {
    final knife = ArcadeLogic(ArcadeMode.knifeHit);
    knife.hit(0);
    expect(knife.score, 2);
    knife.hit(0);
    expect(knife.score, 0);
    expect(knife.misses, 1);

    final fireworks = ArcadeLogic(ArcadeMode.fireworks);
    for (var i = 0; i < 9; i++) {
      fireworks.hit(i);
    }
    expect(fireworks.score, 14);
    expect(fireworks.occupied, isEmpty);
  });

  test('slot car steering and obstacles remain available', () {
    final g = SlotCarsLogic(random: Random(1));
    g.steer(1);
    expect(g.lane, 2);
    g.update(1000);
    expect(g.obstacles, isNotEmpty);
  });
}
