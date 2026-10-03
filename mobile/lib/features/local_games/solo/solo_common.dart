import 'package:flutter/material.dart';
import '../party/party_widgets.dart' show GameTopBar;
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show ScorePill;

/// Base for one-player games: a clock, a score, and a short pause after "game over" so
/// you can see what happened before the score screen.
abstract class SoloLogic extends LocalGameLogic {
  int now = 0;
  int score = 0;
  int? _endAt;
  bool get over => _endAt != null;

  @override
  bool get finished => _endAt != null && now >= _endAt!;
  @override
  List<int> get scores => [score];

  @override
  void update(int elapsedMs) {
    now = elapsedMs;
    if (!over) step(elapsedMs);
  }

  /// Per-frame game step while the game is running.
  @protected
  void step(int now) {}

  /// Ends the game; the score screen follows after [pauseMs].
  @protected
  void gameOver([int pauseMs = 1200]) {
    if (over) return;
    _endAt = now + pauseMs;
    notifyListeners();
  }
}

/// Top bar for solo games: pause, title, and the live score.
class SoloFrame extends StatelessWidget {
  final String title;
  final int score;
  final String? extra; // e.g. "⏱ 42s"
  final Widget child;
  const SoloFrame({super.key, required this.title, required this.score, this.extra, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
        child: Column(children: [
          GameTopBar(
            title: title,
            subtitle: extra,
            trailing: TweenAnimationBuilder<double>(
              key: ValueKey(score),
              tween: Tween(begin: 1.25, end: 1),
              duration: const Duration(milliseconds: 250),
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: ScorePill('$score'),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ]),
      );
}

/// Swipe direction from a fling: 0 up, 1 right, 2 down, 3 left (or null if too small).
int? swipeDir(Offset v, {double minSpeed = 120}) {
  if (v.distance < minSpeed) return null;
  return v.dx.abs() > v.dy.abs() ? (v.dx > 0 ? 1 : 3) : (v.dy > 0 ? 2 : 0);
}
