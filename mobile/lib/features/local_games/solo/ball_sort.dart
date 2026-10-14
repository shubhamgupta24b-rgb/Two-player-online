import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/level_progress.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const _ballColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFFFB8C00),
  Color(0xFF00ACC1),
  Color(0xFFEC407A),
  Color(0xFF6D4C41),
  Color(0xFF7CB342),
];

int _pourCount(List<List<int>> tubes, int from, int to) {
  if (from == to) return 0;
  final a = tubes[from], b = tubes[to];
  if (a.isEmpty || b.length >= BallSortLogic.capacity) return 0;
  if (b.isNotEmpty && b.last != a.last) return 0;
  var run = 1;
  while (run < a.length && a[a.length - 1 - run] == a.last) {
    run++;
  }
  return min(run, BallSortLogic.capacity - b.length);
}

/// A puzzle made by walking legal pours away from a solved board, so it always has a solution.
List<List<int>> dealSolvable(
    {required int colors, required int seed, int steps = 12}) {
  final rng = Random(seed);
  final tubes = <List<int>>[
    for (var c = 0; c < colors; c++)
      List<int>.filled(BallSortLogic.capacity, c, growable: true),
    <int>[],
    <int>[],
  ];
  for (var n = 0; n < steps; n++) {
    final moves = <(int, int)>[];
    for (var a = 0; a < tubes.length; a++) {
      for (var b = 0; b < tubes.length; b++) {
        if (_pourCount(tubes, a, b) > 0) moves.add((a, b));
      }
    }
    if (moves.isEmpty) break;
    final m = moves[rng.nextInt(moves.length)];
    final k = _pourCount(tubes, m.$1, m.$2);
    for (var i = 0; i < k; i++) {
      tubes[m.$2].add(tubes[m.$1].removeLast());
    }
  }
  final solved = tubes.every((t) =>
      t.isEmpty ||
      (t.length == BallSortLogic.capacity && t.every((b) => b == t.first)));
  if (solved) {
    final empty = tubes.indexWhere((t) => t.isEmpty);
    final full = tubes.indexWhere((t) => t.length == BallSortLogic.capacity);
    if (empty >= 0 && full >= 0) {
      tubes[empty].add(tubes[full].removeLast());
    }
  }
  return tubes;
}

/// Ball Sort: tubes of 4 coloured balls. Tap a tube, then another, to pour its top ball(s)
/// onto a matching colour or into an empty tube. Fill every tube with one colour to clear
/// the level. Each level adds a colour. Score = levels cleared.
class BallSortLogic extends SoloLogic {
  static const capacity = 4;
  static const levelsPerTier = 50;
  final Random rng;
  int level = 1;
  int difficulty = 0;
  bool _packed = false;
  int _packColors = 3;
  List<List<int>> tubes = [];
  final List<List<List<int>>> _history = [];
  int? selected;
  int moves = 0;
  int? clearedAt; // when the level was just cleared (for the celebration)

  BallSortLogic({Random? random}) : rng = random ?? Random() {
    _newLevel();
  }

  int get colors => _packed ? _packColors : min(3 + level, _ballColors.length);

  String get tierName =>
      const ['Easy', 'Medium', 'Hard'][difficulty.clamp(0, 2)];

  /// Loads one of the 50 puzzles in a difficulty. Each puzzle is solvable and not already solved.
  void usePack(int tier, int at) {
    difficulty = tier.clamp(0, 2);
    level = at.clamp(1, levelsPerTier);
    _packed = true;
    _packColors = switch (difficulty) {
      0 => 2 + (level - 1) ~/ 17,
      1 => 4 + (level - 1) ~/ 25,
      _ => 6 + (level - 1) ~/ 26,
    };
    _packColors = min(_packColors, _ballColors.length);
    final steps = switch (difficulty) {
      0 => 6 + level ~/ 4,
      1 => 16 + level ~/ 3,
      _ => 28 + level ~/ 2,
    };
    tubes = dealSolvable(
        colors: _packColors, seed: difficulty * 1000 + level, steps: steps);
    _history.clear();
    selected = null;
    moves = 0;
    clearedAt = null;
    notifyListeners();
  }

  void _newLevel() {
    final n = colors;
    // Deal 4 balls of each colour across n tubes, then 2 empty tubes; avoid starting solved.
    do {
      final balls = [
        for (var c = 0; c < n; c++)
          for (var i = 0; i < capacity; i++) c
      ]..shuffle(rng);
      tubes = [
        for (var t = 0; t < n; t++)
          balls.sublist(t * capacity, (t + 1) * capacity),
        <int>[],
        <int>[]
      ];
    } while (solved);
    _history.clear();
    selected = null;
    moves = 0;
  }

  bool get solved => tubes.every((t) =>
      t.isEmpty || (t.length == capacity && t.every((b) => b == t.first)));

  /// How many balls would pour from [from] to [to] (0 if that's not allowed).
  int pourable(int from, int to) {
    if (from == to) return 0;
    final a = tubes[from], b = tubes[to];
    if (a.isEmpty || b.length >= capacity) return 0;
    if (b.isNotEmpty && b.last != a.last) return 0;
    var run = 1;
    while (run < a.length && a[a.length - 1 - run] == a.last) {
      run++;
    }
    return min(run, capacity - b.length);
  }

  void tap(int tube) {
    if (over || clearedAt != null) return;
    final s = selected;
    if (s == null) {
      if (tubes[tube].isNotEmpty) selected = tube;
    } else if (s == tube) {
      selected = null;
    } else {
      final n = pourable(s, tube);
      if (n > 0) {
        _history.add([for (final t in tubes) List.of(t)]);
        for (var i = 0; i < n; i++) {
          tubes[tube].add(tubes[s].removeLast());
        }
        moves++;
        selected = null;
        HapticFeedback.selectionClick().ignore();
        if (solved) {
          score = level;
          clearedAt = now;
          HapticFeedback.mediumImpact().ignore();
        }
      } else {
        selected = tubes[tube].isNotEmpty ? tube : null;
      }
    }
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty || clearedAt != null) return;
    tubes = _history.removeLast();
    selected = null;
    moves = max(0, moves - 1);
    notifyListeners();
  }

  void restart() {
    if (clearedAt != null) return;
    if (_history.isNotEmpty) tubes = _history.first;
    _history.clear();
    selected = null;
    moves = 0;
    notifyListeners();
  }

  void finish() => gameOver(300);

  @override
  void step(int now) {
    final at = clearedAt;
    if (at != null && now - at > 1300) {
      clearedAt = null;
      if (_packed) {
        LevelProgress.markCleared('ball_sort_$difficulty', level);
        if (level < levelsPerTier) {
          usePack(difficulty, level + 1);
        } else {
          gameOver(300);
        }
      } else {
        level++;
        _newLevel();
      }
      notifyListeners();
    }
  }
}

final ballSortInfo = LocalGameInfo(
  id: 'ball_sort',
  title: 'Ball Sort',
  emoji: '🧪',
  color: const Color(0xFF26A69A),
  tagline: 'Pour the balls until every tube is one colour!',
  rules: const [
    'Tap a tube, then another tube, to pour the top ball onto the same colour or into an empty tube.',
    'Fill every tube with balls of a single colour to clear the level.',
    'Each level adds a colour. Stuck? Use UNDO or RESTART. Tap DONE to finish.',
  ],
  scoreUnit: 'levels',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<BallSortLogic>(
    create: () => BallSortLogic()..usePack(0, 1),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: g.clearedAt != null
          ? 'Level ${g.level} cleared!'
          : 'Level ${g.level}',
      score: g.score,
      extra: g._packed
          ? '${g.tierName} ${g.level}/${BallSortLogic.levelsPerTier} · ${g.moves} moves'
          : '${g.moves} moves · ${g.colors} colours',
      child: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final n = g.tubes.length;
            final perRow = n <= 6 ? n : (n / 2).ceil();
            final rows = (n / perRow).ceil();
            final tubeW = min((c.maxWidth - 12 * perRow) / perRow, 64.0);
            final tubeH = min(tubeW * 3.9, (c.maxHeight - 30 * rows) / rows);
            return Center(
              child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 30,
                  children: [
                    for (var t = 0; t < n; t++)
                      _Tube(g: g, index: t, width: tubeW, height: tubeH),
                  ]),
            );
          }),
        ),
        Row(children: [
          for (final (i, name) in const [
            (0, 'Easy'),
            (1, 'Medium'),
            (2, 'Hard')
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: KitButton(name,
                    style: g.difficulty == i && g._packed
                        ? KitButtonStyle.soft
                        : KitButtonStyle.ghost,
                    onPressed: () => g.usePack(i, 1)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: KitButton('Undo',
                  icon: GameIcons.undo,
                  style: KitButtonStyle.soft,
                  onPressed: g.undo)),
          const SizedBox(width: 8),
          Expanded(
              child: KitButton('Reset',
                  icon: GameIcons.restart,
                  style: KitButtonStyle.soft,
                  onPressed: g.restart)),
          const SizedBox(width: 8),
          Expanded(
              child: GoldButton('Done',
                  icon: GameIcons.flag,
                  height: 52,
                  fontSize: 18,
                  onPressed: g.finish)),
        ]),
      ]),
    ),
  ),
);

class _Tube extends StatelessWidget {
  final BallSortLogic g;
  final int index;
  final double width, height;
  const _Tube(
      {required this.g,
      required this.index,
      required this.width,
      required this.height});

  @override
  Widget build(BuildContext context) {
    final balls = g.tubes[index];
    final picked = g.selected == index;
    final done = balls.length == BallSortLogic.capacity &&
        balls.every((b) => b == balls.first);
    final d = width * 0.78;
    return Semantics(
      button: true,
      label: 'Tube ${index + 1}',
      child: GestureDetector(
        onTap: () => g.tap(index),
        child: ClipPath(
          clipper: const _HexClipper(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(0, picked ? -14 : 0, 0),
            width: width,
            height: height,
            padding: EdgeInsets.only(bottom: width * 0.1),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.06)
              ]),
              borderRadius: BorderRadius.circular(width * 0.22),
              border: Border.all(
                  color: done
                      ? StatusColors.success
                      : (picked ? Brand.gold : Colors.white54),
                  width: done || picked ? 3 : 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              for (var i = balls.length - 1; i >= 0; i--)
                Container(
                  width: d,
                  height: d,
                  margin: EdgeInsets.only(top: width * 0.06),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                        center: const Alignment(-0.35, -0.4),
                        colors: [
                          Color.lerp(_ballColors[balls[i]], Colors.white, 0.5)!,
                          _ballColors[balls[i]]
                        ]),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 2)
                    ],
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.22)
      ..lineTo(w, h * 0.78)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.78)
      ..lineTo(0, h * 0.22)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
