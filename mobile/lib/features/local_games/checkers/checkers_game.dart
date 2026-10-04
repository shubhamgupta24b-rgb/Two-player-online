import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';

/// A move: from square, the squares landed on, and the pieces jumped.
class CheckersMove {
  final int from;
  final List<int> path; // landing squares in order (one for a step, several for a multi-jump)
  final List<int> captured;
  const CheckersMove(this.from, this.path, this.captured);
  int get to => path.last;
}

/// Checkers (English draughts) on 8x8. Player 1 (index 0) starts at the bottom and moves up.
/// Pieces move diagonally forward; kings (reaching the far row) move both ways. Capturing is
/// compulsory and a capture continues for as long as it can. Take every piece, or leave your
/// rival without a move, to win. 80 moves without a capture is a draw.
class CheckersLogic extends LocalGameLogic {
  static const size = 8;
  static const drawAfter = 80;

  /// board[square] = 0 empty, 1/2 player 1/2 man, 3/4 player 1/2 king.
  final List<int> board = List.filled(size * size, 0);
  int turn = 0;
  int? selected;
  int quietMoves = 0;
  bool draw = false;
  (int, int)? lastMove;

  CheckersLogic() {
    for (var sq = 0; sq < 64; sq++) {
      final r = sq ~/ 8, c = sq % 8;
      if ((r + c).isOdd) {
        if (r <= 2) board[sq] = 2; // player 2 at the top
        if (r >= 5) board[sq] = 1; // player 1 at the bottom
      }
    }
  }

  static int ownerOf(int piece) => piece == 0 ? -1 : (piece == 1 || piece == 3 ? 0 : 1);
  static bool isKing(int piece) => piece >= 3;
  int pieces(int player) => board.where((x) => ownerOf(x) == player).length;

  List<(int, int)> _dirs(int piece) {
    if (isKing(piece)) return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
    return ownerOf(piece) == 0 ? const [(-1, -1), (-1, 1)] : const [(1, -1), (1, 1)];
  }

  bool _on(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  /// Every multi-jump from [sq] for [piece], given the pieces already [taken].
  List<CheckersMove> _jumps(int start, int sq, int piece, List<int> path, List<int> taken) {
    final out = <CheckersMove>[];
    final r = sq ~/ 8, c = sq % 8;
    for (final (dr, dc) in _dirs(piece)) {
      final mr = r + dr, mc = c + dc, lr = r + 2 * dr, lc = c + 2 * dc;
      if (!_on(lr, lc)) continue;
      final mid = mr * 8 + mc, land = lr * 8 + lc;
      final midPiece = board[mid];
      if (ownerOf(midPiece) != 1 - ownerOf(piece) || taken.contains(mid)) continue;
      if (board[land] != 0 && land != start) continue;
      final nextPath = [...path, land], nextTaken = [...taken, mid];
      // A man that reaches the far row is crowned and the move ends there.
      final crowned = !isKing(piece) && (lr == 0 || lr == 7);
      final more = crowned ? const <CheckersMove>[] : _jumps(start, land, piece, nextPath, nextTaken);
      out.addAll(more.isEmpty ? [CheckersMove(start, nextPath, nextTaken)] : more);
    }
    return out;
  }

  /// Legal moves for [player]. Captures are compulsory.
  List<CheckersMove> movesFor(int player) {
    final jumps = <CheckersMove>[], steps = <CheckersMove>[];
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (ownerOf(p) != player) continue;
      jumps.addAll(_jumps(sq, sq, p, const [], const []));
      final r = sq ~/ 8, c = sq % 8;
      for (final (dr, dc) in _dirs(p)) {
        if (_on(r + dr, c + dc) && board[(r + dr) * 8 + c + dc] == 0) steps.add(CheckersMove(sq, [(r + dr) * 8 + c + dc], const []));
      }
    }
    return jumps.isNotEmpty ? jumps : steps;
  }

  List<CheckersMove> get legal => movesFor(turn);

  @override
  bool get finished => draw || legal.isEmpty;
  int? get winner => draw || !finished ? null : 1 - turn; // whoever can't move loses
  @override
  List<int> get scores => [for (var p = 0; p < 2; p++) winner == p ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// Taps a square: picks one of your pieces, or moves the picked piece there.
  void tap(int sq) {
    if (forward('tap', [sq])) return;
    if (finished) return;
    final moves = legal;
    if (ownerOf(board[sq]) == turn && moves.any((m) => m.from == sq)) {
      selected = sq;
      notifyListeners();
      return;
    }
    final s = selected;
    if (s == null) return;
    final options = moves.where((m) => m.from == s && m.to == sq).toList();
    if (options.isEmpty) return;
    // Two different jump routes to the same square: take the one that captures most.
    options.sort((a, b) => b.captured.length - a.captured.length);
    play(options.first);
  }

  void play(CheckersMove m) {
    var piece = board[m.from];
    board[m.from] = 0;
    for (final c in m.captured) {
      board[c] = 0;
    }
    final row = m.to ~/ 8;
    if (!isKing(piece) && ((ownerOf(piece) == 0 && row == 0) || (ownerOf(piece) == 1 && row == 7))) piece += 2;
    board[m.to] = piece;
    quietMoves = m.captured.isEmpty ? quietMoves + 1 : 0;
    if (quietMoves >= drawAfter) draw = true;
    lastMove = (m.from, m.to);
    selected = null;
    turn = 1 - turn;
    notifyListeners();
  }
}

/// The computer: biggest capture, crowning, then safe moves forward; a little randomness.
CheckersMove checkersBotPick(CheckersLogic g, Random rng) {
  final moves = g.legal;
  double value(CheckersMove m) {
    var v = m.captured.length * 10.0 + rng.nextDouble();
    final piece = g.board[m.from];
    final row = m.to ~/ 8;
    if (!CheckersLogic.isKing(piece) && (row == 0 || row == 7)) v += 6;
    // Would the piece be jumped right away? (rough look at its new neighbours)
    final r = row, c = m.to % 8;
    for (final (dr, dc) in const [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
      final ar = r + dr, ac = c + dc, br = r - dr, bc = c - dc;
      if (ar < 0 || ar > 7 || ac < 0 || ac > 7 || br < 0 || br > 7 || bc < 0 || bc > 7) continue;
      final attacker = g.board[ar * 8 + ac];
      final behind = br * 8 + bc;
      if (CheckersLogic.ownerOf(attacker) == 1 - g.turn && (g.board[behind] == 0 || behind == m.from)) v -= 5;
    }
    if (c == 0 || c == 7) v += 1; // edges are safe
    return v;
  }

  return moves.reduce((a, b) => value(a) >= value(b) ? a : b);
}

final checkersInfo = LocalGameInfo(
  id: 'checkers',
  title: 'Checkers',
  emoji: '⚫',
  color: const Color(0xFFB71C1C),
  tagline: 'Jump, capture, crown your king!',
  rules: const [
    'Move a piece one square diagonally forward. Tap a piece, then where it goes.',
    'Jump over a rival piece to capture it. Captures are compulsory and keep going if they can.',
    'Reach the far side to become a king 👑, which moves backwards too.',
    'Take every rival piece (or leave them with no move) to win. Sit at opposite ends of the phone.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<CheckersLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst((g.turn, g.lastMove), now, 700, 1500)) return;
    g.play(checkersBotPick(g, b.rng));
  }),
  online: RelaySpec<CheckersLogic>(
    create: (n) => CheckersLogic(),
    save: (g) => {
      'board': g.board,
      'turn': g.turn,
      'sel': g.selected,
      'quiet': g.quietMoves,
      'draw': g.draw,
      'last': g.lastMove == null ? null : [g.lastMove!.$1, g.lastMove!.$2],
    },
    load: (g, s, me) {
      g.board.setAll(0, ints(s['board']));
      g.turn = asInt(s['turn']);
      g.quietMoves = asInt(s['quiet']);
      g.draw = s['draw'] == true;
      final last = s['last'] == null ? null : ints(s['last']);
      g.lastMove = last == null ? null : (last[0], last[1]);
      g.selected = g.turn == me ? nInt(s['sel']) : null; // a picked piece is only shown to its player
    },
    apply: (g, from, name, a) {
      if (name == 'tap' && from == g.turn) g.tap(asInt(a[0]));
    },
    view: (context, g, players, me) => _CheckersTable(g: g, players: players, flipped: me == 1),
  ),
  play: (players, onFinished) => TickingPlay<CheckersLogic>(
    create: () => CheckersLogic(),
    onFinished: onFinished,
    builder: (context, g) => _CheckersTable(g: g, players: players),
  ),
);

class _CheckersTable extends StatelessWidget {
  final CheckersLogic g;
  final List<GpPlayer> players;
  final bool flipped; // online player 2 sees their own pieces at the bottom
  const _CheckersTable({required this.g, required this.players, this.flipped = false});

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    final status = g.draw
        ? '🤝 DRAW: 80 moves without a capture'
        : g.finished
            ? '🏆 ${players[g.winner!].name.toUpperCase()} WINS!'
            : g.legal.first.captured.isNotEmpty
                ? '${current.whose} TURN: YOU MUST CAPTURE!'
                : '${current.whose} TURN';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var p = 0; p < 2; p++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: p == g.turn && !g.finished ? players[p].color : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: players[p].color, width: 2),
                  ),
                  child: Text('${players[p].name} · ${g.pieces(p)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        // Player 2's view of whose turn it is, upside down for the far side of the phone.
        if (!flipped) RotatedBox(quarterTurns: 2, child: _Status(text: status, color: current.color)),
        const SizedBox(height: 6),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _Board(g: g, players: players, flipped: flipped)))),
        const SizedBox(height: 6),
        _Status(text: status, color: current.color),
      ]),
    );
  }
}

class _Status extends StatelessWidget {
  final String text;
  final Color color;
  const _Status({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16));
}

class _Board extends StatelessWidget {
  final CheckersLogic g;
  final List<GpPlayer> players;
  final bool flipped;
  const _Board({required this.g, required this.players, required this.flipped});

  @override
  Widget build(BuildContext context) {
    final legal = g.finished ? const <CheckersMove>[] : g.legal;
    final movable = {for (final m in legal) m.from};
    final targets = g.selected == null ? const <int>{} : {for (final m in legal) if (m.from == g.selected) m.to};
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: const Color(0xFF4E342E), borderRadius: BorderRadius.circular(12)),
      child: GridView.count(
        crossAxisCount: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 64; i++)
            Builder(builder: (context) {
              final sq = flipped ? 63 - i : i;
              final dark = (sq ~/ 8 + sq % 8).isOdd;
              final piece = g.board[sq];
              final owner = CheckersLogic.ownerOf(piece);
              final isLast = g.lastMove != null && (g.lastMove!.$1 == sq || g.lastMove!.$2 == sq);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick().ignore();
                  g.tap(sq);
                },
                child: Container(
                  color: dark ? (isLast ? const Color(0xFF8D6E63) : const Color(0xFF6D4C41)) : const Color(0xFFF3E0C0),
                  child: Stack(alignment: Alignment.center, children: [
                    if (targets.contains(sq))
                      FractionallySizedBox(
                        widthFactor: 0.35,
                        heightFactor: 0.35,
                        child: Container(decoration: const BoxDecoration(color: Color(0xCCFFC93C), shape: BoxShape.circle)),
                      ),
                    if (piece != 0)
                      FractionallySizedBox(
                        widthFactor: 0.8,
                        heightFactor: 0.8,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.3),
                              colors: [Color.lerp(players[owner].color, Colors.white, 0.35)!, players[owner].color, Color.lerp(players[owner].color, Colors.black, 0.35)!],
                            ),
                            border: Border.all(
                              color: g.selected == sq ? GpColors.accent : (movable.contains(sq) && owner == g.turn ? Colors.white : Colors.black26),
                              width: g.selected == sq ? 4 : 2,
                            ),
                            boxShadow: const [BoxShadow(color: Colors.black38, offset: Offset(0, 2), blurRadius: 2)],
                          ),
                          alignment: Alignment.center,
                          child: CheckersLogic.isKing(piece) ? const FittedBox(child: Padding(padding: EdgeInsets.all(4), child: Text('👑', style: TextStyle(fontSize: 22)))) : null,
                        ),
                      ),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}
