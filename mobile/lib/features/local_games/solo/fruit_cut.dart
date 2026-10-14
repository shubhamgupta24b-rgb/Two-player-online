import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../shell/level_progress.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// One fruit or bomb in normalised screen space (0–1, y grows downward).
class CutPiece {
  final int id;
  double x, y, vx, vy, r;
  final bool bomb;
  final int tint;
  bool sliced = false;
  CutPiece(
      {required this.id,
      required this.x,
      required this.y,
      required this.vx,
      required this.vy,
      required this.r,
      required this.bomb,
      required this.tint});
}

/// Fruit Cut: fruit rises from the bottom. A swipe that crosses a fruit scores.
/// Slicing a bomb ends the round. Each level asks for more fruit, faster.
class FruitCutLogic extends SoloLogic {
  static const targets = [8, 14, 22];
  final Random rng;
  int level;
  final List<CutPiece> pieces = [];
  int _id = 1;
  int _last = 0;
  int _spawnIn = 0;
  int sliced = 0;
  bool bombHit = false;
  bool cleared = false;

  FruitCutLogic({Random? random, this.level = 1}) : rng = random ?? Random();

  int get target => targets[(level - 1).clamp(0, targets.length - 1)];
  double get speed => 0.28 + (level - 1) * 0.1;

  void setLevel(int n) {
    if (over || cleared || sliced > 0) return;
    level = n.clamp(1, 3);
    pieces.clear();
    sliced = 0;
    score = 0;
    bombHit = false;
    _spawnIn = 0;
    _last = 0;
    notifyListeners();
  }

  void slash(double ax, double ay, double bx, double by) {
    if (over || cleared) return;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    if (len2 < 0.0004) return;
    for (final p in pieces) {
      if (p.sliced) continue;
      final t = (((p.x - ax) * dx + (p.y - ay) * dy) / len2).clamp(0.0, 1.0);
      final cx = ax + dx * t - p.x, cy = ay + dy * t - p.y;
      if (cx * cx + cy * cy > p.r * p.r) continue;
      p.sliced = true;
      if (p.bomb) {
        bombHit = true;
        gameOver(900);
        return;
      }
      sliced++;
      score++;
      if (sliced >= target) {
        cleared = true;
        LevelProgress.markCleared('fruit_cut', level);
        gameOver(900);
        return;
      }
    }
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = _last == 0 ? 16 : (now - _last).clamp(0, 40);
    _last = now;
    final sec = dt / 1000;
    for (final p in pieces) {
      if (p.sliced) continue;
      p.x += p.vx * sec;
      p.y += p.vy * sec;
    }
    pieces
        .removeWhere((p) => p.sliced || p.y < -0.2 || p.x < -0.2 || p.x > 1.2);
    _spawnIn -= dt;
    if (_spawnIn <= 0 && !over) {
      _spawnIn = max(280, 720 - level * 120);
      final bomb = rng.nextDouble() < 0.14 + level * 0.04;
      pieces.add(CutPiece(
        id: _id++,
        x: 0.12 + rng.nextDouble() * 0.76,
        y: 1.08,
        vx: (rng.nextDouble() - 0.5) * 0.15,
        vy: -(speed + rng.nextDouble() * 0.12),
        r: bomb ? 0.045 : 0.055,
        bomb: bomb,
        tint: rng.nextInt(4),
      ));
    }
    notifyListeners();
  }
}

final fruitCutInfo = LocalGameInfo(
  id: 'fruit_cut',
  title: 'Fruit Cut',
  emoji: '🍉',
  color: const Color(0xFFFF7043),
  tagline: 'Swipe the fruit. Do not cut the bomb.',
  rules: const [
    'Fruit rises from the bottom of the screen. Swipe across a fruit to slice it.',
    'A bomb ends the round as soon as you slice it.',
    'Clear the fruit target to finish the level. Three levels, each faster than the last.',
  ],
  scoreUnit: 'fruit',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<FruitCutLogic>(
    create: () => FruitCutLogic(),
    onFinished: onFinished,
    builder: (context, g) => _FruitCutView(g: g),
  ),
);

class _FruitCutView extends StatefulWidget {
  final FruitCutLogic g;
  const _FruitCutView({required this.g});
  @override
  State<_FruitCutView> createState() => _FruitCutViewState();
}

class _FruitCutViewState extends State<_FruitCutView> {
  int _open = 1;
  Offset? _from;

  @override
  void initState() {
    super.initState();
    LevelProgress.unlocked('fruit_cut').then((n) {
      if (mounted) setState(() => _open = n.clamp(1, 3));
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return SoloFrame(
      title: g.bombHit
          ? 'Bomb!'
          : (g.cleared ? 'Level ${g.level} clear' : 'Fruit Cut'),
      score: g.score,
      extra: 'Level ${g.level} · ${g.sliced}/${g.target}',
      child: Column(children: [
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: KitButton(
                  'Level $i',
                  style:
                      i <= _open ? KitButtonStyle.soft : KitButtonStyle.ghost,
                  onPressed: i <= _open && !g.over && g.sliced == 0
                      ? () => g.setLevel(i)
                      : null,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            Offset n(Offset p) => Offset(p.dx / c.maxWidth, p.dy / c.maxHeight);
            return GestureDetector(
              onPanStart: (d) => _from = n(d.localPosition),
              onPanUpdate: (d) {
                final to = n(d.localPosition);
                final from = _from;
                if (from != null) g.slash(from.dx, from.dy, to.dx, to.dy);
                _from = to;
              },
              onPanEnd: (_) => _from = null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: const Color(0xFF1B3A4B),
                    borderRadius: BorderRadius.circular(18)),
                child: CustomPaint(
                    painter: _FruitPainter(g), child: const SizedBox.expand()),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _FruitPainter extends CustomPainter {
  final FruitCutLogic g;
  _FruitPainter(this.g);
  static const _colors = [
    Color(0xFFE53935),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF8E24AA)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in g.pieces) {
      if (p.sliced) continue;
      final c = Offset(p.x * size.width, p.y * size.height);
      final r = p.r * size.shortestSide;
      if (p.bomb) {
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFF263238));
        canvas.drawCircle(
            c, r * 0.35, Paint()..color = const Color(0xFFFF7043));
      } else {
        canvas.drawCircle(c, r, Paint()..color = _colors[p.tint]);
        canvas.drawCircle(c.translate(-r * 0.25, -r * 0.25), r * 0.22,
            Paint()..color = Colors.white.withValues(alpha: 0.45));
      }
    }
  }

  @override
  bool shouldRepaint(_FruitPainter old) => true;
}
