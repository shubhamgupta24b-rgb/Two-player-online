import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../shell/level_progress.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Chicken Jump: tap to flap. Fly through the gaps. Three levels get tighter and faster.
class ChickenLogic extends SoloLogic {
  static const height = 1.0;
  final Random rng;
  int level;
  double birdY = 0.45;
  double vy = 0;
  double scroll = 0;
  final List<double> gaps = [];
  bool crashed = false;
  bool cleared = false;

  ChickenLogic({Random? random, this.level = 1}) : rng = random ?? Random() {
    var y = 0.45;
    for (var i = 0; i < 8; i++) {
      y = (y + (rng.nextDouble() - 0.5) * 0.35).clamp(0.22, 0.78);
      gaps.add(y);
    }
  }

  double get gapSize => 0.42 - (level - 1) * 0.08;
  double get pace => 0.28 + (level - 1) * 0.08;
  int get goal => 6 + level * 2;

  /// Only before the run starts. Rebuilds the gaps for the chosen level.
  void setLevel(int n) {
    if (over || cleared || score > 0) return;
    level = n.clamp(1, 3);
    birdY = 0.45;
    vy = 0;
    scroll = 0;
    gaps.clear();
    var y = 0.45;
    for (var i = 0; i < 8; i++) {
      y = (y + (rng.nextDouble() - 0.5) * 0.35).clamp(0.22, 0.78);
      gaps.add(y);
    }
    notifyListeners();
  }

  void flap() {
    if (over || cleared) return;
    vy = -0.85;
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = 0.016;
    vy += 1.7 * dt;
    birdY += vy * dt;
    scroll += pace * dt;
    if (birdY < 0.04 || birdY > 0.96) {
      crashed = true;
      gameOver(700);
      return;
    }
    final index = scroll.floor();
    final into = scroll - index;
    if (into > 0.42 && into < 0.58 && index < gaps.length) {
      final gap = gaps[index % gaps.length];
      if ((birdY - gap).abs() > gapSize / 2) {
        crashed = true;
        gameOver(700);
        return;
      }
    }
    score = min(index, goal);
    if (index >= goal && !cleared) {
      cleared = true;
      score = goal;
      LevelProgress.markCleared('chicken_jump', level);
      gameOver(700);
      return;
    }
    notifyListeners();
  }
}

final chickenJumpInfo = LocalGameInfo(
  id: 'chicken_jump',
  title: 'Chicken Jump',
  emoji: '🐔',
  color: const Color(0xFFFFB300),
  tagline: 'Tap to flap through the gaps.',
  rules: const [
    'Tap the screen to flap. Gravity pulls the chicken down.',
    'Fly through each gap. Touching the posts or the edge ends the run.',
    'Clear the distance to finish the level. Three levels, each with tighter gaps.',
  ],
  scoreUnit: 'gaps',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<ChickenLogic>(
    create: () => ChickenLogic(),
    onFinished: onFinished,
    builder: (context, g) => _ChickenView(g: g),
  ),
);

class _ChickenView extends StatefulWidget {
  final ChickenLogic g;
  const _ChickenView({required this.g});
  @override
  State<_ChickenView> createState() => _ChickenViewState();
}

class _ChickenViewState extends State<_ChickenView> {
  int _open = 1;

  @override
  void initState() {
    super.initState();
    LevelProgress.unlocked('chicken_jump').then((n) {
      if (mounted) setState(() => _open = n.clamp(1, 3));
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return SoloFrame(
      title: g.cleared ? 'Level clear' : (g.crashed ? 'Down!' : 'Chicken Jump'),
      score: g.score,
      extra: 'Level ${g.level} · goal ${g.goal}',
      child: Column(children: [
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: KitButton('Level $i',
                    style:
                        i <= _open ? KitButtonStyle.soft : KitButtonStyle.ghost,
                    onPressed: i <= _open && g.score == 0 && !g.over
                        ? () => g.setLevel(i)
                        : null),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: GestureDetector(
            onTap: g.flap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: const Color(0xFF87CEEB),
                  borderRadius: BorderRadius.circular(18)),
              child: CustomPaint(
                  painter: _ChickenPainter(g), child: const SizedBox.expand()),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ChickenPainter extends CustomPainter {
  final ChickenLogic g;
  _ChickenPainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Paint()..color = const Color(0xFF81C784);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.92, size.width, size.height * 0.08),
        ground);
    final post = Paint()..color = const Color(0xFF2E7D32);
    for (var i = 0; i < 4; i++) {
      final world = g.scroll + i * 0.85;
      final idx = world.floor();
      final x = (0.25 + (idx - g.scroll) * 0.55) * size.width;
      if (x < -40 || x > size.width + 40) continue;
      final gap = g.gaps[idx % g.gaps.length] * size.height;
      final half = g.gapSize * size.height / 2;
      canvas.drawRect(Rect.fromLTWH(x, 0, 28, gap - half), post);
      canvas.drawRect(
          Rect.fromLTWH(x, gap + half, 28, size.height - gap - half), post);
    }
    final bird = Offset(size.width * 0.28, g.birdY * size.height);
    canvas.drawCircle(bird, 16, Paint()..color = const Color(0xFFFFB300));
    canvas.drawCircle(
        bird + const Offset(6, -4), 4, Paint()..color = Colors.white);
    canvas.drawCircle(bird + const Offset(7, -4), 2,
        Paint()..color = const Color(0xFF1C1A17));
    final wing = Path()
      ..moveTo(bird.dx - 4, bird.dy)
      ..lineTo(bird.dx - 18, bird.dy + 8 * sin(g.now / 80))
      ..lineTo(bird.dx - 2, bird.dy + 6);
    canvas.drawPath(wing, Paint()..color = const Color(0xFFF57F17));
  }

  @override
  bool shouldRepaint(_ChickenPainter old) => true;
}
