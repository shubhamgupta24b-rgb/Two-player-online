import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';

class MemoryCard {
  final int id;
  final String symbol;
  int? matchedBy; // player index once matched
  MemoryCard(this.id, this.symbol);
  bool get matched => matchedBy != null;
}

/// Same rules as the online version: 12 pairs, a match scores and you go again,
/// a miss is shown briefly and the turn passes.
class MemoryLogic extends LocalGameLogic {
  static const symbols = ['🍎', '🍌', '🍇', '🍉', '🍓', '🥝', '🍒', '🥭', '🍑', '🍍', '🥥', '🍋'];
  final int mismatchMs;
  final List<MemoryCard> cards;
  final List<int> pairs;
  final List<int> picks = [];
  int turn = 0;
  int _now = 0;
  int? _mismatchUntil;

  MemoryLogic({int pairCount = 12, this.mismatchMs = 900, int players = 2, Random? random})
      : pairs = List.filled(players, 0),
        cards = _deal(pairCount, random ?? Random());

  static List<MemoryCard> _deal(int n, Random r) {
    final values = [...symbols.take(n), ...symbols.take(n)]..shuffle(r);
    return [for (var i = 0; i < values.length; i++) MemoryCard(i, values[i])];
  }

  @override
  List<int> get scores => pairs;
  @override
  bool get finished => cards.every((c) => c.matched);
  bool get showingMismatch => _mismatchUntil != null;
  bool isFaceUp(MemoryCard c) => c.matched || picks.contains(c.id);

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final until = _mismatchUntil;
    if (until != null && _now >= until) {
      picks.clear();
      _mismatchUntil = null;
      turn = (turn + 1) % pairs.length;
      notifyListeners();
    }
  }

  /// Returns true if the flip was accepted.
  bool flip(int id) {
    if (finished || showingMismatch || id < 0 || id >= cards.length) return false;
    final card = cards[id];
    if (card.matched || picks.contains(id)) return false;
    picks.add(id);
    if (picks.length == 2) {
      final a = cards[picks[0]], b = cards[picks[1]];
      if (a.symbol == b.symbol) {
        a.matchedBy = b.matchedBy = turn;
        pairs[turn]++;
        picks.clear(); // same player goes again
      } else {
        _mismatchUntil = _now + mismatchMs;
      }
    }
    notifyListeners();
    return true;
  }
}

final memoryInfo = LocalGameInfo(
  id: 'memory',
  title: 'Memory',
  emoji: '🧠',
  color: const Color(0xFFA29BFE),
  tagline: 'Find the pairs, remember everything!',
  rules: const [
    'Take turns flipping two cards.',
    'Find a matching pair to score a point and go again.',
    'No match? The cards flip back and it\'s the other player\'s turn.',
    'Most pairs when the board is clear wins.',
  ],
  scoreUnit: 'pairs',
  splitScreen: false,
  play: (players, onFinished) => TickingPlay<MemoryLogic>(
    create: () => MemoryLogic(),
    onFinished: onFinished,
    builder: (context, g) => _MemoryBoard(players: players, g: g),
  ),
);

class _MemoryBoard extends StatelessWidget {
  final List<GpPlayer> players;
  final MemoryLogic g;
  const _MemoryBoard({required this.players, required this.g});

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 4),
          for (var i = 0; i < players.length; i++) ...[
            Expanded(child: _ScorePill(player: players[i], pairs: g.pairs[i], active: g.turn == i && !g.finished)),
            if (i < players.length - 1) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            g.finished ? 'BOARD CLEAR!' : (g.showingMismatch ? 'NO MATCH…' : "${current.name.toUpperCase()}'S TURN"),
            key: ValueKey('${g.turn}${g.showingMismatch}${g.finished}'),
            style: TextStyle(color: g.showingMismatch ? Colors.white70 : current.color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            // 4 columns x 6 rows on phones; 6 x 4 when the space is wide.
            final cols = c.maxWidth > c.maxHeight ? 6 : 4;
            final rows = (g.cards.length / cols).ceil();
            const gap = 8.0;
            final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
            final cellH = (c.maxHeight - gap * (rows - 1)) / rows;
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                childAspectRatio: (cellW / cellH).clamp(0.5, 1.5),
              ),
              itemCount: g.cards.length,
              itemBuilder: (_, i) {
                final card = g.cards[i];
                return _FlipCard(
                  key: ValueKey(card.id),
                  faceUp: g.isFaceUp(card),
                  symbol: card.symbol,
                  ownerColor: card.matched ? players[card.matchedBy!].color : null,
                  onTap: () {
                    if (g.flip(card.id)) HapticFeedback.selectionClick().ignore();
                  },
                );
              },
            );
          }),
        ),
      ]),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final GpPlayer player;
  final int pairs;
  final bool active;
  const _ScorePill({required this.player, required this.pairs, required this.active});
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
          Text('$pairs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
        ]),
      );
}

/// Card that flips around its vertical axis.
class _FlipCard extends StatelessWidget {
  final bool faceUp;
  final String symbol;
  final Color? ownerColor;
  final VoidCallback onTap;
  const _FlipCard({super.key, required this.faceUp, required this.symbol, required this.ownerColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !faceUp,
      label: faceUp ? 'Card $symbol' : 'Hidden card',
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: faceUp ? 1 : 0),
          duration: const Duration(milliseconds: 260),
          builder: (_, t, __) {
            final showFace = t >= 0.5;
            final angle = t * pi;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(showFace ? angle - pi : angle),
              child: showFace ? _face() : _back(),
            );
          },
        ),
      ),
    );
  }

  Widget _back() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 4)],
        ),
        alignment: Alignment.center,
        child: const Text('?', style: TextStyle(color: Colors.white70, fontSize: 30, fontWeight: FontWeight.w900)),
      );

  Widget _face() => Container(
        decoration: BoxDecoration(
          color: GpColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ownerColor ?? GpColors.accent, width: 3),
        ),
        alignment: Alignment.center,
        child: Opacity(opacity: ownerColor != null ? 0.75 : 1, child: FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: Text(symbol, style: const TextStyle(fontSize: 40))))),
      );
}
