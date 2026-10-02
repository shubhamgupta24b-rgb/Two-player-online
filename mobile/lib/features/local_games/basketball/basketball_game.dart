import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class Shot {
  final int points;
  final double timing;
  final double target;
  final int number; // nth shot, used to restart the ball animation
  const Shot(this.points, this.timing, this.target, this.number);
}

/// Same scoring as the online version: stop your power meter close to the moving
/// target (within 7 = 3 pts, 18 = 2 pts, 32 = 1 pt). 30 seconds, 0.5s between shots.
class BasketballLogic extends TimedDuel {
  static const meterPeriodMs = 1400;
  final int cooldownMs;
  final int targetCycleMs;
  final List<int> score;
  final List<int> shots;
  final List<int> _lastShotAt;
  final List<Shot?> lastShot;
  final List<double> _targets;

  BasketballLogic({int durationMs = 30000, this.cooldownMs = 500, this.targetCycleMs = 1200, int players = 2, Random? random})
      : score = List.filled(players, 0),
        shots = List.filled(players, 0),
        _lastShotAt = List.filled(players, -1 << 30),
        lastShot = List.filled(players, null),
        _targets = _makeTargets(random ?? Random(), durationMs ~/ targetCycleMs + 2),
        super(durationMs);

  static List<double> _makeTargets(Random r, int n) => [for (var i = 0; i < n; i++) 15 + r.nextDouble() * 70];

  @override
  List<int> get scores => score;

  /// The hoop's sweet spot, shared by both players so it's fair. Moves every [targetCycleMs].
  double get target => _targets[(elapsedMs ~/ targetCycleMs).clamp(0, _targets.length - 1)];

  /// Power meter 0..100 bouncing back and forth; player 2 is offset so they don't mirror each other.
  double meter(int player) {
    final phase = ((elapsedMs + player * 350) % meterPeriodMs) / meterPeriodMs;
    return (phase < 0.5 ? phase * 2 : 2 - phase * 2) * 100;
  }

  bool canShoot(int player) => !finished && elapsedMs - _lastShotAt[player] >= cooldownMs;

  static int pointsFor(double distance) => distance <= 7 ? 3 : distance <= 18 ? 2 : distance <= 32 ? 1 : 0;

  /// Returns the points scored, or null if the shot isn't allowed right now.
  int? shoot(int player) {
    if (!canShoot(player)) return null;
    final timing = meter(player);
    final t = target;
    final pts = pointsFor((timing - t).abs());
    _lastShotAt[player] = elapsedMs;
    shots[player]++;
    score[player] += pts;
    lastShot[player] = Shot(pts, timing, t, shots[player]);
    notifyListeners();
    return pts;
  }
}

final basketballInfo = LocalGameInfo(
  id: 'basketball_hoops',
  title: 'Basketball Hoops',
  emoji: '🏀',
  color: const Color(0xFFFF9F43),
  tagline: 'Time your shot, sink the basket!',
  rules: const [
    'Your power meter slides back and forth.',
    'Tap your side when the white line is in the green zone.',
    'Green = 3 pts, yellow = 2, orange = 1. Most points in 30s wins. 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  play: (players, onFinished) => TickingPlay<BasketballLogic>(
    create: () => BasketballLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      middle: DuelMiddleBar(players: players, scores: g.scores, secondsLeft: g.secondsLeft, progress: g.progress),
      center: ZoneCenterChip('${g.secondsLeft}s'),
      zone: (i) => _HoopHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _HoopHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final BasketballLogic g;
  const _HoopHalf({required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    final shot = g.lastShot[index];
    final ready = g.canShoot(index);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        final pts = g.shoot(index);
        if (pts != null && pts > 0) HapticFeedback.lightImpact().ignore();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(children: [
          Row(children: [
            PlayerTagSmall(player: player),
            const Spacer(),
            Text('${g.score[index]} pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
          Expanded(child: _Court(shot: shot, color: player.color)),
          _Meter(value: g.meter(index), target: g.target, dim: !ready),
          const SizedBox(height: 6),
          Text(ready ? 'TAP TO SHOOT' : 'RELOADING…', style: TextStyle(color: ready ? GpColors.accent : Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ]),
      ),
    );
  }
}

/// Backboard + hoop, with the last shot's ball flying in (or bouncing off).
class _Court extends StatelessWidget {
  final Shot? shot;
  final Color color;
  const _Court({required this.shot, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final hoopY = h * 0.28;
      final s = shot;
      return Stack(clipBehavior: Clip.none, children: [
        // Backboard and rim.
        Positioned(left: w / 2 - 50, top: hoopY - 54, child: Container(width: 100, height: 64, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6), border: Border.all(color: GpColors.no, width: 3)))),
        Positioned(left: w / 2 - 34, top: hoopY, child: Container(width: 68, height: 8, decoration: BoxDecoration(color: const Color(0xFFFF6B00), borderRadius: BorderRadius.circular(4)))),
        Positioned(left: w / 2 - 28, top: hoopY + 8, child: CustomPaint(size: const Size(56, 26), painter: _NetPainter())),
        if (s != null)
          TweenAnimationBuilder<double>(
            key: ValueKey(s.number),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (_, t, __) {
              // Misses drift sideways in the direction they were off by.
              final miss = s.points == 0 ? (s.timing > s.target ? 1 : -1) * 60.0 : (s.points == 1 ? 18.0 : 0);
              final x = w / 2 - 18 + miss * t;
              final y = h - 40 - (h - 40 - hoopY + 10) * sin(t * pi / 2);
              return Positioned(left: x, top: y, child: Opacity(opacity: t < 0.95 ? 1 : 0.6, child: const Text('🏀', style: TextStyle(fontSize: 34))));
            },
          ),
        if (s != null)
          Positioned(
            left: 0,
            right: 0,
            top: hoopY + 40,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('t${s.number}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, t, child) => Opacity(opacity: (1 - t).clamp(0, 1), child: Transform.translate(offset: Offset(0, -20 * t), child: child)),
              child: Text(
                ['MISS', '+1 RIM!', '+2 NICE!', '+3 SWISH!'][s.points],
                textAlign: TextAlign.center,
                style: TextStyle(color: s.points == 0 ? Colors.white54 : (s.points == 3 ? GpColors.yes : GpColors.accent), fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ]);
    });
  }
}

class _NetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(size.width / 2 + (x - size.width / 2) * 0.6, size.height), p);
    }
    canvas.drawLine(Offset(size.width * 0.2, size.height), Offset(size.width * 0.8, size.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Horizontal power meter with scoring zones around the target.
class _Meter extends StatelessWidget {
  final double value;
  final double target;
  final bool dim;
  const _Meter({required this.value, required this.target, required this.dim});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        width: double.infinity,
        child: CustomPaint(painter: _MeterPainter(value, target, dim)),
      );
}

class _MeterPainter extends CustomPainter {
  final double value, target;
  final bool dim;
  _MeterPainter(this.value, this.target, this.dim);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(r, Paint()..color = Colors.white12);
    double x(double v) => size.width * v.clamp(0, 100) / 100;
    void zone(double half, Color c) => canvas.drawRect(Rect.fromLTRB(x(target - half), 0, x(target + half), size.height), Paint()..color = c);
    zone(32, const Color(0xFFFF9F43));
    zone(18, GpColors.accent);
    zone(7, GpColors.yes);
    canvas.restore();
    final mx = x(value);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(mx - 3, -4, 6, size.height + 8), const Radius.circular(3)),
        Paint()..color = dim ? Colors.white38 : Colors.white);
  }

  @override
  bool shouldRepaint(_MeterPainter old) => old.value != value || old.target != target || old.dim != dim;
}
