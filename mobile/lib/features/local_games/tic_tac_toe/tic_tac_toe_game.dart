import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';

/// Classic noughts and crosses. Player 1 is X, player 2 is O; whoever starts
/// alternates every match. The winner scores 1, a full board is a draw (0-0).
class TicTacToeLogic extends LocalGameLogic {
  static const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6], // diagonals
  ];

  final List<int> cells = List.filled(9, -1); // -1 empty, else player index
  int turn;
  List<int>? winLine;
  int? winner;

  TicTacToeLogic({int starter = 0}) : turn = starter;

  bool get isDraw => winner == null && cells.every((c) => c >= 0);
  @override
  bool get finished => winner != null || isDraw;
  @override
  List<int> get scores => [for (var p = 0; p < 2; p++) winner == p ? 1 : 0];

  @override
  void update(int elapsedMs) {} // turn-based: nothing happens on its own

  /// Returns true if the move was accepted.
  bool play(int cell) {
    if (finished || cell < 0 || cell > 8 || cells[cell] >= 0) return false;
    cells[cell] = turn;
    for (final l in lines) {
      if (cells[l[0]] == turn && cells[l[1]] == turn && cells[l[2]] == turn) {
        winLine = l;
        winner = turn;
      }
    }
    if (!finished) turn = 1 - turn;
    notifyListeners();
    return true;
  }
}

var _matchesStarted = 0;

final ticTacToeInfo = LocalGameInfo(
  id: 'tic_tac_toe',
  title: 'Tic-Tac-Toe',
  emoji: '❌',
  color: const Color(0xFF00B8D9),
  tagline: 'Three in a row wins!',
  rules: const [
    'Player 1 is X, Player 2 is O. Take turns tapping an empty square.',
    'Get three of your marks in a row (across, down or diagonal) to win.',
    'A full board with no line is a draw. The starting player switches every match.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  play: (players, onFinished) => TickingPlay<TicTacToeLogic>(
    create: () => TicTacToeLogic(starter: _matchesStarted++ % 2),
    onFinished: onFinished,
    builder: (context, g) => _Board(players: players, g: g),
  ),
);

class _Board extends StatelessWidget {
  final List<GpPlayer> players;
  final TicTacToeLogic g;
  const _Board({required this.players, required this.g});

  static String mark(int p) => p == 0 ? 'X' : 'O';

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    final status = g.winner != null
        ? '${players[g.winner!].name.toUpperCase()} WINS!'
        : g.isDraw
            ? "IT'S A DRAW!"
            : "${current.name.toUpperCase()}'S TURN (${mark(g.turn)})";
    final statusColor = g.winner != null ? players[g.winner!].color : (g.isDraw ? Colors.white : current.color);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 4),
          for (var i = 0; i < 2; i++) ...[
            Expanded(child: _Who(player: players[i], mark: mark(i), active: !g.finished && g.turn == i)),
            if (i == 0) const SizedBox(width: 8),
          ],
        ]),
        const Spacer(),
        Text(status, textAlign: TextAlign.center, style: TextStyle(color: statusColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final side = c.maxWidth.clamp(0.0, 460.0);
          return SizedBox(
            width: side,
            height: side,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: GpColors.panel, borderRadius: BorderRadius.circular(28)),
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 9; i++)
                    _Cell(
                      owner: g.cells[i],
                      players: players,
                      highlight: g.winLine?.contains(i) ?? false,
                      onTap: () {
                        if (g.play(i)) HapticFeedback.selectionClick().ignore();
                      },
                    ),
                ],
              ),
            ),
          );
        }),
        const Spacer(flex: 2),
      ]),
    );
  }
}

class _Who extends StatelessWidget {
  final GpPlayer player;
  final String mark;
  final bool active;
  const _Who({required this.player, required this.mark, required this.active});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? player.color : player.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: player.color, width: 2),
        ),
        child: Row(children: [
          Expanded(
            child: Text(player.name.toUpperCase(),
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
          Text(mark, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
        ]),
      );
}

class _Cell extends StatelessWidget {
  final int owner;
  final List<GpPlayer> players;
  final bool highlight;
  final VoidCallback onTap;
  const _Cell({required this.owner, required this.players, required this.highlight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = owner < 0 ? 'Empty square' : '${owner == 0 ? 'X' : 'O'} square';
    return Semantics(
      button: owner < 0,
      label: label,
      child: Material(
        color: highlight ? GpColors.accent.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: owner < 0 ? onTap : null,
          child: owner < 0
              ? const SizedBox.expand()
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Center(
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(owner == 0 ? 'X' : 'O', style: TextStyle(color: players[owner].color, fontSize: 80, fontWeight: FontWeight.w900, height: 1)),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
