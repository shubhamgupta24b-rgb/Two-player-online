import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import 'local_game_shell.dart' show PauseButton;

/// Phone lies flat between two players: player 1 (index 0) plays the bottom half,
/// player 2 (index 1) the top half, rotated to face them. [middle] sits between the
/// halves and never overlaps either player's touch area.
class SplitScreen extends StatelessWidget {
  final Widget Function(int playerIndex) half;
  final Widget middle;
  const SplitScreen({super.key, required this.half, required this.middle});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: RotatedBox(quarterTurns: 2, child: RepaintBoundary(child: half(1)))),
      middle,
      Expanded(child: RepaintBoundary(child: half(0))),
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
            Expanded(child: Padding(padding: const EdgeInsets.all(3), child: RotatedBox(quarterTurns: turns, child: RepaintBoundary(child: zone(i))))),
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
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.only(left: Space.m, right: 2),
      decoration: BoxDecoration(color: t.bgBottom, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: t.strokeStrong), boxShadow: t.shadowMd),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Semantics(liveRegion: true, child: Text(text, style: t.styles.score.copyWith(fontSize: 16))),
        const PauseButton(),
      ]),
    );
  }
}

/// A player's name on their colour, with their shape.
class PlayerTagSmall extends StatelessWidget {
  final GpPlayer player;
  const PlayerTagSmall({super.key, required this.player});
  @override
  Widget build(BuildContext context) {
    final seat = PlayerPalette.indexOf(player.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
      decoration: BoxDecoration(color: fillFor(player.color), borderRadius: Radii.rMd),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (seat != null) ...[SizedBox(width: 11, height: 11, child: CustomPaint(painter: PlayerShapePainter(PlayerPalette.shape(seat), Colors.white))), const SizedBox(width: 5)],
        Flexible(
          child: Text(player.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// A player's score as a badge: their shape and the number (never colour alone).
class _ScoreBadge extends StatelessWidget {
  final GpPlayer player;
  final int score;
  const _ScoreBadge(this.player, this.score);
  @override
  Widget build(BuildContext context) {
    final seat = PlayerPalette.indexOf(player.color);
    return Semantics(
      label: '${player.name} $score',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 3),
        decoration: BoxDecoration(color: fillFor(player.color), borderRadius: Radii.rMd),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (seat != null) ...[SizedBox(width: 12, height: 12, child: CustomPaint(painter: PlayerShapePainter(PlayerPalette.shape(seat), Colors.white))), const SizedBox(width: 5)],
          Text('$score', style: context.tk.styles.score.copyWith(fontSize: 18, color: Colors.white)),
        ]),
      ),
    );
  }
}

/// Centre strip for "first to N" games: both scores (player 2's upside down) and the target.
class ScoreMiddleBar extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int> scores;
  final String label; // e.g. "FIRST TO 5"
  const ScoreMiddleBar({super.key, required this.players, required this.scores, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 52,
      decoration: BoxDecoration(color: t.bgBottom, border: Border.symmetric(horizontal: BorderSide(color: t.stroke))),
      padding: const EdgeInsets.symmetric(horizontal: Space.m),
      child: Row(children: [
        RotatedBox(quarterTurns: 2, child: _ScoreBadge(players[1], scores[1])),
        Expanded(child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.styles.label)),
        const PauseButton(),
        const SizedBox(width: Space.xs),
        _ScoreBadge(players[0], scores[0]),
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
    final t = context.tk;
    final total = scores[0] + scores[1];
    final share = total == 0 ? 0.5 : scores[0] / total; // player 1's share
    final urgent = secondsLeft <= 3;
    return Container(
      height: 52,
      decoration: BoxDecoration(color: t.bgBottom, border: Border.symmetric(horizontal: BorderSide(color: t.stroke))),
      padding: const EdgeInsets.symmetric(horizontal: Space.m),
      child: Row(children: [
        // Player 2's score is upside down so they can read it from their side.
        RotatedBox(quarterTurns: 2, child: _ScoreBadge(players[1], scores[1])),
        const SizedBox(width: Space.s),
        Expanded(
          child: ExcludeSemantics(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(children: [
                    Expanded(flex: (share * 1000).round().clamp(1, 999), child: Container(color: players[0].color)),
                    Container(width: 2, color: Colors.white),
                    Expanded(flex: ((1 - share) * 1000).round().clamp(1, 999), child: Container(color: players[1].color)),
                  ]),
                ),
              ),
              const SizedBox(height: Space.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: 1 - progress, minHeight: 4, color: urgent ? t.danger : t.accent, backgroundColor: t.stroke),
              ),
            ]),
          ),
        ),
        const SizedBox(width: Space.xs),
        const PauseButton(),
        Semantics(
          label: '$secondsLeft seconds left',
          excludeSemantics: true,
          child: Text('${secondsLeft}s', style: t.styles.score.copyWith(fontSize: 18, color: urgent ? t.danger : t.onBg)),
        ),
        const SizedBox(width: Space.s),
        _ScoreBadge(players[0], scores[0]),
      ]),
    );
  }
}
