import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import 'local_game_shell.dart' show PauseButton;

/// The shared in-game header for turn-based and score games: pause, one chip per player
/// (name, shape, score and an optional extra like 🏹3), whose turn lit up, and an optional
/// widget on the right (round, timer).
class GameHud extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int>? scores;
  final int? turn; // lit-up player; null: nobody's turn (finished, or everyone at once)
  final String Function(int i)? extra; // e.g. arrows left, tokens home
  final String Function(int i)? nameOf; // e.g. team letters
  final Set<int> dimmed; // players who are out
  final Widget? trailing;
  const GameHud({super.key, required this.players, this.scores, this.turn, this.extra, this.nameOf, this.dimmed = const {}, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const PauseButton(),
      const SizedBox(width: Space.xs),
      Expanded(
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < players.length; i++)
            PlayerChip(
              name: nameOf?.call(i) ?? players[i].name,
              color: players[i].color,
              score: scores?[i],
              suffix: extra?.call(i),
              active: turn == i,
              dim: dimmed.contains(i),
            ),
        ]),
      ),
      if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
    ]);
  }
}

/// A small label for the HUD's right side (ROUND 2/4, HOLE 3/6).
class HudLabel extends StatelessWidget {
  final String text;
  const HudLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 5),
      decoration: BoxDecoration(color: t.glassStrong, borderRadius: Radii.rMd),
      child: Text(text, style: t.styles.label.copyWith(color: t.onBg, letterSpacing: 0.8)),
    );
  }
}

/// The status line under (or over) the play area: whose turn it is, or a message.
/// One style everywhere; [message] wins over the turn banner while it's set.
class GameStatus extends StatelessWidget {
  final GpPlayer? player; // whose turn
  final String? turnText; // e.g. "PLAYER 1'S TURN · pull back & let go"
  final String? message; // e.g. "🎯 BULLSEYE! +10"
  final double height;
  const GameStatus({super.key, this.player, this.turnText, this.message, this.height = 48});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final Widget child;
    if (message != null) {
      child = Text(message!,
          key: ValueKey('m$message'), textAlign: TextAlign.center, maxLines: 2, style: t.styles.headline.copyWith(color: t.accent, fontSize: 22, shadows: const [Shadow(color: Colors.black45, blurRadius: 4)]));
    } else if (player != null && turnText != null) {
      child = TurnBanner(key: ValueKey('t$turnText'), text: turnText!, color: player!.color);
    } else if (turnText != null) {
      child = Text(turnText!, key: ValueKey('x$turnText'), textAlign: TextAlign.center, style: t.styles.bodyStrong.copyWith(color: t.onBgMuted));
    } else {
      child = const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.normal),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.emphasized)), child: c)),
            child: child,
          ),
        ),
      ),
    );
  }
}
