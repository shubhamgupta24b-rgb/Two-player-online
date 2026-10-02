import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../air_hockey/air_hockey_game.dart' show V;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Ping pong on a 1 x [length] table. Player 1's paddle is at the bottom, player 2's at
/// the top; each slides theirs left and right. Where the ball hits the paddle sets its
/// angle, and every hit speeds it up. First to [target] points.
class PingPongLogic extends LocalGameLogic {
  static const length = 1.6, ballR = 0.03, paddleHalf = 0.13, paddleY = 0.09, startSpeed = 0.95, maxSpeed = 2.4;
  final int target;
  final Random _rng;
  final List<int> points = [0, 0];
  final List<double> paddleX = [0.5, 0.5];
  V ball = const V(0.5, length / 2);
  V vel = V.zero;
  double speed = startSpeed;
  int? lastPointTo;
  int _now = 0, _last = 0;
  int? _serveAt = 900;
  int _serveTo = 0;

  PingPongLogic({this.target = 7, Random? random}) : _rng = random ?? Random() {
    _serveTo = _rng.nextInt(2);
  }

  @override
  List<int> get scores => points;
  @override
  bool get finished => points.any((p) => p >= target);
  bool get waitingToServe => _serveAt != null;

  void movePaddle(int p, double x) => paddleX[p] = x.clamp(paddleHalf, 1 - paddleHalf);

  /// Y of each player's paddle face: bottom for player 1, top for player 2.
  static double paddleLine(int p) => p == 0 ? length - paddleY : paddleY;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final dt = ((_now - _last) / 1000).clamp(0.0, 0.05);
    _last = _now;
    if (finished) return;
    final serve = _serveAt;
    if (serve != null) {
      if (_now < serve) return notifyListeners();
      _serveAt = null;
      speed = startSpeed;
      final angle = (_rng.nextDouble() - 0.5) * 0.9;
      ball = const V(0.5, length / 2);
      vel = V(sin(angle), _serveTo == 0 ? cos(angle) : -cos(angle)) * speed;
    }
    for (var i = 0; i < 4; i++) {
      _step(dt / 4);
      if (_serveAt != null) break;
    }
    notifyListeners();
  }

  void _step(double dt) {
    ball = ball + vel * dt;
    if (ball.x < ballR && vel.x < 0 || ball.x > 1 - ballR && vel.x > 0) vel = V(-vel.x, vel.y);
    for (var p = 0; p < 2; p++) {
      final y = paddleLine(p);
      final towards = p == 0 ? vel.y > 0 : vel.y < 0;
      final reached = p == 0 ? ball.y + ballR >= y : ball.y - ballR <= y;
      final notPast = p == 0 ? ball.y < y + 0.03 : ball.y > y - 0.03;
      if (towards && reached && notPast && (ball.x - paddleX[p]).abs() <= paddleHalf + ballR) {
        // Hit: the further from the centre, the sharper the angle.
        final offset = ((ball.x - paddleX[p]) / paddleHalf).clamp(-1.0, 1.0);
        speed = min(maxSpeed, speed * 1.07);
        final angle = offset * 1.0;
        vel = V(sin(angle), p == 0 ? -cos(angle) : cos(angle)) * speed;
        HapticFeedback.selectionClick().ignore();
      }
    }
    if (ball.y > length + ballR) return _point(1);
    if (ball.y < -ballR) return _point(0);
  }

  void _point(int to) {
    points[to]++;
    lastPointTo = to;
    vel = V.zero;
    ball = const V(0.5, length / 2);
    _serveTo = 1 - to; // serve towards the player who lost the point
    _serveAt = _now + 900;
  }
}

final pingPongInfo = LocalGameInfo(
  id: 'ping_pong',
  title: 'Ping Pong',
  emoji: '🏓',
  color: const Color(0xFFFF9F43),
  tagline: "Don't let it past you!",
  rules: const [
    'Slide your finger left and right on your half to move your paddle.',
    'Hit the ball with the edge of the paddle to angle it. It speeds up every hit.',
    'If the ball gets past your paddle, your rival scores. First to 7 wins.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  play: (players, onFinished) => TickingPlay<PingPongLogic>(
    create: () => PingPongLogic(),
    onFinished: onFinished,
    builder: (context, g) => Column(children: [
      Expanded(child: Padding(padding: const EdgeInsets.all(8), child: _PongTable(players: players, g: g))),
      ScoreMiddleBar(players: players, scores: g.scores, label: 'FIRST TO ${g.target}'),
    ]),
  ),
);

class _PongTable extends StatefulWidget {
  final List<GpPlayer> players;
  final PingPongLogic g;
  const _PongTable({required this.players, required this.g});
  @override
  State<_PongTable> createState() => _PongTableState();
}

class _PongTableState extends State<_PongTable> {
  final _fingers = <int, int>{};
  Rect _table = Rect.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = min(c.maxWidth, c.maxHeight / PingPongLogic.length);
      final h = w * PingPongLogic.length;
      _table = Rect.fromLTWH((c.maxWidth - w) / 2, (c.maxHeight - h) / 2, w, h);
      void move(PointerEvent e) {
        final p = _fingers[e.pointer];
        if (p != null) widget.g.movePaddle(p, (e.localPosition.dx - _table.left) / _table.width);
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
        child: CustomPaint(size: c.biggest, painter: _PongPainter(widget.g, _table, widget.players.map((p) => p.color).toList())),
      );
    });
  }
}

class _PongPainter extends CustomPainter {
  final PingPongLogic g;
  final Rect table;
  final List<Color> colors;
  final V ball;
  final List<double> paddles;
  _PongPainter(this.g, this.table, this.colors)
      : ball = g.ball,
        paddles = List.of(g.paddleX);

  @override
  void paint(Canvas canvas, Size size) {
    final s = table.width;
    Offset at(double x, double y) => Offset(table.left + x * s, table.top + y * s);
    canvas.drawRRect(RRect.fromRectAndRadius(table, Radius.circular(s * 0.05)), Paint()..color = const Color(0xFF1F6F5C));
    final white = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3;
    canvas.drawLine(at(0, PingPongLogic.length / 2), at(1, PingPongLogic.length / 2), white);
    canvas.drawLine(at(0.5, 0), at(0.5, PingPongLogic.length), Paint()
      ..color = Colors.white24
      ..strokeWidth = 2);
    for (var p = 0; p < 2; p++) {
      final y = PingPongLogic.paddleLine(p);
      final r = Rect.fromCenter(center: at(paddles[p], y + (p == 0 ? 0.0125 : -0.0125)), width: PingPongLogic.paddleHalf * 2 * s, height: 0.025 * s);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(0.0125 * s)), Paint()..color = colors[p]);
    }
    if (!g.waitingToServe || g.lastPointTo == null) {
      canvas.drawCircle(at(ball.x, ball.y), PingPongLogic.ballR * s, Paint()..color = Colors.white);
    }
    if (g.waitingToServe) {
      final text = g.lastPointTo == null ? 'GET READY' : 'POINT!';
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(color: GpColors.accent, fontSize: 40, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, table.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PongPainter old) => true;
}
