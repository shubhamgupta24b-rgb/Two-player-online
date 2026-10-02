import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Simple 2D vector for the table physics.
class V {
  static const zero = V(0, 0);
  final double x, y;
  const V(this.x, this.y);
  V operator +(V o) => V(x + o.x, y + o.y);
  V operator -(V o) => V(x - o.x, y - o.y);
  V operator *(double k) => V(x * k, y * k);
  double dot(V o) => x * o.x + y * o.y;
  double get length => sqrt(x * x + y * y);
}

/// Air hockey on a 1 x [length] table. Player 1 defends the bottom goal, player 2 the
/// top. Each moves a mallet inside their own half. First to [target] goals, or the
/// leader when the clock runs out.
class AirHockeyLogic extends TimedDuel {
  static const length = 1.6;
  static const puckR = 0.045, malletR = 0.075, goalHalf = 0.18, maxSpeed = 2.6;
  final int target;
  final List<int> goals = [0, 0];
  V puck = const V(0.5, length / 2);
  V vel = V.zero;
  final List<V> mallet = [const V(0.5, length - 0.2), const V(0.5, 0.2)];
  final List<V> _malletVel = [V.zero, V.zero];
  int? lastGoalBy;
  int _last = 0;
  int? _resumeAt;

  AirHockeyLogic({this.target = 5, int durationMs = 120000}) : super(durationMs);

  @override
  List<int> get scores => goals;
  @override
  bool get finished => super.finished || goals.any((g) => g >= target);
  bool get paused => _resumeAt != null;

  /// Moves a player's mallet to [to] (table coordinates), kept inside their own half.
  void moveMallet(int p, V to) {
    final minY = p == 0 ? length / 2 + malletR : malletR;
    final maxY = p == 0 ? length - malletR : length / 2 - malletR;
    final clamped = V(to.x.clamp(malletR, 1 - malletR), to.y.clamp(minY, maxY));
    _malletVel[p] = (clamped - mallet[p]) * 60; // roughly per-frame movement -> per second
    mallet[p] = clamped;
  }

  @override
  void onUpdate() {
    final dt = ((elapsedMs - _last) / 1000).clamp(0.0, 0.05);
    _last = elapsedMs;
    final resume = _resumeAt;
    if (resume != null) {
      if (elapsedMs < resume) return;
      _resumeAt = null;
    }
    const steps = 4;
    for (var i = 0; i < steps; i++) {
      _step(dt / steps);
      if (paused) break;
    }
    for (var p = 0; p < 2; p++) {
      _malletVel[p] = _malletVel[p] * 0.6; // stop "pushing" when the finger stops
    }
  }

  void _step(double dt) {
    puck = puck + vel * dt;
    vel = vel * (1 - 0.35 * dt); // table friction
    // Side walls.
    if (puck.x < puckR && vel.x < 0 || puck.x > 1 - puckR && vel.x > 0) vel = V(-vel.x * 0.95, vel.y);
    puck = V(puck.x.clamp(puckR, 1 - puckR), puck.y);
    // End walls and goals.
    final inGoalMouth = (puck.x - 0.5).abs() < goalHalf;
    if (puck.y < -puckR && inGoalMouth) return _goal(0);
    if (puck.y > length + puckR && inGoalMouth) return _goal(1);
    if (!inGoalMouth) {
      if (puck.y < puckR && vel.y < 0 || puck.y > length - puckR && vel.y > 0) vel = V(vel.x, -vel.y * 0.95);
      puck = V(puck.x, puck.y.clamp(puckR, length - puckR));
    }
    // Mallets.
    for (var p = 0; p < 2; p++) {
      final d = puck - mallet[p];
      final dist = d.length;
      if (dist < puckR + malletR && dist > 0) {
        final n = d * (1 / dist);
        puck = mallet[p] + n * (puckR + malletR);
        final rel = vel - _malletVel[p];
        final along = rel.dot(n);
        if (along < 0) vel = vel - n * (1.9 * along);
        vel = vel + n * 0.15; // always a little kick away from the mallet
      }
    }
    final speed = vel.length;
    if (speed > maxSpeed) vel = vel * (maxSpeed / speed);
  }

  void _goal(int scorer) {
    goals[scorer]++;
    HapticFeedback.heavyImpact().ignore();
    lastGoalBy = scorer;
    // Puck restarts in the conceding player's half.
    puck = V(0.5, scorer == 0 ? length * 0.3 : length * 0.7);
    vel = V.zero;
    _resumeAt = elapsedMs + 900;
  }
}

final airHockeyInfo = LocalGameInfo(
  id: 'air_hockey',
  title: 'Air Hockey',
  emoji: '🏒',
  color: const Color(0xFF4D96FF),
  tagline: 'Smash the puck into their goal!',
  rules: const [
    'Drag your mallet around your half of the table.',
    'Hit the puck into the goal at the far end.',
    'First to 5 goals wins (or the leader after 2 minutes).',
  ],
  scoreUnit: 'goals',
  splitScreen: true,
  play: (players, onFinished) => TickingPlay<AirHockeyLogic>(
    create: () => AirHockeyLogic(),
    onFinished: onFinished,
    builder: (context, g) => Column(children: [
      Expanded(child: Padding(padding: const EdgeInsets.all(8), child: TableView(players: players, logic: g))),
      DuelMiddleBar(players: players, scores: g.scores, secondsLeft: g.secondsLeft, progress: g.progress),
    ]),
  ),
);

/// Shared table widget: draws the table and turns touches into mallet moves.
/// Touches in the bottom half drive player 1, the top half player 2.
class TableView extends StatefulWidget {
  final List<GpPlayer> players;
  final AirHockeyLogic logic;
  const TableView({super.key, required this.players, required this.logic});
  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  final _fingers = <int, int>{}; // pointer -> player
  Rect _table = Rect.zero;

  V _toTable(Offset p) => V((p.dx - _table.left) / _table.width, (p.dy - _table.top) / _table.width);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Fit a 1 x length table into the space.
      final w = min(c.maxWidth, c.maxHeight / AirHockeyLogic.length);
      final h = w * AirHockeyLogic.length;
      _table = Rect.fromLTWH((c.maxWidth - w) / 2, (c.maxHeight - h) / 2, w, h);
      void move(PointerEvent e) {
        final p = _fingers[e.pointer];
        if (p != null) widget.logic.moveMallet(p, _toTable(e.localPosition));
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _fingers[e.pointer] = e.localPosition.dy > c.maxHeight / 2 ? 0 : 1;
          move(e);
        },
        onPointerMove: move,
        onPointerUp: (e) => _fingers.remove(e.pointer),
        onPointerCancel: (e) => _fingers.remove(e.pointer),
        child: CustomPaint(size: c.biggest, painter: _TablePainter(widget.logic, _table, widget.players.map((p) => p.color).toList())),
      );
    });
  }
}

class _TablePainter extends CustomPainter {
  final AirHockeyLogic g;
  final Rect table;
  final List<Color> colors;
  final V puck;
  final List<V> mallets;
  _TablePainter(this.g, this.table, this.colors)
      : puck = g.puck,
        mallets = List.of(g.mallet);

  @override
  void paint(Canvas canvas, Size size) {
    final s = table.width;
    Offset at(V v) => Offset(table.left + v.x * s, table.top + v.y * s);
    canvas.drawRRect(RRect.fromRectAndRadius(table, Radius.circular(s * 0.08)), Paint()..color = const Color(0xFF1B2A4A));
    final line = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(at(const V(0, AirHockeyLogic.length / 2)), at(const V(1, AirHockeyLogic.length / 2)), line);
    canvas.drawCircle(at(const V(0.5, AirHockeyLogic.length / 2)), s * 0.15, line);
    // Goals.
    for (final (y, c) in [(0.0, colors[1]), (AirHockeyLogic.length, colors[0])]) {
      canvas.drawLine(at(V(0.5 - AirHockeyLogic.goalHalf, y)), at(V(0.5 + AirHockeyLogic.goalHalf, y)), Paint()
        ..color = c
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round);
    }
    // Mallets and puck.
    for (var p = 0; p < 2; p++) {
      canvas.drawCircle(at(mallets[p]), AirHockeyLogic.malletR * s, Paint()..color = colors[p]);
      canvas.drawCircle(at(mallets[p]), AirHockeyLogic.malletR * s * 0.45, Paint()..color = Color.lerp(colors[p], Colors.white, 0.5)!);
    }
    canvas.drawCircle(at(puck), AirHockeyLogic.puckR * s, Paint()..color = GpColors.accent);
    canvas.drawCircle(at(puck), AirHockeyLogic.puckR * s, Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    if (g.paused && g.lastGoalBy != null) {
      final tp = TextPainter(
        text: const TextSpan(text: 'GOAL!', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, table.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) => true;
}
