import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

/// Same rules as the online version: claim cells, painting over a rival's cell
/// steals it, most cells after 25 seconds wins.
class PaintFightLogic extends TimedDuel {
  final int cols;
  final int rows;
  final List<int> owner; // -1 = empty
  final List<int> cells;

  PaintFightLogic({int durationMs = 25000, this.cols = 8, this.rows = 12, int players = 2})
      : owner = List.filled(cols * rows, -1),
        cells = List.filled(players, 0),
        super(durationMs);

  @override
  List<int> get scores => cells;

  /// Returns true if the cell changed hands.
  bool paint(int player, int col, int row) {
    if (finished || col < 0 || col >= cols || row < 0 || row >= rows) return false;
    final i = row * cols + col;
    final prev = owner[i];
    if (prev == player) return false;
    if (prev >= 0) cells[prev]--;
    owner[i] = player;
    cells[player]++;
    notifyListeners();
    return true;
  }
}

final paintFightInfo = LocalGameInfo(
  id: 'paint_fight',
  title: 'Paint Fight',
  emoji: '🎨',
  color: const Color(0xFF4D96FF),
  tagline: 'Cover the board in your colour!',
  rules: const [
    'Drag your finger to paint the board in your colour.',
    'Start each stroke on your own half, then paint anywhere, even over your rival.',
    'Painting over their cells steals them. Most cells after 25 seconds wins.',
  ],
  scoreUnit: 'cells',
  splitScreen: true,
  play: (players, onFinished) => TickingPlay<PaintFightLogic>(
    create: () => PaintFightLogic(),
    onFinished: onFinished,
    builder: (context, g) => Column(children: [
      RotatedBox(quarterTurns: 2, child: _Hud(player: players[1], cells: g.cells[1], total: g.owner.length)),
      Expanded(child: _PaintBoard(players: players, g: g)),
      DuelMiddleBar(players: players, scores: g.scores, secondsLeft: g.secondsLeft, progress: g.progress),
    ]),
  ),
);

class _Hud extends StatelessWidget {
  final GpPlayer player;
  final int cells;
  final int total;
  const _Hud({required this.player, required this.cells, required this.total});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Row(children: [
          PlayerTagSmall(player: player),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text('$cells cells · ${(cells * 100 / total).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ]),
      );
}

/// Shared board. Each finger belongs to whoever's half it first touched.
class _PaintBoard extends StatefulWidget {
  final List<GpPlayer> players;
  final PaintFightLogic g;
  const _PaintBoard({required this.players, required this.g});
  @override
  State<_PaintBoard> createState() => _PaintBoardState();
}

class _PaintBoardState extends State<_PaintBoard> {
  final _fingers = <int, (int player, Offset last)>{};
  Size _boardSize = Size.zero;
  Offset _origin = Offset.zero;

  PaintFightLogic get g => widget.g;
  double get _cell => min(_boardSize.width / g.cols, _boardSize.height / g.rows);

  void _paintAt(int player, Offset p) {
    final c = _cell;
    if (c <= 0) return;
    final local = p - _origin;
    g.paint(player, (local.dx / c).floor(), (local.dy / c).floor());
  }

  /// Paints every cell along the drag so fast swipes don't leave gaps.
  void _stroke(int player, Offset from, Offset to) {
    final steps = max(1, ((to - from).distance / (_cell / 2)).ceil());
    for (var s = 1; s <= steps; s++) {
      _paintAt(player, Offset.lerp(from, to, s / steps)!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _boardSize = c.biggest;
      final cell = _cell;
      final w = cell * g.cols, h = cell * g.rows;
      _origin = Offset((c.maxWidth - w) / 2, (c.maxHeight - h) / 2);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (g.finished) return;
          // Bottom half = player 1 (index 0), top half = player 2.
          final player = e.localPosition.dy >= c.maxHeight / 2 ? 0 : 1;
          _fingers[e.pointer] = (player, e.localPosition);
          _paintAt(player, e.localPosition);
        },
        onPointerMove: (e) {
          final f = _fingers[e.pointer];
          if (f == null) return;
          _stroke(f.$1, f.$2, e.localPosition);
          _fingers[e.pointer] = (f.$1, e.localPosition);
        },
        onPointerUp: (e) => _fingers.remove(e.pointer),
        onPointerCancel: (e) => _fingers.remove(e.pointer),
        child: Stack(children: [
          Positioned(
            left: _origin.dx,
            top: _origin.dy,
            width: w,
            height: h,
            child: RepaintBoundary(child: CustomPaint(painter: _BoardPainter(g, widget.players.map((p) => p.color).toList(), cell))),
          ),
        ]),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  final PaintFightLogic g;
  final List<Color> colors;
  final double cell;
  // Snapshot so shouldRepaint can compare boards.
  final List<int> _owners;
  _BoardPainter(this.g, this.colors, this.cell) : _owners = List.of(g.owner);

  @override
  void paint(Canvas canvas, Size size) {
    final empty = Paint()..color = Colors.white10;
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final o = _owners[r * g.cols + c];
        final rect = Rect.fromLTWH(c * cell + 2, r * cell + 2, cell - 4, cell - 4);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)), o < 0 ? empty : (Paint()..color = colors[o]));
      }
    }
    // Halfway line: where each player's strokes must start.
    final y = g.rows * cell / 2;
    final line = Paint()
      ..color = Colors.white38
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, y), Offset(min(x + 7, size.width), y), line);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => cell != old.cell || !_listEquals(_owners, old._owners);

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
