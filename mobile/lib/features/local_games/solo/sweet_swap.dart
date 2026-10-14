import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../shell/level_progress.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Original match-3. Swap neighbours, clear lines of three or more, then pieces fall.
/// Four in a line also clears that whole row or column.
class SweetLogic extends SoloLogic {
  static const side = 7;
  static const colors = 5;
  final Random rng;
  int level;
  late List<int> cells;
  int movesLeft = 0;
  int target = 0;
  int? selected;
  bool cleared = false;
  bool failed = false;

  SweetLogic({Random? random, this.level = 1}) : rng = random ?? Random() {
    target = const [400, 700, 1100][level - 1];
    movesLeft = const [22, 18, 15][level - 1];
    cells = List.filled(side * side, 0);
    _fill();
    for (var guard = 0; guard < 40 && _anyMatch(); guard++) {
      _clearMatches(scoreIt: false);
      _fall();
    }
  }

  void setLevel(int n) {
    if (over || score > 0) return;
    level = n.clamp(1, 3);
    target = const [400, 700, 1100][level - 1];
    movesLeft = const [22, 18, 15][level - 1];
    selected = null;
    cleared = false;
    failed = false;
    cells = List.filled(side * side, 0);
    _fill();
    for (var guard = 0; guard < 40 && _anyMatch(); guard++) {
      _clearMatches(scoreIt: false);
      _fall();
    }
    notifyListeners();
  }

  void _fill() {
    for (var i = 0; i < cells.length; i++) {
      cells[i] = rng.nextInt(colors);
    }
  }

  bool tap(int i) {
    if (over || cleared || i < 0 || i >= cells.length) return false;
    final s = selected;
    if (s == null) {
      selected = i;
      notifyListeners();
      return true;
    }
    if (s == i) {
      selected = null;
      notifyListeners();
      return true;
    }
    if (!_adjacent(s, i)) {
      selected = i;
      notifyListeners();
      return false;
    }
    _swap(s, i);
    if (!_anyMatch()) {
      _swap(s, i);
      selected = null;
      notifyListeners();
      return false;
    }
    movesLeft--;
    selected = null;
    _resolve();
    return true;
  }

  void _resolve() {
    var guard = 0;
    while (_anyMatch() && guard++ < 20) {
      _clearMatches(scoreIt: true);
      _fall();
    }
    if (score >= target) {
      cleared = true;
      LevelProgress.markCleared('sweet_swap', level);
      gameOver(700);
    } else if (movesLeft <= 0) {
      failed = true;
      gameOver(700);
    }
    notifyListeners();
  }

  bool _adjacent(int a, int b) {
    final ar = a ~/ side, ac = a % side, br = b ~/ side, bc = b % side;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  void _swap(int a, int b) {
    final t = cells[a];
    cells[a] = cells[b];
    cells[b] = t;
  }

  bool _anyMatch() => _runs().isNotEmpty;

  List<List<int>> _runs() {
    final runs = <List<int>>[];
    for (var r = 0; r < side; r++) {
      var c = 0;
      while (c < side) {
        final v = cells[r * side + c];
        var k = c + 1;
        while (k < side && cells[r * side + k] == v && v >= 0) {
          k++;
        }
        if (v >= 0 && k - c >= 3)
          runs.add([for (var i = c; i < k; i++) r * side + i]);
        c = k;
      }
    }
    for (var c = 0; c < side; c++) {
      var r = 0;
      while (r < side) {
        final v = cells[r * side + c];
        var k = r + 1;
        while (k < side && cells[k * side + c] == v && v >= 0) {
          k++;
        }
        if (v >= 0 && k - r >= 3)
          runs.add([for (var i = r; i < k; i++) i * side + c]);
        r = k;
      }
    }
    return runs;
  }

  void _clearMatches({required bool scoreIt}) {
    final hit = <int>{};
    for (final run in _runs()) {
      hit.addAll(run);
      if (scoreIt && run.length >= 4) {
        final horizontal = run[0] ~/ side == run[1] ~/ side;
        if (horizontal) {
          final r = run[0] ~/ side;
          for (var c = 0; c < side; c++) {
            hit.add(r * side + c);
          }
        } else {
          final c = run[0] % side;
          for (var r = 0; r < side; r++) {
            hit.add(r * side + c);
          }
        }
      }
    }
    if (scoreIt) score += hit.length * 10;
    for (final i in hit) {
      cells[i] = -1;
    }
  }

  void _fall() {
    for (var c = 0; c < side; c++) {
      var write = side - 1;
      for (var r = side - 1; r >= 0; r--) {
        final v = cells[r * side + c];
        if (v >= 0) {
          cells[write * side + c] = v;
          if (write != r) cells[r * side + c] = -1;
          write--;
        }
      }
      for (var r = write; r >= 0; r--) {
        cells[r * side + c] = rng.nextInt(colors);
      }
    }
  }
}

final sweetSwapInfo = LocalGameInfo(
  id: 'sweet_swap',
  title: 'Sweet Swap',
  emoji: '🍬',
  color: const Color(0xFFEC407A),
  tagline: 'Swap sweets. Match three.',
  rules: const [
    'Tap a sweet, then a neighbour, to swap them.',
    'Three or more of the same colour clear. Four in a line also clears that row or column.',
    'A swap that matches nothing snaps back and does not cost a move.',
    'Reach the score before you run out of moves. Three levels.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SweetLogic>(
    create: () => SweetLogic(),
    onFinished: onFinished,
    builder: (context, g) => _SweetView(g: g),
  ),
);

class _SweetView extends StatefulWidget {
  final SweetLogic g;
  const _SweetView({required this.g});
  @override
  State<_SweetView> createState() => _SweetViewState();
}

class _SweetViewState extends State<_SweetView> {
  int _open = 1;
  @override
  void initState() {
    super.initState();
    LevelProgress.unlocked('sweet_swap').then((n) {
      if (mounted) setState(() => _open = n.clamp(1, 3));
    });
  }

  static const _palette = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF8E24AA),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return SoloFrame(
      title: g.cleared
          ? 'Level clear'
          : (g.failed ? 'Out of moves' : 'Sweet Swap'),
      score: g.score,
      extra: 'Lv ${g.level} · ${g.movesLeft} moves · goal ${g.target}',
      child: Column(children: [
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: KitButton('Level $i',
                    style:
                        i <= _open ? KitButtonStyle.soft : KitButtonStyle.ghost,
                    onPressed: i <= _open && g.score == 0 && !g.over
                        ? () => g.setLevel(i)
                        : null),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: GridView.count(
              crossAxisCount: SweetLogic.side,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < g.cells.length; i++)
                  GestureDetector(
                    onTap: () => g.tap(i),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: g.cells[i] < 0
                            ? const Color(0xFF102027)
                            : _palette[g.cells[i]],
                        borderRadius: BorderRadius.circular(8),
                        border: g.selected == i
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
