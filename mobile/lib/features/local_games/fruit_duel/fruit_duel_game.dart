import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class Slash {
  final int fruit;
  final int lane;
  final int points; // 0 = wrong lane
  const Slash(this.fruit, this.lane, this.points);
}

/// Like the online version (pick the fruit's lane, one slash per fruit, 20s) with a
/// duel twist for the shared screen: first correct slash +2, second +1. Fruits speed up.
class FruitDuelLogic extends TimedDuel {
  static const lanes = 3;
  static const fruits = ['🍉', '🍎', '🍊', '🍍', '🍇', '🍌', '🍓', '🥝'];
  final List<int> score;
  final List<int> hits;
  final List<Slash?> lastSlash;
  final List<int> _starts = [];
  final List<int> _lanes = [];
  final List<String> _emoji = [];
  int current = 0;
  bool _firstHitTaken = false;

  FruitDuelLogic({int durationMs = 20000, int players = 2, Random? random})
      : score = List.filled(players, 0),
        hits = List.filled(players, 0),
        lastSlash = List.filled(players, null),
        super(durationMs) {
    final r = random ?? Random();
    var t = 0;
    for (var i = 0; t < durationMs; i++) {
      _starts.add(t);
      // Never the same lane twice in a row, so every fruit visibly moves.
      var lane = r.nextInt(lanes);
      if (i > 0 && lane == _lanes.last) lane = (lane + 1 + r.nextInt(lanes - 1)) % lanes;
      _lanes.add(lane);
      _emoji.add(fruits[r.nextInt(fruits.length)]);
      t += max(550, 1000 - i * 15);
    }
  }

  @override
  List<int> get scores => score;
  int get fruitLane => _lanes[current];
  String get fruitEmoji => _emoji[current];
  int get fruitCount => _starts.length;

  /// 1 -> 0 as the current fruit's time runs out.
  double get fruitTimeLeft {
    final end = current + 1 < _starts.length ? _starts[current + 1] : durationMs;
    final span = end - _starts[current];
    return span <= 0 ? 0 : (1 - (elapsedMs - _starts[current]) / span).clamp(0.0, 1.0);
  }

  @override
  void onUpdate() {
    while (current + 1 < _starts.length && elapsedMs >= _starts[current + 1]) {
      current++;
      _firstHitTaken = false;
    }
  }

  bool slashedCurrent(int player) => lastSlash[player]?.fruit == current;

  /// Returns points scored, or null if this player already slashed this fruit.
  int? slash(int player, int lane) {
    if (finished || lane < 0 || lane >= lanes || slashedCurrent(player)) return null;
    var pts = 0;
    if (lane == fruitLane) {
      pts = _firstHitTaken ? 1 : 2;
      _firstHitTaken = true;
      hits[player]++;
      score[player] += pts;
    }
    lastSlash[player] = Slash(current, lane, pts);
    notifyListeners();
    return pts;
  }
}

final fruitDuelInfo = LocalGameInfo(
  id: 'fruit_duel',
  title: 'Fruit Duel',
  emoji: '🍉',
  color: const Color(0xFF2ECC71),
  tagline: 'Slice it before your rival does!',
  rules: const [
    'A fruit pops up in one of three lanes on both sides.',
    'Tap the lane with the fruit to slice it. One try per fruit!',
    'First to slice gets +2, second gets +1. Fruits get faster. 20 seconds.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  play: (players, onFinished) => TickingPlay<FruitDuelLogic>(
    create: () => FruitDuelLogic(),
    onFinished: onFinished,
    builder: (context, g) => SplitScreen(
      middle: DuelMiddleBar(players: players, scores: g.scores, secondsLeft: g.secondsLeft, progress: g.progress),
      half: (i) => _FruitHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _FruitHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final FruitDuelLogic g;
  const _FruitHalf({required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    final mine = g.lastSlash[index];
    final usedTry = g.slashedCurrent(index);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(children: [
        Row(children: [
          PlayerTagSmall(player: player),
          const Spacer(),
          Text('${g.score[index]} pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: Row(children: [
            for (var lane = 0; lane < FruitDuelLogic.lanes; lane++)
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    final pts = g.slash(index, lane);
                    if (pts != null) (pts > 0 ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact()).ignore();
                  },
                  child: _Lane(
                    color: player.color,
                    fruit: lane == g.fruitLane ? g.fruitEmoji : null,
                    fruitId: g.current,
                    timeLeft: g.fruitTimeLeft,
                    slashHere: usedTry && mine!.lane == lane ? mine : null,
                    dim: usedTry,
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Lane extends StatelessWidget {
  final Color color;
  final String? fruit;
  final int fruitId;
  final double timeLeft;
  final Slash? slashHere;
  final bool dim;
  const _Lane({required this.color, required this.fruit, required this.fruitId, required this.timeLeft, required this.slashHere, required this.dim});

  @override
  Widget build(BuildContext context) {
    final s = slashHere;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Stack(alignment: Alignment.center, children: [
        if (fruit != null)
          TweenAnimationBuilder<double>(
            key: ValueKey(fruitId),
            tween: Tween(begin: 0.2, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Opacity(
              opacity: dim && (s == null || s.points == 0) ? 0.35 : 1,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(child: Text(s != null && s.points > 0 ? '💥' : fruit!, style: const TextStyle(fontSize: 54))),
                const SizedBox(height: 6),
                SizedBox(
                  width: 50,
                  child: LinearProgressIndicator(value: timeLeft, minHeight: 4, color: Colors.white, backgroundColor: Colors.white12),
                ),
              ]),
            ),
          ),
        if (s != null)
          Positioned(
            bottom: 12,
            child: Text(
              s.points == 0 ? '✗ MISS' : '+${s.points}',
              style: TextStyle(color: s.points == 0 ? GpColors.no : GpColors.yes, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
      ]),
    );
  }
}
