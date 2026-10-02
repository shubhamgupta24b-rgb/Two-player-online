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
