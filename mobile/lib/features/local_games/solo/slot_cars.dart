import 'dart:math';
import 'package:flutter/material.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

class SlotObstacle {
  final int lane;
  double y;
  SlotObstacle(this.lane, this.y);
}

/// A short, touch-controlled slot-car time trial. Stay on the track, dodge traffic,
/// and survive 45 seconds. The speed increases gradually.
class SlotCarsLogic extends SoloLogic {
  static const durationMs = 45000;
  final Random _rng;
  final List<SlotObstacle> obstacles = [];
  int lane = 1;
  int dodged = 0;
  int hits = 0;
  int _nextObstacle = 800;
  int _lastScoredSecond = -1;
  int _lastElapsed = 0;

  SlotCarsLogic({Random? random}) : _rng = random ?? Random();

  int get msLeft => max(0, durationMs - now);
  double get speed => 0.42 + (now / durationMs) * 0.42;

  void steer(int delta) {
    if (over) return;
    lane = (lane + delta).clamp(0, 2);
    notifyListeners();
  }

  @override
  void step(int elapsed) {
    if (elapsed >= durationMs) {
      gameOver();
      return;
    }
    final second = elapsed ~/ 1000;
    if (second > _lastScoredSecond) {
      score += 1;
      _lastScoredSecond = second;
    }
    final dt = ((elapsed - _lastElapsed) / 1000).clamp(0.0, 0.05);
    _lastElapsed = elapsed;
    for (final o in obstacles) {
      o.y += speed * dt;
    }
    for (final o in obstacles.where((o) => o.y >= 0.76 && o.y <= 0.91 && o.lane == lane).toList()) {
      obstacles.remove(o);
      hits++;
      score = max(0, score - 3);
    }
    final before = obstacles.length;
    obstacles.removeWhere((o) => o.y > 1.08);
    dodged += before - obstacles.length;
    if (elapsed >= _nextObstacle) {
      obstacles.add(SlotObstacle(_rng.nextInt(3), -0.12));
      _nextObstacle = elapsed + max(420, 850 - (elapsed ~/ 100)).toInt();
    }
    notifyListeners();
  }
}

final slotCarsInfo = LocalGameInfo(
  id: 'slot_cars',
  title: 'Slot Cars',
  emoji: '🏎️',
  color: const Color(0xFFB44A35),
  tagline: 'Hold your line. Dodge traffic. Beat the clock.',
  rules: const [
    'Use the left and right buttons to switch between three lanes.',
    'Avoid the cars ahead. A collision costs 3 points.',
    'Survive for 45 seconds; the track gets faster as you go.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SlotCarsLogic>(
    create: () => SlotCarsLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: 'SLOT CARS',
      score: g.score,
      extra: 'TIME ${(g.msLeft / 1000).ceil()}s  ·  DODGED ${g.dodged}',
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SlotTrackPainter(lane: g.lane, obstacles: g.obstacles),
                      ),
                    ),
                    Positioned(
                      left: 0, right: 0, bottom: 22,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var i = 0; i < 3; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 48, height: 70,
                              decoration: BoxDecoration(
                                color: g.lane == i ? const Color(0xFFFFD166) : const Color(0xFF292D32),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: g.lane == i ? const Color(0xFFFFF0B3) : const Color(0xFF626970), width: 2),
                                boxShadow: g.lane == i ? const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 3))] : const [],
                              ),
                              alignment: Alignment.center,
                              child: Text(g.lane == i ? '🏎️' : '🚗', style: const TextStyle(fontSize: 28)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 18),
              Expanded(child: _SteerButton(label: '← LEFT', onTap: () => g.steer(-1))),
              const SizedBox(width: 12),
              Expanded(child: _SteerButton(label: 'RIGHT →', onTap: () => g.steer(1))),
              const SizedBox(width: 18),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  ),
);

class _SteerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SteerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF292D32),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    ),
  );
}

class _SlotTrackPainter extends CustomPainter {
  final int lane;
  final List<SlotObstacle> obstacles;
  _SlotTrackPainter({required this.lane, required this.obstacles});

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = const Color(0xFF343A40);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF6C8C50));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .08, 0, size.width * .84, size.height), const Radius.circular(16)), road);
    final dash = Paint()..color = const Color(0xFFE7E2D8)..strokeWidth = 2;
    for (var laneLine = 1; laneLine <= 2; laneLine++) {
      final x = size.width * (.08 + .84 * laneLine / 3);
      for (var y = -30.0; y < size.height; y += 52) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 25), dash);
      }
    }
    final curb = Paint()..color = const Color(0xFFC85D48)..strokeWidth = 5;
    canvas.drawLine(Offset(size.width * .08, 0), Offset(size.width * .08, size.height), curb);
    canvas.drawLine(Offset(size.width * .92, 0), Offset(size.width * .92, size.height), curb);
    for (final o in obstacles) {
      final x = size.width * (.08 + .84 * (o.lane + .5) / 3);
      final y = o.y * size.height;
      final rect = Rect.fromCenter(center: Offset(x, y), width: size.width * .13, height: size.height * .075);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), Paint()..color = const Color(0xFFB9C3CB));
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(4)), Paint()..color = const Color(0xFF9A4938));
    }
  }

  @override
  bool shouldRepaint(covariant _SlotTrackPainter oldDelegate) => true;
}
