import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';
import '../widgets/dice.dart';

/// Classic Snakes & Ladders, 2-6 players. Roll, move, climb ladders, slide down snakes.
/// A 6 rolls again. You need the exact number to land on 100 (otherwise you stay put).
class SnakesLaddersLogic extends LocalGameLogic {
  static const ladders = {4: 14, 9: 31, 20: 38, 28: 84, 40: 59, 51: 67, 63: 81, 71: 91};
  static const snakes = {17: 7, 54: 34, 62: 19, 64: 60, 87: 24, 93: 73, 95: 75, 99: 78};
  final int players;
  final Random _random;
  final List<int> pos; // 0 = not on the board yet
  int turn = 0;
  int? lastRoll;
  int? winner;
  String message = 'Tap the dice to roll';
  int rolls = 0; // bumps on every roll, for the dice animation

  SnakesLaddersLogic({this.players = 2, Random? random})
      : _random = random ?? Random(),
        pos = List.filled(players, 0);

  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => [for (var i = 0; i < players; i++) winner == i ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// Rolls for the current player (or uses [value], for tests) and moves them.
  int? roll([int? value]) {
    if (forward('roll', const [])) return null;
    if (finished) return null;
    final r = value ?? _random.nextInt(6) + 1;
    lastRoll = r;
    rolls++;
    final p = turn;
    final target = pos[p] + r;
    if (target > 100) {
      message = 'Need exactly ${100 - pos[p]} to finish';
    } else {
      var land = target;
      if (ladders.containsKey(land)) {
        message = '🪜 Ladder! Up from $land to ${ladders[land]}';
        land = ladders[land]!;
      } else if (snakes.containsKey(land)) {
        message = '🐍 Snake! Down from $land to ${snakes[land]}';
        land = snakes[land]!;
      } else {
        message = 'Moved to $land';
      }
      pos[p] = land;
      if (land == 100) {
        winner = p;
        message = 'Reached 100!';
        notifyListeners();
        return r;
      }
    }
    if (r == 6) {
      message += ' · Rolled 6, go again!';
    } else {
      turn = (turn + 1) % players;
    }
    notifyListeners();
    return r;
  }

  /// Grid position of square [n] (1-100): row 0 is the top. Rows snake left/right.
  static (int col, int row) cell(int n) {
    final i = n - 1;
    final rowFromBottom = i ~/ 10;
    final c = rowFromBottom.isEven ? i % 10 : 9 - i % 10;
    return (c, 9 - rowFromBottom);
  }
}

final snakesLaddersInfo = LocalGameInfo(
  id: 'snakes_ladders',
  title: 'Snakes & Ladders',
  emoji: '🐍',
  color: const Color(0xFF2EAA4F),
  tagline: 'Climb up, slide down, race to 100!',
  rules: const [
    'Take turns tapping the dice. Your token moves that many squares.',
    'Land at the foot of a ladder 🪜 to climb up; land on a snake 🐍 head and slide down.',
    'Rolling a 6 gives you another roll. You need the exact number to land on 100.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  maxPlayers: 6,
  bot: botFor<SnakesLaddersLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (b.thinkFirst(g.rolls, now, 800, 1400)) g.roll();
  }),
  online: RelaySpec<SnakesLaddersLogic>(
    create: (n) => SnakesLaddersLogic(players: n),
    save: (g) => {'pos': g.pos, 'turn': g.turn, 'roll': g.lastRoll, 'rolls': g.rolls, 'winner': g.winner, 'msg': g.message},
    load: (g, s, me) {
      g.pos.setAll(0, ints(s['pos']));
      g.turn = asInt(s['turn']);
      g.lastRoll = nInt(s['roll']);
      g.rolls = asInt(s['rolls']);
      g.winner = nInt(s['winner']);
      g.message = s['msg'] as String;
    },
    apply: (g, from, name, a) {
      if (name == 'roll' && from == g.turn) g.roll();
    },
    view: (context, g, players, me) => _SnlTable(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<SnakesLaddersLogic>(
    create: () => SnakesLaddersLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _SnlTable(players: players, g: g),
  ),
);

class _SnlTable extends StatelessWidget {
  final List<GpPlayer> players;
  final SnakesLaddersLogic g;
  const _SnlTable({required this.players, required this.g});

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < players.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: i == g.turn ? players[i].color : Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: players[i].color, width: 2)),
                  child: Text('${players[i].name} · ${g.pos[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _Board(players: players, g: g)))),
        const SizedBox(height: 8),
        Text(g.message, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text("${current.name.toUpperCase()}'S ROLL", overflow: TextOverflow.ellipsis, style: TextStyle(color: current.color, fontWeight: FontWeight.w900, fontSize: 18))),
          const SizedBox(width: 14),
          RollingDice(
            value: g.lastRoll ?? 1,
            rollId: g.rolls,
            color: current.color,
            size: 64,
            onTap: g.finished
                ? null
                : () {
                    HapticFeedback.mediumImpact().ignore();
                    g.roll();
                  },
          ),
        ]),
      ]),
    );
  }
}

class _Board extends StatelessWidget {
  final List<GpPlayer> players;
  final SnakesLaddersLogic g;
  const _Board({required this.players, required this.g});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth / 10;
      final tokens = <Widget>[];
      for (var p = 0; p < players.length; p++) {
        final n = g.pos[p];
        if (n == 0) continue;
        final (col, row) = SnakesLaddersLogic.cell(n);
        // Fan out tokens sharing a square.
        final same = [for (var q = 0; q < players.length; q++) if (g.pos[q] == n) q];
        final k = same.indexOf(p);
        final off = same.length == 1 ? Offset.zero : Offset(cos(k * 2 * pi / same.length), sin(k * 2 * pi / same.length)) * s * 0.18;
        tokens.add(AnimatedPositioned(
          key: ValueKey('t$p'),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutBack,
          left: col * s + s * 0.2 + off.dx,
          top: row * s + s * 0.2 + off.dy,
          width: s * 0.6,
          height: s * 0.6,
          child: _Token(color: players[p].color, active: p == g.turn),
        ));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _SnlPainter())),
          ...tokens,
        ]),
      );
    });
  }
}

class _Token extends StatelessWidget {
  final Color color;
  final bool active;
  const _Token({required this.color, required this.active});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(color, Colors.white, 0.45)!, color]),
          border: Border.all(color: active ? Colors.white : Colors.black54, width: active ? 2.5 : 1.5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 2))],
        ),
      );
}

class _SnlPainter extends CustomPainter {
  const _SnlPainter();
  static const _tiles = [Color(0xFFFFF3C4), Color(0xFFFFD6A5), Color(0xFFCAFFBF), Color(0xFF9BF6FF), Color(0xFFBDB2FF), Color(0xFFFFC6FF)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 10;
    Offset centre(int n) {
      final (c, r) = SnakesLaddersLogic.cell(n);
      return Offset((c + 0.5) * s, (r + 0.5) * s);
    }

    for (var n = 1; n <= 100; n++) {
      final (c, r) = SnakesLaddersLogic.cell(n);
      canvas.drawRect(Rect.fromLTWH(c * s, r * s, s, s), Paint()..color = _tiles[(c + r) % _tiles.length]);
      final tp = TextPainter(
        text: TextSpan(text: n == 100 ? '🏁' : '$n', style: TextStyle(color: const Color(0xFF5A4A6A), fontSize: s * 0.26, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c * s + s * 0.08, r * s + s * 0.04));
    }
    // Ladders.
    SnakesLaddersLogic.ladders.forEach((from, to) {
      final a = centre(from), b = centre(to);
      final dir = (b - a);
      final normal = Offset(-dir.dy, dir.dx) / dir.distance * s * 0.17;
      final rail = Paint()
        ..color = const Color(0xFF8B5A2B)
        ..strokeWidth = s * 0.09
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a + normal, b + normal, rail);
      canvas.drawLine(a - normal, b - normal, rail);
      final rungs = (dir.distance / (s * 0.45)).floor();
      for (var i = 1; i < rungs; i++) {
        final p = a + dir * (i / rungs);
        canvas.drawLine(p + normal, p - normal, rail..strokeWidth = s * 0.07);
      }
    });
    // Snakes: wavy bodies from head to tail.
    const snakeColors = [Color(0xFF2EAA4F), Color(0xFFE53935), Color(0xFF7B4DFF), Color(0xFFFF8A3D)];
    var k = 0;
    SnakesLaddersLogic.snakes.forEach((head, tail) {
      final a = centre(head), b = centre(tail);
      final dir = b - a;
      final normal = Offset(-dir.dy, dir.dx) / dir.distance;
      final path = Path()..moveTo(a.dx, a.dy);
      const steps = 24;
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final p = a + dir * t + normal * sin(t * pi * 3) * s * 0.35 * (1 - t * 0.5);
        path.lineTo(p.dx, p.dy);
      }
      final color = snakeColors[k++ % snakeColors.length];
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22
        ..strokeCap = StrokeCap.round
        ..color = Colors.black38);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.17
        ..strokeCap = StrokeCap.round
        ..color = color);
      canvas.drawCircle(a, s * 0.2, Paint()..color = color);
      canvas.drawCircle(a, s * 0.2, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..color = Colors.black45);
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(a + normal * side * s * 0.08 - dir / dir.distance * s * 0.04, s * 0.045, Paint()..color = Colors.white);
        canvas.drawCircle(a + normal * side * s * 0.08 - dir / dir.distance * s * 0.04, s * 0.02, Paint()..color = Colors.black);
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
