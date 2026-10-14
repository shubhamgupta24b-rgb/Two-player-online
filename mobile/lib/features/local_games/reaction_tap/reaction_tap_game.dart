import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
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
    'Your side turns RED: wait...',
    'When it turns GREEN, tap as fast as you can. First tap wins the point.',
    'Tap while it is still red and you LOSE a point. First to 5 wins. 2 to 6 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 6,
  bot: botFor<ReactionTapLogic>((g, b, now) {
    if (g.finished || g.phase != ReactionPhase.go) return;
    // Human-like reaction time: 280-650 ms after green.
    if (b.thinkFirst(g.goAt, now, 280, 650)) g.tap(b.seat);
  }),
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
      ScoreMiddleBar(players: players, scores: g.scores, label: 'First to ${g.target}'),
      Expanded(child: _ReactionHalf(player: players[me], index: me, g: g)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<ReactionTapLogic>(
    create: () => ReactionTapLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      colors: [for (final p in players) p.color],
      middle: ScoreMiddleBar(players: players, scores: g.scores, label: 'First to ${g.target}'),
      center: ZoneCenterChip('First to ${g.target}'),
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
    final won = g.phase == ReactionPhase.result && !g.falseStart && g.lastTapper == index;
    final (Color bg, Color lamp, GameIcons icon, String big, String small) = switch (g.phase) {
      ReactionPhase.wait => (const Color(0xFF3A1420), const Color(0xFFE5484D), GameIcons.lock, 'Wait...', "Don't tap yet!"),
      ReactionPhase.go => (const Color(0xFF0E3A26), const Color(0xFF2FD47A), GameIcons.bolt, 'TAP!', 'Now!'),
      ReactionPhase.result => g.falseStart
          ? (g.lastTapper == index
              ? (const Color(0xFF22202C), const Color(0xFF6B6878), GameIcons.cross, 'Too early!', '-1 point: wait for green')
              : (const Color(0xFF22202C), player.color, GameIcons.check, 'Phew!', 'Someone tapped too early'))
          : (won
              ? (Color.lerp(player.color, Colors.black, 0.55)!, Brand.gold, GameIcons.star, 'You win!', '+1 in ${g.reactionMs} ms')
              : (const Color(0xFF22202C), const Color(0xFF6B6878), GameIcons.cross, 'Too slow', 'Someone was faster')),
    };
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (g.tap(index)) HapticFeedback.mediumImpact().ignore();
      },
      child: Semantics(
        button: true,
        label: '${player.name}: $big $small',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [Color.lerp(bg, lamp, 0.25)!, bg], radius: 0.9),
            borderRadius: Radii.rLg,
            border: Border.all(color: player.color, width: 4),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    PlayerBadge(index: PlayerPalette.indexOf(player.color) ?? index, size: 22, color: player.color, initial: player.name),
                    const SizedBox(width: 6),
                    Text('${player.name}  ${g.score[index]}', style: const TextStyle(fontFamily: Fonts.body, color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  ]),
                  const SizedBox(height: 12),
                  // The signal lamp.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 110,
                    height: 110,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(center: const Alignment(-0.3, -0.35), colors: [Color.lerp(lamp, Colors.white, 0.45)!, lamp, Color.lerp(lamp, Colors.black, 0.3)!]),
                      border: Border.all(color: const Color(0xFF15131C), width: 6),
                      boxShadow: [BoxShadow(color: lamp.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 4)],
                    ),
                    child: GameIcon(icon, size: 52, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(big, style: TextStyle(fontFamily: Fonts.display, color: won ? Brand.gold : Colors.white, fontSize: 52, height: 1.05)),
                  Text(small, style: const TextStyle(fontFamily: Fonts.body, color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
