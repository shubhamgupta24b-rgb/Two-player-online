import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import 'local_game_shell.dart' show PauseButton;

/// Phone lies flat between two players: player 1 (index 0) plays the bottom half,
/// player 2 (index 1) the top half, rotated to face them.
class SplitScreen extends StatelessWidget {
  final Widget Function(int playerIndex) half;
  final Widget middle;
  const SplitScreen({super.key, required this.half, required this.middle});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: RotatedBox(quarterTurns: 2, child: half(1))),
      middle,
      Expanded(child: half(0)),
    ]);
  }
}

/// One zone per player on a phone lying flat.
/// - 2 players: top (rotated) and bottom halves with [middle] between them.
/// - 3-6 players: two columns along the long sides. Left zones face the left edge, right
///   zones the right edge, so everyone reads their zone upright; [center] floats in the middle.
class PlayerZones extends StatelessWidget {
  final int count;
  final Widget Function(int playerIndex) zone;
  final Widget middle;
  final Widget center;
  const PlayerZones({super.key, required this.count, required this.zone, required this.middle, required this.center});

  /// Players 1..ceil(n/2) sit on the left side (top to bottom), the rest on the right.
  static int leftCount(int n) => (n + 1) ~/ 2;

  @override
  Widget build(BuildContext context) {
    if (count <= 2) return SplitScreen(half: zone, middle: middle);
    final left = leftCount(count);
    Widget column(Iterable<int> ids, int turns) => Column(children: [
          for (final i in ids)
            Expanded(child: Padding(padding: const EdgeInsets.all(3), child: RotatedBox(quarterTurns: turns, child: zone(i)))),
        ]);
    return Stack(children: [
      Row(children: [
        Expanded(child: column(Iterable.generate(left), 1)),
        Expanded(child: column(Iterable.generate(count - left, (i) => left + i), 3)),
      ]),
      Center(child: center),
    ]);
  }
}

/// Small floating pill for the middle of a 3-6 player layout: status text + pause.
class ZoneCenterChip extends StatelessWidget {
  final String text;
  const ZoneCenterChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12, right: 2),
        decoration: BoxDecoration(color: GpColors.bgBottom, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const PauseButton(),
        ]),
      );
}

class PlayerTagSmall extends StatelessWidget {
  final GpPlayer player;
  const PlayerTagSmall({super.key, required this.player});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: player.color, borderRadius: BorderRadius.circular(14)),
        child: Text(player.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      );
}

/// Centre strip for "first to N" games: both scores (player 2's upside down) and the target.
class ScoreMiddleBar extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int> scores;
  final String label; // e.g. "FIRST TO 5"
  const ScoreMiddleBar({super.key, required this.players, required this.scores, required this.label});

  @override
  Widget build(BuildContext context) {
    Widget score(int i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(color: players[i].color, borderRadius: BorderRadius.circular(12)),
          child: Text('${scores[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        );
    return Container(
      height: 50,
      color: GpColors.bgBottom,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        RotatedBox(quarterTurns: 2, child: score(1)),
        Expanded(
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ),
        const PauseButton(),
        const SizedBox(width: 6),
        score(0),
      ]),
    );
  }
}

/// Centre strip: seconds left plus a tug-of-war bar showing who is ahead.
class DuelMiddleBar extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int> scores;
  final int secondsLeft;
  final double progress;
  const DuelMiddleBar({super.key, required this.players, required this.scores, required this.secondsLeft, required this.progress});

  @override
  Widget build(BuildContext context) {
    final total = scores[0] + scores[1];
    final share = total == 0 ? 0.5 : scores[0] / total; // player 1's share
    final urgent = secondsLeft <= 3;
    return Container(
      height: 50,
      color: GpColors.bgBottom,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // Player 2's score is upside down so they can read it from their side.
        RotatedBox(quarterTurns: 2, child: _score(players[1], scores[1])),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(children: [
                  Expanded(flex: (share * 1000).round().clamp(1, 999), child: Container(color: players[0].color)),
                  Expanded(flex: ((1 - share) * 1000).round().clamp(1, 999), child: Container(color: players[1].color)),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: 1 - progress, minHeight: 4, color: urgent ? GpColors.no : GpColors.accent, backgroundColor: Colors.white12),
            ),
          ]),
        ),
        const SizedBox(width: 4),
        const PauseButton(),
        Text('${secondsLeft}s', style: TextStyle(color: urgent ? GpColors.no : Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(width: 10),
        _score(players[0], scores[0]),
      ]),
    );
  }

  Widget _score(GpPlayer p, int s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(12)),
        child: Text('$s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
      );
}
