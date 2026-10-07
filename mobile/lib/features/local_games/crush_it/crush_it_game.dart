import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Same rules as the online version: most taps in 10 seconds wins.
class CrushItLogic extends TimedDuel {
  final List<int> taps;
  CrushItLogic({int durationMs = 10000, int players = 2})
      : taps = List.filled(players, 0),
        super(durationMs);

  @override
  List<int> get scores => taps;

  void tap(int player) {
    if (finished) return;
    taps[player]++;
    notifyListeners();
  }
}

final crushItInfo = LocalGameInfo(
  id: 'crush_it',
  title: 'Crush It',
  emoji: '👊',
  color: const Color(0xFFFF6B6B),
  tagline: 'Tap faster than your friend!',
  rules: const ['Smash your zone of the screen as fast as you can.', 'Every tap counts for 10 seconds.', 'Most taps wins. 2 to 6 players.'],
  scoreUnit: 'taps',
  splitScreen: true,
  maxPlayers: 6,
  bot: botFor<CrushItLogic>((g, b, now) {
    if (g.finished || !b.due(now)) return;
    g.tap(b.seat);
    b.wait(now, 130, 230); // about 5-7 taps a second
  }),
  play: (players, onFinished) => TickingPlay<CrushItLogic>(
    create: () => CrushItLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      middle: DuelMiddleBar(players: players, scores: g.scores, secondsLeft: g.secondsLeft, progress: g.progress),
      center: ZoneCenterChip('${g.secondsLeft}s'),
      zone: (i) => _CrushHalf(player: players[i], taps: g.taps[i], onTap: () => g.tap(i), done: g.finished),
    ),
  ),
);

class _CrushHalf extends StatelessWidget {
  final GpPlayer player;
  final int taps;
  final VoidCallback onTap;
  final bool done;
  const _CrushHalf({required this.player, required this.taps, required this.onTap, required this.done});

  @override
  Widget build(BuildContext context) {
    // Listener (not a tap recogniser) so both players can hammer at the same time with no gesture delay.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: done
          ? null
          : (_) {
              onTap();
              HapticFeedback.selectionClick().ignore();
            },
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: player.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: player.color, width: 3),
        ),
        // Scales down on short screens instead of overflowing.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(player.name.toUpperCase(), style: TextStyle(color: player.color, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          // Restarting the tween on every tap makes the fist "punch".
          TweenAnimationBuilder<double>(
            key: ValueKey(taps),
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 140),
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 130,
              height: 130,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: player.color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color.lerp(player.color, Colors.black, 0.4)!, offset: const Offset(0, 6))],
              ),
              child: const Text('👊', style: TextStyle(fontSize: 64)),
            ),
          ),
          const SizedBox(height: 10),
          Text('$taps', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
          Text(done ? 'TIME!' : 'TAP! TAP! TAP!', style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ]),
        ),
      ),
    );
  }
}
