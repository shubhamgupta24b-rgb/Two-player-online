import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';

/// Classic Connect Four on a 7x6 board. Discs drop to the lowest free row; four in a
/// row (across, down or diagonal) wins. The starting player alternates every match.
class ConnectFourLogic extends LocalGameLogic {
  static const cols = 7, rows = 6;
  final List<int> cells = List.filled(cols * rows, -1); // row 0 is the top
  int turn;
  int? winner;
  List<int>? winCells;
  int? lastDrop;

  ConnectFourLogic({int starter = 0}) : turn = starter;

  int at(int c, int r) => cells[r * cols + c];
  bool get isDraw => winner == null && cells.every((x) => x >= 0);
  @override
  bool get finished => winner != null || isDraw;
  @override
  List<int> get scores => [for (var p = 0; p < 2; p++) winner == p ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// Drops a disc in [col]. Returns the row it landed on, or null if not allowed.
  int? drop(int col) {
    if (forward('drop', [col])) return null;
    if (finished || col < 0 || col >= cols) return null;
    for (var r = rows - 1; r >= 0; r--) {
      if (at(col, r) < 0) {
        cells[r * cols + col] = turn;
        lastDrop = r * cols + col;
        _checkWin(col, r);
        if (!finished) turn = 1 - turn;
        notifyListeners();
        return r;
      }
    }
    return null; // column full
  }

  void _checkWin(int c, int r) {
    const dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];
    for (final (dc, dr) in dirs) {
      final line = [r * cols + c];
      for (final sign in [1, -1]) {
        var x = c + dc * sign, y = r + dr * sign;
        while (x >= 0 && x < cols && y >= 0 && y < rows && at(x, y) == turn) {
          line.add(y * cols + x);
          x += dc * sign;
          y += dr * sign;
        }
      }
      if (line.length >= 4) {
        winner = turn;
        winCells = line;
        return;
      }
    }
  }
}

var _matchesStarted = 0;

final connectFourInfo = LocalGameInfo(
  id: 'connect_four',
  title: 'Connect Four',
  emoji: '🔴',
  color: const Color(0xFFE5484D),
  tagline: 'Line up four to win!',
  rules: const [
    'Take turns tapping a column to drop your disc.',
    'Get four of your discs in a row: across, down or diagonal.',
    'Full board with no line is a draw. The starting player switches every match.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<ConnectFourLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.cells.where((c) => c >= 0).length, now, 600, 1300)) return;
    const cols = ConnectFourLogic.cols, rows = ConnectFourLogic.rows;
    int? landing(int c) {
      for (var r = rows - 1; r >= 0; r--) {
        if (g.at(c, r) < 0) return r;
      }
      return null;
    }

    bool wins(int c, int who) {
      final r = landing(c);
      if (r == null) return false;
      int at(int x, int y) => x == c && y == r ? who : g.at(x, y);
      for (final (dc, dr) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
        var n = 1;
        for (final s in const [1, -1]) {
          var x = c + dc * s, y = r + dr * s;
          while (x >= 0 && x < cols && y >= 0 && y < rows && at(x, y) == who) {
            n++;
            x += dc * s;
            y += dr * s;
          }
        }
        if (n >= 4) return true;
      }
      return false;
    }

    final open = [for (var c = 0; c < cols; c++) if (landing(c) != null) c];
    final opp = 1 - b.seat;
    // Win, else block, else favour the middle (with a little randomness).
    final int col = open.where((c) => wins(c, b.seat)).firstOrNull ??
        open.where((c) => wins(c, opp)).firstOrNull ??
        (b.chance(0.2) ? b.pick<int>(open) : (open.toList()..sort((a, c) => (a - 3).abs().compareTo((c - 3).abs()))).first);
    g.drop(col);
  }),
  online: RelaySpec<ConnectFourLogic>(
    create: (n) => ConnectFourLogic(),
    save: (g) => {'cells': g.cells, 'turn': g.turn, 'winner': g.winner, 'winCells': g.winCells, 'lastDrop': g.lastDrop},
    load: (g, s, me) {
      g.cells.setAll(0, ints(s['cells']));
      g.turn = asInt(s['turn']);
      g.winner = nInt(s['winner']);
      g.winCells = s['winCells'] == null ? null : ints(s['winCells']);
      g.lastDrop = nInt(s['lastDrop']);
    },
    apply: (g, from, name, a) {
      if (name == 'drop' && from == g.turn) g.drop(asInt(a[0]));
    },
    view: (context, g, players, me) => _Board(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<ConnectFourLogic>(
    create: () => ConnectFourLogic(starter: _matchesStarted++ % 2),
    onFinished: onFinished,
    builder: (context, g) => _Board(players: players, g: g),
  ),
);

class _Board extends StatelessWidget {
  final List<GpPlayer> players;
  final ConnectFourLogic g;
  const _Board({required this.players, required this.g});

  /// The row a disc dropped in column [c] would land on, or null if the column is full.
  int? _landing(int c) {
    for (var r = ConnectFourLogic.rows - 1; r >= 0; r--) {
      if (g.at(c, r) < 0) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    final status = g.winner != null
        ? '${players[g.winner!].name.toUpperCase()} WINS!'
        : g.isDraw
            ? "IT'S A DRAW!"
            : '${current.whose} TURN';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 6),
          Expanded(
            child: Text(status,
                textAlign: TextAlign.center,
                style: TextStyle(color: g.winner != null ? players[g.winner!].color : (g.isDraw ? Colors.white : current.color), fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 44),
        ]),
        const SizedBox(height: 12),
        // Drop arrows in the colour of whoever's turn it is.
        if (!g.finished)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (var c = 0; c < ConnectFourLogic.cols; c++)
                Expanded(child: Icon(Icons.arrow_drop_down_rounded, size: 34, color: _landing(c) == null ? Colors.white12 : current.color)),
            ]),
          ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: ConnectFourLogic.cols / (ConnectFourLogic.rows + 0.4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF2E5BDB), borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 6))]),
                child: Row(children: [
                  for (var c = 0; c < ConnectFourLogic.cols; c++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Column ${c + 1}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (g.drop(c) != null) HapticFeedback.selectionClick().ignore();
                          },
                          child: Column(children: [
                            for (var r = 0; r < ConnectFourLogic.rows; r++)
                              Expanded(
                                child: _Hole(
                                  owner: g.at(c, r),
                                  players: players,
                                  win: g.winCells?.contains(r * ConnectFourLogic.cols + c) ?? false,
                                  fresh: g.lastDrop == r * ConnectFourLogic.cols + c,
                                  ghost: !g.finished && _landing(c) == r ? current.color : null,
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 24, runSpacing: 6, children: [
          for (var i = 0; i < 2; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 9, backgroundColor: players[i].color),
              const SizedBox(width: 6),
              Text(players[i].name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
        ]),
      ]),
    );
  }
}

class _Hole extends StatelessWidget {
  final int owner;
  final List<GpPlayer> players;
  final bool win;
  final bool fresh;
  final Color? ghost; // where the current player's disc would land
  const _Hole({required this.owner, required this.players, required this.win, required this.fresh, this.ghost});

  @override
  Widget build(BuildContext context) {
    final c = owner < 0 ? null : players[owner].color;
    final disc = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c == null ? (ghost?.withValues(alpha: 0.22) ?? GpColors.bgBottom) : null,
        // Discs get a shine so they look like plastic counters.
        gradient: c == null ? null : RadialGradient(center: const Alignment(-0.3, -0.35), colors: [Color.lerp(c, Colors.white, 0.4)!, c, Color.lerp(c, Colors.black, 0.25)!]),
        border: win
            ? Border.all(color: Colors.white, width: 4)
            : (ghost != null && c == null ? Border.all(color: ghost!.withValues(alpha: 0.7), width: 2) : null),
        boxShadow: c == null ? const [BoxShadow(color: Colors.black54, offset: Offset(0, -2), blurRadius: 2, spreadRadius: -1)] : null,
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: fresh
            ? TweenAnimationBuilder<double>(
                key: ValueKey(owner),
                tween: Tween(begin: -3, end: 0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.bounceOut,
                builder: (_, y, child) => FractionalTranslation(translation: Offset(0, y), child: child),
                child: disc,
              )
            : disc,
      ),
    );
  }
}
