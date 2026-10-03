import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';

/// Dots & Boxes on a 6x6 dot grid (25 boxes). Draw one line per turn; closing a box
/// claims it and earns another line. When every line is drawn, most boxes wins.
class DotsBoxesLogic extends LocalGameLogic {
  final int size; // boxes per side
  final int players;
  late final List<List<int>> hLines = List.generate(size + 1, (_) => List.filled(size, -1)); // [row][col]
  late final List<List<int>> vLines = List.generate(size, (_) => List.filled(size + 1, -1));
  late final List<List<int>> boxes = List.generate(size, (_) => List.filled(size, -1));
  int turn = 0;
  (bool, int, int)? lastLine; // (horizontal, row, col)

  DotsBoxesLogic({this.players = 2, this.size = 5});

  int get totalLines => 2 * size * (size + 1);
  int get drawn => hLines.expand((r) => r).where((x) => x >= 0).length + vLines.expand((r) => r).where((x) => x >= 0).length;
  @override
  bool get finished => drawn == totalLines;
  @override
  List<int> get scores => [for (var p = 0; p < players; p++) boxes.expand((r) => r).where((x) => x == p).length];
  @override
  void update(int elapsedMs) {}

  bool _boxDone(int r, int c) => hLines[r][c] >= 0 && hLines[r + 1][c] >= 0 && vLines[r][c] >= 0 && vLines[r][c + 1] >= 0;

  /// Draws a line. Returns how many boxes it closed, or null if it was already drawn / off the grid.
  int? drawLine({required bool horizontal, required int row, required int col}) {
    if (forward('line', [horizontal, row, col])) return null;
    final lines = horizontal ? hLines : vLines;
    if (row < 0 || row >= lines.length || col < 0 || col >= lines[row].length || lines[row][col] >= 0) return null;
    lines[row][col] = turn;
    lastLine = (horizontal, row, col);
    // Boxes either side of the line.
    final candidates = horizontal ? [(row - 1, col), (row, col)] : [(row, col - 1), (row, col)];
    var closed = 0;
    for (final (r, c) in candidates) {
      if (r < 0 || r >= size || c < 0 || c >= size || boxes[r][c] >= 0) continue;
      if (_boxDone(r, c)) {
        boxes[r][c] = turn;
        closed++;
      }
    }
    if (closed == 0) turn = (turn + 1) % players;
    notifyListeners();
    return closed;
  }
}

final dotsBoxesInfo = LocalGameInfo(
  id: 'dots_boxes',
  title: 'Dots & Boxes',
  emoji: '🔲',
  color: const Color(0xFF7B4DFF),
  tagline: 'Close the box, steal the board!',
  rules: const [
    'Take turns tapping between two dots to draw a line.',
    'Close the fourth side of a box to claim it, then draw again.',
    'When all lines are drawn, the most boxes wins. 2 to 4 players.',
  ],
  scoreUnit: 'boxes',
  splitScreen: false,
  maxPlayers: 4,
  bot: botFor<DotsBoxesLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.drawn, now, 500, 1000)) return;
    final n = g.size;
    int sides(int r, int c) => [g.hLines[r][c], g.hLines[r + 1][c], g.vLines[r][c], g.vLines[r][c + 1]].where((x) => x >= 0).length;
    List<(int, int)> boxesOf(bool h, int r, int c) => h ? [(r - 1, c), (r, c)] : [(r, c - 1), (r, c)];
    bool inside((int, int) p) => p.$1 >= 0 && p.$1 < n && p.$2 >= 0 && p.$2 < n;
    final free = <(bool, int, int)>[
      for (var r = 0; r <= n; r++) for (var c = 0; c < n; c++) if (g.hLines[r][c] < 0) (true, r, c),
      for (var r = 0; r < n; r++) for (var c = 0; c <= n; c++) if (g.vLines[r][c] < 0) (false, r, c),
    ];
    // Take a box if one is ready; otherwise avoid handing over a box (a third side); otherwise anything.
    final closing = free.where((l) => boxesOf(l.$1, l.$2, l.$3).where(inside).any((p) => sides(p.$1, p.$2) == 3));
    final safe = free.where((l) => boxesOf(l.$1, l.$2, l.$3).where(inside).every((p) => sides(p.$1, p.$2) < 2));
    final (bool, int, int) line = closing.firstOrNull ?? (safe.isNotEmpty ? b.pick(safe.toList()) : b.pick(free));
    g.drawLine(horizontal: line.$1, row: line.$2, col: line.$3);
  }),
  online: RelaySpec<DotsBoxesLogic>(
    create: (n) => DotsBoxesLogic(players: n),
    save: (g) => {
      'h': [for (final r in g.hLines) ...r],
      'v': [for (final r in g.vLines) ...r],
      'b': [for (final r in g.boxes) ...r],
      'turn': g.turn,
      'last': g.lastLine == null ? null : [g.lastLine!.$1, g.lastLine!.$2, g.lastLine!.$3],
    },
    load: (g, s, me) {
      void fill(List<List<int>> grid, List<int> flat) {
        var k = 0;
        for (final row in grid) {
          for (var c = 0; c < row.length; c++) {
            row[c] = flat[k++];
          }
        }
      }

      fill(g.hLines, ints(s['h']));
      fill(g.vLines, ints(s['v']));
      fill(g.boxes, ints(s['b']));
      g.turn = asInt(s['turn']);
      final l = s['last'] as List?;
      g.lastLine = l == null ? null : (l[0] as bool, asInt(l[1]), asInt(l[2]));
    },
    apply: (g, from, name, a) {
      if (name == 'line' && from == g.turn) g.drawLine(horizontal: a[0] == true, row: asInt(a[1]), col: asInt(a[2]));
    },
    view: (context, g, players, me) => _DotsTable(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<DotsBoxesLogic>(
    create: () => DotsBoxesLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _DotsTable(players: players, g: g),
  ),
);

class _DotsTable extends StatelessWidget {
  final List<GpPlayer> players;
  final DotsBoxesLogic g;
  const _DotsTable({required this.players, required this.g});

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    final scores = g.scores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 6),
          Expanded(
            child: Text(g.finished ? 'BOARD COMPLETE!' : '${current.whose} LINE',
                textAlign: TextAlign.center, style: TextStyle(color: g.finished ? Colors.white : current.color, fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          const SizedBox(width: 44),
        ]),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          for (var i = 0; i < players.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: i == g.turn ? players[i].color : Colors.white10, borderRadius: BorderRadius.circular(14), border: Border.all(color: players[i].color, width: 2)),
              child: Text('${players[i].name} · ${scores[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final pad = w * 0.06;
                final cell = (w - 2 * pad) / g.size;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final u = (d.localPosition.dx - pad) / cell, v = (d.localPosition.dy - pad) / cell;
                    final dh = (v - v.round()).abs(), dv = (u - u.round()).abs();
                    final res = dh < dv ? g.drawLine(horizontal: true, row: v.round(), col: u.floor()) : g.drawLine(horizontal: false, row: v.floor(), col: u.round());
                    if (res != null) (res > 0 ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick()).ignore();
                  },
                  child: CustomPaint(size: Size(w, w), painter: _DotsPainter(g, players, pad, cell)),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('${g.totalLines - g.drawn} lines left', style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final DotsBoxesLogic g;
  final List<GpPlayer> players;
  final double pad, cell;
  _DotsPainter(this.g, this.players, this.pad, this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    Offset dot(int r, int c) => Offset(pad + c * cell, pad + r * cell);
    // Claimed boxes.
    for (var r = 0; r < g.size; r++) {
      for (var c = 0; c < g.size; c++) {
        final o = g.boxes[r][c];
        if (o < 0) continue;
        final rect = Rect.fromPoints(dot(r, c), dot(r + 1, c + 1)).deflate(cell * 0.08);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.12)), Paint()..color = players[o].color.withValues(alpha: 0.75));
        final tp = TextPainter(
          text: TextSpan(text: players[o].name.characters.first.toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: cell * 0.42)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // Empty lines as faint guides, drawn lines in the player's colour.
    void line(Offset a, Offset b, int owner, bool last) {
      if (owner < 0) {
        canvas.drawLine(a, b, Paint()
          ..color = Colors.white12
          ..strokeWidth = cell * 0.06
          ..strokeCap = StrokeCap.round);
        return;
      }
      if (last) {
        canvas.drawLine(a, b, Paint()
          ..color = Colors.white
          ..strokeWidth = cell * 0.17
          ..strokeCap = StrokeCap.round);
      }
      canvas.drawLine(a, b, Paint()
        ..color = players[owner].color
        ..strokeWidth = cell * 0.11
        ..strokeCap = StrokeCap.round);
    }

    for (var r = 0; r <= g.size; r++) {
      for (var c = 0; c < g.size; c++) {
        line(dot(r, c), dot(r, c + 1), g.hLines[r][c], g.lastLine == (true, r, c));
      }
    }
    for (var r = 0; r < g.size; r++) {
      for (var c = 0; c <= g.size; c++) {
        line(dot(r, c), dot(r + 1, c), g.vLines[r][c], g.lastLine == (false, r, c));
      }
    }
    for (var r = 0; r <= g.size; r++) {
      for (var c = 0; c <= g.size; c++) {
        canvas.drawCircle(dot(r, c), cell * 0.09, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
