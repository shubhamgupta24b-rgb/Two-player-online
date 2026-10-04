import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// An obstacle: a cactus on the ground, or a bird flying low or high.
class Obstacle {
  double x; // distance ahead, in metres
  final bool bird;
  final bool high; // birds only: high birds can be run under
  final double width;
  Obstacle(this.x, {this.bird = false, this.high = false, this.width = 0.6});
}

/// Dino Run: the dino runs on its own; tap to jump over cacti and low birds (high birds
/// fly over you). It gets faster. Score = metres run.
class DinoLogic extends SoloLogic {
  static const gravity = -38.0, jumpSpeed = 13.5;
  final Random rng;
  double distance = 0, speed = 9; // metres, metres a second
  double y = 0, vy = 0; // the dino's height
  final List<Obstacle> obstacles = [];
  double _nextAt = 18;
  int _last = 0;
  double get dinoX => 2.0; // where the dino stands, metres from the left edge

  DinoLogic({Random? random}) : rng = random ?? Random();

  bool get onGround => y <= 0;

  void jump() {
    if (over || !onGround) return;
    vy = jumpSpeed;
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  @override
  void step(int now) {
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    speed = min(22, 9 + distance / 120);
    distance += speed * dt;
    score = distance.floor();
    vy += gravity * dt;
    y = max(0, y + vy * dt);
    if (y == 0) vy = 0;
    for (final o in obstacles) {
      o.x -= speed * dt;
    }
    obstacles.removeWhere((o) => o.x < -2);
    if (distance + 20 > _nextAt) {
      final bird = distance > 150 && rng.nextDouble() < 0.3;
      obstacles.add(Obstacle(_nextAt - distance + dinoX + 14, bird: bird, high: bird && rng.nextBool(), width: bird ? 0.8 : 0.5 + rng.nextDouble() * 0.6));
      _nextAt += max(7.0, 14 - distance / 80) + rng.nextDouble() * 8;
    }
    // Hit test: the dino is about 0.8 m wide and 1 m tall.
    for (final o in obstacles) {
      final ox = o.x;
      final overlapX = ox < dinoX + 0.5 && ox + o.width > dinoX - 0.3;
      if (!overlapX) continue;
      final hit = o.bird ? (o.high ? false : y < 1.0) : y < 0.9;
      if (hit) {
        HapticFeedback.heavyImpact().ignore();
        gameOver(1300);
        break;
      }
    }
    notifyListeners();
  }
}

final dinoInfo = LocalGameInfo(
  id: 'dino_run',
  title: 'Dino Run',
  emoji: '🦖',
  color: const Color(0xFF8BC34A),
  tagline: 'Jump the cacti, dodge the birds!',
  rules: const [
    'The dino runs by itself. Tap anywhere to jump.',
    'Jump over cacti 🌵 and low birds. High birds fly over your head.',
    'It keeps getting faster. Score = metres run.',
  ],
  scoreUnit: 'metres',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<DinoLogic>(
    create: () => DinoLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: '🦖 DINO RUN',
      score: g.score,
      extra: '${g.speed.toStringAsFixed(0)} m/s',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => g.jump(),
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CustomPaint(size: Size.infinite, painter: _DinoPainter(g))),
      ),
    ),
  ),
);

class _DinoPainter extends CustomPainter {
  final DinoLogic g;
  _DinoPainter(this.g);

  static final _emoji = <String, TextPainter>{};
  static TextPainter _tp(String e, double size) =>
      _emoji.putIfAbsent('$e$size', () => TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout());

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width / 12; // pixels per metre (12 m on screen)
    final ground = size.height * 0.72;
    // Sky turns to sunset and night as you go further.
    final t = (g.distance % 1500) / 1500;
    final sky = Color.lerp(const Color(0xFF81D4FA), const Color(0xFFFF8A65), (sin(t * 2 * pi) + 1) / 2 * 0.6)!;
    canvas.drawRect(Offset.zero & size, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [sky, const Color(0xFFFFF3E0)]).createShader(Offset.zero & size));
    // Far hills and clouds, slower than the ground (parallax).
    final hills = Paint()..color = const Color(0xFFA5D6A7);
    for (var i = -1; i < 6; i++) {
      final x = i * size.width * 0.4 - (g.distance * m * 0.15) % (size.width * 0.4);
      canvas.drawCircle(Offset(x, ground + size.width * 0.15), size.width * 0.26, hills);
    }
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      final x = (i * size.width * 0.37 - g.distance * m * 0.05) % (size.width + 80) - 40;
      final y = size.height * (0.12 + 0.1 * (i % 2));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 70, height: 24), cloud);
      canvas.drawOval(Rect.fromCenter(center: Offset(x + 18, y - 8), width: 40, height: 22), cloud);
    }
    // Ground with moving stones.
    canvas.drawRect(Rect.fromLTRB(0, ground, size.width, size.height), Paint()..color = const Color(0xFFD7B98E));
    canvas.drawLine(Offset(0, ground), Offset(size.width, ground), Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 3);
    final stone = Paint()..color = const Color(0xFFA1887F);
    for (var i = 0; i < 14; i++) {
      final x = (i * 53.0 - g.distance * m) % (size.width + 20);
      canvas.drawCircle(Offset(x < 0 ? x + size.width + 20 : x, ground + 10 + (i % 3) * 9), 2.5, stone);
    }
    // Obstacles.
    for (final o in g.obstacles) {
      final x = o.x * m;
      if (o.bird) {
        final by = ground - (o.high ? 2.1 : 0.7) * m;
        final flap = (g.now ~/ 140).isEven ? '🦅' : '🐦';
        final tp = _tp(flap, m * 0.9);
        canvas.save();
        canvas.translate(x + tp.width, by - tp.height);
        canvas.scale(-1, 1); // flying towards the dino
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      } else {
        final tp = _tp('🌵', m * (0.8 + o.width * 0.5));
        tp.paint(canvas, Offset(x, ground - tp.height * 0.92));
      }
    }
    // The dino (facing right), with a shadow that shrinks as it jumps.
    final dx = g.dinoX * m - m * 0.5;
    canvas.drawOval(Rect.fromCenter(center: Offset(dx + m * 0.55, ground + 4), width: m * (0.9 - min(0.5, g.y * 0.15)), height: 7), Paint()..color = Colors.black26);
    final dino = _tp('🦖', m * 1.25);
    canvas.save();
    canvas.translate(dx + dino.width, ground - g.y * m - dino.height * 0.95);
    canvas.scale(-1, 1);
    dino.paint(canvas, Offset.zero);
    canvas.restore();
    if (g.over) {
      final boom = _tp('💥', m * 1.2);
      boom.paint(canvas, Offset(dx + m * 0.3, ground - g.y * m - m * 1.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
