import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const _ballColors = [
  Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFDD835), Color(0xFF8E24AA),
  Color(0xFFFB8C00), Color(0xFF00ACC1), Color(0xFFEC407A), Color(0xFF6D4C41), Color(0xFF7CB342),
];

/// Ball Sort: tubes of 4 coloured balls. Tap a tube, then another, to pour its top ball(s)
/// onto a matching colour or into an empty tube. Fill every tube with one colour to clear
/// the level. Each level adds a colour. Score = levels cleared.
class BallSortLogic extends SoloLogic {
  static const capacity = 4;
  final Random rng;
  int level = 1;
  List<List<int>> tubes = [];
  final List<List<List<int>>> _history = [];
  int? selected;
  int moves = 0;
  int? clearedAt; // when the level was just cleared (for the celebration)

  BallSortLogic({Random? random}) : rng = random ?? Random() {
    _newLevel();
  }

  int get colors => min(3 + level, _ballColors.length);

  void _newLevel() {
    final n = colors;
    // Deal 4 balls of each colour across n tubes, then 2 empty tubes; avoid starting solved.
    do {
      final balls = [for (var c = 0; c < n; c++) for (var i = 0; i < capacity; i++) c]..shuffle(rng);
      tubes = [for (var t = 0; t < n; t++) balls.sublist(t * capacity, (t + 1) * capacity), <int>[], <int>[]];
    } while (solved);
    _history.clear();
    selected = null;
    moves = 0;
  }

  bool get solved => tubes.every((t) => t.isEmpty || (t.length == capacity && t.every((b) => b == t.first)));

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
      level++;
      _newLevel();
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
    create: () => BallSortLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: g.clearedAt != null ? 'Level ${g.level} cleared!' : 'Level ${g.level}',
      score: g.score,
      extra: '${g.moves} moves · ${g.colors} colours',
      child: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final n = g.tubes.length;
            final perRow = n <= 6 ? n : (n / 2).ceil();
            final rows = (n / perRow).ceil();
            final tubeW = min((c.maxWidth - 12 * perRow) / perRow, 64.0);
            final tubeH = min(tubeW * 3.9, (c.maxHeight - 30 * rows) / rows);
            return Center(
              child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 30, children: [
                for (var t = 0; t < n; t++) _Tube(g: g, index: t, width: tubeW, height: tubeH),
              ]),
            );
          }),
        ),
        Row(children: [
          Expanded(child: KitButton('Undo', icon: GameIcons.undo, style: KitButtonStyle.soft, onPressed: g.undo)),
          const SizedBox(width: 8),
          Expanded(child: KitButton('Reset', icon: GameIcons.restart, style: KitButtonStyle.soft, onPressed: g.restart)),
          const SizedBox(width: 8),
          Expanded(child: GoldButton('Done', icon: GameIcons.flag, height: 52, fontSize: 18, onPressed: g.finish)),
        ]),
      ]),
    ),
  ),
);

class _Tube extends StatelessWidget {
  final BallSortLogic g;
  final int index;
  final double width, height;
  const _Tube({required this.g, required this.index, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final balls = g.tubes[index];
    final picked = g.selected == index;
    final done = balls.length == BallSortLogic.capacity && balls.every((b) => b == balls.first);
    final d = width * 0.78;
    return Semantics(
      button: true,
      label: 'Tube ${index + 1}',
      child: GestureDetector(
        onTap: () => g.tap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, picked ? -14 : 0, 0),
          width: width,
          height: height,
          padding: EdgeInsets.only(bottom: width * 0.1),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.06)]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(width / 2), top: const Radius.circular(6)),
            border: Border.all(color: done ? StatusColors.success : (picked ? Brand.gold : Colors.white54), width: done || picked ? 3 : 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            for (var i = balls.length - 1; i >= 0; i--)
              Container(
                width: d,
                height: d,
                margin: EdgeInsets.only(top: width * 0.06),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(center: const Alignment(-0.35, -0.4), colors: [Color.lerp(_ballColors[balls[i]], Colors.white, 0.5)!, _ballColors[balls[i]]]),
                  boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 2)],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
