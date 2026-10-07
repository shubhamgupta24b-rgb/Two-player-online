import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Minesweeper on 9x9 with 10 mines. Your first tap is always safe (the mines are placed
/// after it). Numbers count neighbouring mines. Score: safe cells opened, plus a time
/// bonus for clearing the board.
class MinesweeperLogic extends SoloLogic {
  static const size = 9, mineCount = 10;
  final Random _rng;
  final Set<int> mines = {};
  final Set<int> open = {};
  final Set<int> flags = {};
  bool placed = false;
  bool won = false;
  int? exploded;
  int _startedAt = 0;

  MinesweeperLogic({Random? random, Set<int>? fixedMines}) : _rng = random ?? Random() {
    if (fixedMines != null) {
      mines.addAll(fixedMines);
      placed = true;
    }
  }

  static List<int> neighbours(int i) {
    final r = i ~/ size, c = i % size;
    return [
      for (var dr = -1; dr <= 1; dr++)
        for (var dc = -1; dc <= 1; dc++)
          if ((dr != 0 || dc != 0) && r + dr >= 0 && r + dr < size && c + dc >= 0 && c + dc < size) (r + dr) * size + c + dc,
    ];
  }

  int count(int i) => neighbours(i).where(mines.contains).length;
  int get seconds => placed ? ((now - _startedAt) / 1000).floor() : 0;
  int get minesLeft => (placed ? mines.length : mineCount) - flags.length;

  void _place(int safe) {
    final keepClear = {safe, ...neighbours(safe)};
    final cells = [for (var i = 0; i < size * size; i++) if (!keepClear.contains(i)) i]..shuffle(_rng);
    mines.addAll(cells.take(mineCount));
    placed = true;
    _startedAt = now;
  }

  void reveal(int i) {
    if (over || open.contains(i) || flags.contains(i)) return;
    if (!placed) _place(i);
    if (mines.contains(i)) {
      exploded = i;
      HapticFeedback.heavyImpact().ignore();
      gameOver(1800);
      return;
    }
    // Flood-fill the empty area.
    final todo = [i];
    while (todo.isNotEmpty) {
      final k = todo.removeLast();
      if (!open.add(k)) continue;
      flags.remove(k);
      if (count(k) == 0) todo.addAll(neighbours(k).where((x) => !open.contains(x) && !mines.contains(x)));
    }
    score = open.length;
    if (open.length == size * size - mines.length) {
      won = true;
      score = open.length + 100 + max(0, 300 - seconds);
      HapticFeedback.mediumImpact().ignore();
      gameOver(1800);
    }
    notifyListeners();
  }

  void toggleFlag(int i) {
    if (over || open.contains(i)) return;
    flags.contains(i) ? flags.remove(i) : flags.add(i);
    HapticFeedback.selectionClick().ignore();
    notifyListeners();
  }

  @override
  void step(int now) {
    if (placed) notifyListeners(); // the clock
  }
}

final minesweeperInfo = LocalGameInfo(
  id: 'minesweeper',
  title: 'Minesweeper',
  emoji: '💣',
  color: const Color(0xFF607D8B),
  tagline: 'Clear the field, dodge the mines!',
  rules: const [
    'Tap a square to dig. Your first tap is always safe.',
    'Numbers show how many mines touch that square.',
    'Long-press (or switch to Flag mode) to flag a mine. Clear every safe square to win!',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<MinesweeperLogic>(
    create: () => MinesweeperLogic(),
    onFinished: onFinished,
    builder: (context, g) => _MinesView(g: g),
  ),
);

class _MinesView extends StatefulWidget {
  final MinesweeperLogic g;
  const _MinesView({required this.g});
  @override
  State<_MinesView> createState() => _MinesViewState();
}

class _MinesViewState extends State<_MinesView> {
  bool _flagMode = false;
  static const _numColors = [Colors.transparent, Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFE53935), Color(0xFF3949AB), Color(0xFF8E24AA), Color(0xFF00897B), Color(0xFF212121), Color(0xFF757575)];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    const n = MinesweeperLogic.size;
    return SoloFrame(
      title: g.won ? 'Cleared!' : (g.exploded != null ? 'Boom!' : 'Minesweeper'),
      score: g.score,
      extra: '${g.minesLeft} flags left · ${g.seconds}s',
      child: Column(children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A752C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
                ),
                child: GridView.count(
                  crossAxisCount: n,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < n * n; i++) _cell(g, i),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Dig / Flag mode pill.
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: NeonPalette.overlay, borderRadius: Radii.rChip, border: Border.all(color: Colors.white24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final flag in [false, true])
              Semantics(
                button: true,
                selected: _flagMode == flag,
                label: flag ? 'Flag mode' : 'Dig mode',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => setState(() => _flagMode = flag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(color: _flagMode == flag ? Brand.gold : Colors.transparent, borderRadius: Radii.rChip),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      GameIcon(flag ? GameIcons.flag : GameIcons.hammer, size: 20, color: _flagMode == flag ? Brand.onGold : Colors.white),
                      const SizedBox(width: 6),
                      Text(flag ? 'Flag' : 'Dig', style: TextStyle(fontFamily: Fonts.display, fontSize: 18, color: _flagMode == flag ? Brand.onGold : Colors.white)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _cell(MinesweeperLogic g, int i) {
    final isOpen = g.open.contains(i);
    final showMine = g.mines.contains(i) && g.over;
    final flagged = g.flags.contains(i);
    final c = isOpen ? g.count(i) : 0;
    return GestureDetector(
      onTap: () => _flagMode ? g.toggleFlag(i) : g.reveal(i),
      onLongPress: () => g.toggleFlag(i),
      child: Container(
        alignment: Alignment.center,
        // Grass you dig into; sand once opened (checkered like a lawn).
        decoration: BoxDecoration(
          color: i == g.exploded
              ? Colors.redAccent
              : isOpen
                  ? ((i ~/ MinesweeperLogic.size + i) % 2 == 0 ? const Color(0xFFE5C29F) : const Color(0xFFD7B899))
                  : ((i ~/ MinesweeperLogic.size + i) % 2 == 0 ? const Color(0xFFA2D149) : const Color(0xFF8ECC39)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isOpen ? null : const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 2))],
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: showMine
                ? const GameIcon(GameIcons.bomb, size: 22)
                : flagged
                    ? const GameIcon(GameIcons.flag, size: 22, color: Color(0xFFE53935))
                    : Text(isOpen && c > 0 ? '$c' : '', style: TextStyle(fontFamily: Fonts.display, color: _numColors[c], fontSize: 22)),
          ),
        ),
      ),
    );
  }
}
