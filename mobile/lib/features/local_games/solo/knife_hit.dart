import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../shell/level_progress.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Knife Hit: a target spins. Tap once to throw. A knife that lands on another knife
/// ends the run. Clear the knife count to finish the level.
class KnifeLogic extends SoloLogic {
  final Random rng;
  int level;
  double angle = 0;
  final List<double> stuck = [];
  int thrown = 0;
  bool flying = false;
  double fly = 0;
  bool failed = false;
  bool cleared = false;
  int _last = 0;

  KnifeLogic({Random? random, this.level = 1}) : rng = random ?? Random();

  int get need => 4 + level;
  double get spin =>
      (1.4 + level * 0.7) * (level == 3 && (now ~/ 1400).isEven ? -1 : 1);

  void setLevel(int n) {
    if (over || cleared || thrown > 0) return;
    level = n.clamp(1, 3);
    angle = 0;
    stuck.clear();
    flying = false;
    fly = 0;
    thrown = 0;
    failed = false;
    score = 0;
    _last = 0;
    notifyListeners();
  }

  void throwKnife() {
    if (over || cleared || flying) return;
    flying = true;
    fly = 0;
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = _last == 0 ? 16 : (now - _last).clamp(0, 40);
    _last = now;
    final sec = dt / 1000;
    angle += spin * sec;
    if (flying) {
      fly += sec * 2.4;
      if (fly >= 1) {
        flying = false;
        final hit = stuck.any((a) => _gap(angle, a) < 0.22);
        if (hit) {
          failed = true;
          gameOver(800);
          return;
        }
        stuck.add(angle);
        thrown++;
        score = thrown;
        if (thrown >= need) {
          cleared = true;
          LevelProgress.markCleared('knife_hit', level);
          gameOver(800);
          return;
        }
      }
    }
    notifyListeners();
  }

  static double _gap(double a, double b) {
    var d = (a - b).abs() % (pi * 2);
    if (d > pi) d = pi * 2 - d;
    return d;
  }
}

final knifeHitInfo = LocalGameInfo(
  id: 'knife_hit',
  title: 'Knife Hit',
  emoji: '🔪',
  color: const Color(0xFFD32F2F),
  tagline: 'Throw knives into the spinning log.',
  rules: const [
    'Tap once to throw. The knife sticks where the log is when it arrives.',
    'Hitting a knife that is already in the log ends the run.',
    'Fill the log to clear the level. Three levels, each faster, and the last one reverses.',
  ],
  scoreUnit: 'knives',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<KnifeLogic>(
    create: () => KnifeLogic(),
    onFinished: onFinished,
    builder: (context, g) => _KnifeView(g: g),
  ),
);

class _KnifeView extends StatefulWidget {
  final KnifeLogic g;
  const _KnifeView({required this.g});
  @override
  State<_KnifeView> createState() => _KnifeViewState();
}

class _KnifeViewState extends State<_KnifeView> {
  int _open = 1;
  @override
  void initState() {
    super.initState();
    LevelProgress.unlocked('knife_hit').then((n) {
      if (mounted) setState(() => _open = n.clamp(1, 3));
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return SoloFrame(
      title:
          g.failed ? 'Hit a knife' : (g.cleared ? 'Level clear' : 'Knife Hit'),
      score: g.score,
      extra: 'Level ${g.level} · ${g.thrown}/${g.need}',
      child: Column(children: [
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: KitButton('Level $i',
                    style:
                        i <= _open ? KitButtonStyle.soft : KitButtonStyle.ghost,
                    onPressed: i <= _open && g.thrown == 0 && !g.over
                        ? () => g.setLevel(i)
                        : null),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: GestureDetector(
            onTap: g.throwKnife,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: const Color(0xFF2C1810),
                  borderRadius: BorderRadius.circular(18)),
              child: CustomPaint(
                  painter: _KnifePainter(g), child: const SizedBox.expand()),
            ),
          ),
        ),
      ]),
    );
  }
}

class _KnifePainter extends CustomPainter {
  final KnifeLogic g;
  _KnifePainter(this.g);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final r = size.shortestSide * 0.22;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawCircle(c, r * 0.55, Paint()..color = const Color(0xFF6D4C41));
    for (final a in g.stuck) {
      _knife(canvas, c, r, a, true);
    }
    final flyY =
        size.height * (0.86 - 0.40 * (g.flying ? g.fly.clamp(0, 1) : 0));
    _knife(canvas, Offset(c.dx, flyY), 0, -pi / 2, false);
  }

  void _knife(Canvas canvas, Offset c, double r, double a, bool stuck) {
    final tip = stuck ? c + Offset(sin(a), -cos(a)) * (r + 4) : c;
    final tail = stuck
        ? c + Offset(sin(a), -cos(a)) * (r + 36)
        : c + const Offset(0, 36);
    canvas.drawLine(
        tip,
        tail,
        Paint()
          ..color = const Color(0xFFECEFF1)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(tip, 5, Paint()..color = const Color(0xFFB0BEC5));
  }

  @override
  bool shouldRepaint(_KnifePainter old) => true;
}
