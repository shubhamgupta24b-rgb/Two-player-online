import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/carrom/carrom_game.dart';
import 'package:multiplayer_game/features/local_games/eight_ball/eight_ball_game.dart';
import 'package:multiplayer_game/features/local_games/hungry_hippos/hungry_hippos_game.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/level_progress.dart';
import 'package:multiplayer_game/features/local_games/solo/ball_sort.dart';
import 'package:multiplayer_game/features/local_games/solo/chicken_jump.dart';
import 'package:multiplayer_game/features/local_games/solo/fruit_cut.dart';
import 'package:multiplayer_game/features/local_games/solo/hangman.dart';
import 'package:multiplayer_game/features/local_games/minesweeper/mine_race_game.dart';
import 'package:multiplayer_game/features/local_games/solo/knife_hit.dart';
import 'package:multiplayer_game/features/local_games/solo/minesweeper.dart';
import 'package:multiplayer_game/features/local_games/solo/sweet_swap.dart';
import 'package:multiplayer_game/features/local_games/tug_of_war/tug_of_war_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('removed games are not in the hub', () {
    final ids = localGames.map((g) => g.id).toSet();
    expect(ids, containsAll(['fruit_cut', 'chicken_jump']));
    expect(ids, isNot(contains('classic_snake')));
    expect(ids, isNot(contains('penalty')));
    expect(ids, isNot(contains('fruit_duel')));
    expect(ids, isNot(contains('snake_duel')));
    expect(ids, isNot(contains('crush_it')));
  });

  test('ball sort packs are solvable arrangements and get harder', () {
    int colorsOf(int tier, int level) => switch (tier) {
          0 => 2 + (level - 1) ~/ 17,
          1 => 4 + (level - 1) ~/ 25,
          _ => 6 + (level - 1) ~/ 26,
        };
    for (final tier in [0, 1, 2]) {
      final easy = dealSolvable(
          colors: colorsOf(tier, 1), seed: tier * 1000 + 1, steps: 6);
      final hard = dealSolvable(
          colors: colorsOf(tier, 50), seed: tier * 1000 + 50, steps: 20);
      for (final tubes in [easy, hard]) {
        final solved = tubes.every((t) =>
            t.isEmpty || (t.length == 4 && t.every((b) => b == t.first)));
        expect(solved, isFalse);
        expect(tubes.where((t) => t.isEmpty).length, greaterThan(0));
      }
      expect(colorsOf(tier, 50), greaterThan(colorsOf(tier, 1)));
    }
    final g = BallSortLogic(random: Random(1))..usePack(2, 50);
    expect(g.level, 50);
    expect(g.colors, greaterThanOrEqualTo(6));
    expect(g.solved, isFalse);
  });

  test('fruit cut scores a slice and ends on a bomb', () {
    final g = FruitCutLogic(random: Random(1), level: 1);
    g.pieces.add(CutPiece(
        id: 1, x: 0.5, y: 0.5, vx: 0, vy: 0, r: 0.05, bomb: false, tint: 0));
    g.slash(0.2, 0.5, 0.8, 0.5);
    expect(g.score, 1);
    g.pieces.add(CutPiece(
        id: 2, x: 0.5, y: 0.2, vx: 0, vy: 0, r: 0.05, bomb: true, tint: 0));
    g.slash(0.5, 0.0, 0.5, 0.4);
    expect(g.bombHit, isTrue);
    expect(g.over, isTrue);
  });

  test(
      'minesweeper levels change the field and hangman hint does not reveal the word',
      () {
    final easy = MinesweeperLogic()..applyTier(1);
    expect(easy.side, 8);
    expect(easy.mineTarget, 8);
    final hard = MinesweeperLogic()..applyTier(3);
    expect(hard.side, 12);
    expect(hard.mineTarget, 22);
    final h = HangmanLogic(random: Random(2));
    h.useHint();
    expect(h.hint, contains('starts with'));
    expect(h.hint, isNot(contains(h.word)));
    h.useHint();
    expect(h.hintUsed, isTrue);
  });

  test('clearing a level unlocks the next one', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await LevelProgress.unlocked('minesweeper'), 1);
    expect(await LevelProgress.markCleared('minesweeper', 1), 2);
    expect(await LevelProgress.unlocked('minesweeper'), 2);
    expect(await LevelProgress.markCleared('minesweeper', 1), 2);
  });

  test('sweet swap rejects a swap that matches nothing and scores a real match',
      () {
    final g = SweetLogic(random: Random(1));
    for (var i = 0; i < g.cells.length; i++) {
      final r = i ~/ SweetLogic.side, c = i % SweetLogic.side;
      g.cells[i] = (r + c).isEven ? 3 : 4;
    }
    g.cells[0] = 1;
    g.cells[1] = 1;
    g.cells[2] = 2;
    g.cells[2 + SweetLogic.side] = 1;
    final before = g.movesLeft;
    g.tap(5);
    g.tap(6);
    expect(g.movesLeft, before);
    g.tap(2);
    g.tap(2 + SweetLogic.side);
    expect(g.score, greaterThan(0));
    expect(g.movesLeft, before - 1);
  });

  test('knife throw sticks once and a second throw on the same angle fails',
      () {
    final g = KnifeLogic(random: Random(1), level: 1);
    var t = 0;
    g.throwKnife();
    while (g.score == 0 && t < 3000) {
      t += 40;
      g.step(t);
    }
    expect(g.score, 1);
    g.angle = g.stuck.first - 2.1 * 0.04 * 11;
    g.throwKnife();
    for (var i = 0; i < 11; i++) {
      t += 40;
      g.step(t);
    }
    expect(g.failed, isTrue);
  });

  test('tug of war ignores a second pull inside the gap', () {
    final g = TugLogic();
    g.pull(0);
    final rope = g.rope;
    g.pull(0);
    expect(g.rope, rope);
    g.now = 200;
    g.pull(0);
    expect(g.rope, lessThan(rope));
  });

  test('minesweeper race hides mines and gives both players the same field',
      () {
    final g = MineRaceLogic(seed: 3);
    expect(g.boards[0].mines, g.boards[1].mines);
    g.now = MineRaceLogic.countdown;
    final safe = [
      for (var i = 0; i < g.side * g.side; i++)
        if (!g.boards[0].mines.contains(i)) i
    ].first;
    g.open(0, safe);
    final saved = g.toMap();
    expect(saved.containsKey('mines'), isFalse);
    expect(saved.containsKey('seed'), isFalse);
    expect((saved['shown'] as List).first, contains(greaterThanOrEqualTo(0)));
  });

  test(
      'chicken jump and knife hit keep moving on screen, and a level change resets a throw',
      () {
    final chicken = ChickenLogic(random: Random(1));
    var paints = 0;
    chicken.addListener(() => paints++);
    final y = chicken.birdY;
    chicken.step(16);
    expect(chicken.birdY, isNot(y));
    expect(paints, greaterThan(0));

    final knife = KnifeLogic(random: Random(1), level: 1);
    var spins = 0;
    knife.addListener(() => spins++);
    final angle = knife.angle;
    knife.step(40);
    expect(knife.angle, isNot(angle));
    expect(spins, greaterThan(0));
    knife.throwKnife();
    expect(knife.flying, isTrue);
    knife.setLevel(2);
    expect(knife.level, 2);
    expect(knife.flying, isFalse);
    expect(knife.fly, 0);
  });

  test('minesweeper will not rebuild a board that has already been dug', () {
    final g = MinesweeperLogic()..applyTier(1);
    g.reveal(0);
    expect(g.placed, isTrue);
    g.applyTier(3);
    expect(g.side, 8);
    expect(g.tier, 1);
  });

  test('hungry hippos picks the leader when time runs out', () {
    final g = HippoLogic(players: 2, random: Random(1));
    g.got[0] = 3;
    g.got[1] = 1;
    g.update(HippoLogic.limit);
    expect(g.winner, 0);
    final tie = HippoLogic(players: 2, random: Random(2));
    tie.update(HippoLogic.limit);
    expect(tie.winner, isNull);
    expect(tie.finished, isTrue);
  });

  test('minesweeper race guest cannot apply a win, and only one player scores',
      () {
    final host = MineRaceLogic(seed: 5);
    host.now = MineRaceLogic.countdown;
    final guest = MineRaceLogic(seed: 9)..isGuest = true;
    mineRaceInfo.online!.load(guest, host.toMap(), 1);
    expect(guest.boards.every((b) => b.mines.isEmpty), isTrue);
    guest.now = MineRaceLogic.countdown;
    guest.open(0, 0);
    expect(guest.winner, isNull);
    expect(guest.status[0], 0);

    void sweep(MineRaceLogic g, int p) {
      var guard = 0;
      while (g.status[p] == 0 && guard++ < 80) {
        final hidden = [
          for (var i = 0; i < g.side * g.side; i++)
            if (!g.boards[p].mines.contains(i) && g.shown[p][i] < 0) i
        ];
        if (hidden.isEmpty) break;
        g.open(p, hidden.first);
      }
    }

    sweep(host, 0);
    sweep(host, 1);
    expect(host.winner, 0);
    expect(host.scores, [1, 0]);
    expect(host.toMap().containsKey('mines'), isFalse);
  });

  test('carrom and eight ball ignore an illegal or second shot and settle', () {
    final carrom = CarromLogic();
    carrom.shoot(0, 9, 40);
    final striker = carrom.disks.first;
    expect(striker.vx.abs(), lessThanOrEqualTo(3.2));
    expect(striker.vy.abs(), lessThanOrEqualTo(3.2));
    final y = striker.y;
    carrom.shoot(1, 0, 2);
    expect(carrom.turn, 0);
    expect(striker.y, y);

    final eight = EightLogic();
    eight.shoot(0, 4, 30);
    final cue = eight.disks.first;
    expect(cue.vx.abs(), lessThanOrEqualTo(3.4));
    expect(cue.vy.abs(), lessThanOrEqualTo(3.4));
    eight.shoot(1, 0, 2);
    expect(eight.turn, 0);

    for (var t = 16; t <= 9000 && (carrom.moving || eight.moving); t += 16) {
      if (carrom.moving) carrom.update(t);
      if (eight.moving) eight.update(t);
    }
    expect(carrom.moving, isFalse);
    expect(eight.moving, isFalse);

    final again = CarromLogic()..shoot(0, 0.2, 2.2);
    for (var t = 16; t <= 400; t += 16) {
      again.update(t);
    }
    final spec = carromInfo.online!;
    final saved = spec.save(again);
    final copy = spec.create(2) as CarromLogic;
    spec.load(copy, saved, -1);
    expect(spec.save(copy), saved);

    final eightSpec = eightBallInfo.online!;
    final shot = EightLogic()..shoot(0, 0.1, 2.4);
    for (var t = 16; t <= 400; t += 16) {
      shot.update(t);
    }
    final eightSaved = eightSpec.save(shot);
    final eightCopy = eightSpec.create(2) as EightLogic;
    eightSpec.load(eightCopy, eightSaved, -1);
    expect(eightSpec.save(eightCopy), eightSaved);
  });
}
