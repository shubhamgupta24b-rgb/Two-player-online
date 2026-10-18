import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/games/game_catalog.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/competitive/competitive_games.dart';

void main() {
  test('five online competitive games are registered in the hub and online catalogue', () {
    const expected = ['carrom','eight_ball_pool','darts','hot_potato','hungry_hippos'];
    for (final id in expected) {
      final local = localGames.where((g) => g.id == id).toList();
      final online = gameCatalog.where((g) => g.id == id).toList();
      expect(local, hasLength(1), reason: 'local registration: $id');
      expect(local.single.online, isNotNull, reason: 'relay support: $id');
      expect(online, hasLength(1), reason: 'online lobby entry: $id');
      expect(online.single.playable, isTrue, reason: 'online playable: $id');
    }
  });

  test('Carrom and 8-ball boards initialize with cue striker and serializable state', () {
    for (final mode in [CompetitiveMode.carrom, CompetitiveMode.eightBallPool]) {
      final game = CompetitiveLogic(mode, players: 2, random: Random(1));
      expect(game.balls.first.kind, 0);
      expect(game.balls.where((b) => !b.pocketed).length, greaterThan(5));
      final saved = game.save();
      final copy = CompetitiveLogic(mode, players: 2, random: Random(2));
      copy.loadState(saved);
      expect(copy.balls.length, game.balls.length);
      expect(copy.turn, game.turn);
      expect(copy.balls.first.x, closeTo(game.balls.first.x, 0.0001));
    }
  });

  test('Darts score by target distance and finish at 50 points', () {
    final game = CompetitiveLogic(CompetitiveMode.darts, players: 2, random: Random(4));
    for (var i = 0; i < 5 && !game.finished; i++) {
      game.throwDart(game.turn, .5, .5);
      if (!game.finished) {
        game.throwDart(game.turn, .5, .5);
        if (!game.finished) game.throwDart(game.turn, .5, .5);
      }
    }
    expect(game.finished, isTrue);
    expect(game.score[0], greaterThanOrEqualTo(50));
  });

  test('Hot Potato passes only from the current holder and Hungry Hippos consumes marbles', () {
    final potato = CompetitiveLogic(CompetitiveMode.hotPotato, players: 3, random: Random(8));
    final original = potato.potatoHolder;
    potato.pass((original + 1) % 3);
    expect(potato.potatoHolder, original);
    potato.pass(original);
    expect(potato.potatoHolder, isNot(original));

    final hippos = CompetitiveLogic(CompetitiveMode.hungryHippos, players: 4, random: Random(9));
    hippos.update(500);
    expect(hippos.marbles, greaterThan(0));
    final before = hippos.marbles;
    hippos.chomp(2);
    expect(hippos.marbles, before - 1);
    expect(hippos.score[2], 1);
  });
}
