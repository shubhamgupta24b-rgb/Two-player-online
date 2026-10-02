import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

enum ReactionPhase { wait, go, result }

/// Wait for green, then tap first. Tapping too early costs you a point (never below 0)
/// and restarts the round. First to [target]. Works for 2-6 players.
class ReactionTapLogic extends LocalGameLogic {
  final int target;
  final int resultMs;
  final Random _rng;
  final List<int> score;
  ReactionPhase phase = ReactionPhase.wait;
  int _now = 0;
  int goAt;
  int _goStarted = 0;
  int _resultUntil = 0;
  int? lastTapper; // who ended the round (winner, or the one who jumped early)
  bool falseStart = false;
  int? reactionMs;

  ReactionTapLogic({this.target = 5, this.resultMs = 1300, int players = 2, Random? random})
      : _rng = random ?? Random(),
        score = List.filled(players, 0),
        goAt = 0 {
    goAt = _nextGo(0);
  }

  /// Green comes 1.5-4 seconds after the round starts, so it can't be predicted.
  int _nextGo(int from) => from + 1500 + _rng.nextInt(2500);

  @override
  List<int> get scores => score;
  @override
  bool get finished => score.any((s) => s >= target);

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    if (phase == ReactionPhase.wait && _now >= goAt) {
      phase = ReactionPhase.go;
      _goStarted = goAt;
      notifyListeners();
    } else if (phase == ReactionPhase.result && _now >= _resultUntil && !finished) {
      phase = ReactionPhase.wait;
      goAt = _nextGo(_now);
      notifyListeners();
    }
  }

  /// Returns true if the tap counted (scored or was a false start).
  bool tap(int player) {
    if (forward('tap', [player])) return false;
    if (finished || phase == ReactionPhase.result) return false;
    lastTapper = player;
    if (phase == ReactionPhase.wait) {
      falseStart = true;
      reactionMs = null;
      if (score[player] > 0) score[player]--;
    } else {
      falseStart = false;
      reactionMs = _now - _goStarted;
      score[player]++;
    }
    phase = ReactionPhase.result;
    _resultUntil = _now + resultMs;
    notifyListeners();
    return true;
  }
}

final reactionTapInfo = LocalGameInfo(
  id: 'reaction_tap',
  title: 'Reaction Tap',
  emoji: '⚡',
  color: const Color(0xFFFFC93C),
  tagline: 'Fastest finger wins!',
  rules: const [
    'Your side turns RED: wait…',
    'When it turns GREEN, tap as fast as you can. First tap wins the point.',
    'Tap while it is still red and you LOSE a point. First to 5 wins. 2 to 6 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 6,
  online: RelaySpec<ReactionTapLogic>(
    create: (n) => ReactionTapLogic(players: n),
    save: (g) => {'score': g.score, 'phase': g.phase.index, 'last': g.lastTapper, 'false': g.falseStart, 'ms': g.reactionMs},
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.phase = ReactionPhase.values[asInt(s['phase'])];
      g.lastTapper = nInt(s['last']);
      g.falseStart = s['false'] == true;
      g.reactionMs = nInt(s['ms']);
    },
    apply: (g, from, name, a) {
      if (name == 'tap' && asInt(a[0]) == from) g.tap(from);
    },
    view: (context, g, players, me) => Column(children: [
      ScoreMiddleBar(players: players, scores: g.scores, label: 'FIRST TO ${g.target}'),
      Expanded(child: _ReactionHalf(player: players[me], index: me, g: g)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<ReactionTapLogic>(
    create: () => ReactionTapLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      middle: ScoreMiddleBar(players: players, scores: g.scores, label: 'FIRST TO ${g.target}'),
      center: ZoneCenterChip('FIRST TO ${g.target}'),
      zone: (i) => _ReactionHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _ReactionHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final ReactionTapLogic g;
  const _ReactionHalf({required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    final (Color bg, String big, String small) = switch (g.phase) {
      ReactionPhase.wait => (const Color(0xFFE5484D), 'WAIT…', "Don't tap yet!"),
      ReactionPhase.go => (const Color(0xFF2FB36D), 'TAP!', 'NOW!'),
      ReactionPhase.result => g.falseStart
          ? (g.lastTapper == index
              ? (const Color(0xFF3A3846), 'TOO EARLY!', '−1 point · wait for green')
              : (player.color, 'PHEW!', 'Someone tapped too early'))
          : (g.lastTapper == index
              ? (player.color, 'YOU WIN!', '+1 · ${g.reactionMs} ms')
              : (const Color(0xFF3A3846), 'TOO SLOW', 'Someone was faster')),
    };
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (g.tap(index)) HapticFeedback.mediumImpact().ignore();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28), border: Border.all(color: player.color, width: 4)),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${player.name.toUpperCase()} · ${g.score[index]}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              Text(big, style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900)),
              Text(small, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}
