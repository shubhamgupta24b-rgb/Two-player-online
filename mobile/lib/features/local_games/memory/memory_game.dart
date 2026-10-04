import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/app_flavor.dart';
import '../../guess_person/data/person_data.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/models/person.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../../guess_person/widgets/person_portrait.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
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
    'No match? The cards flip back and it\'s the next player\'s turn.',
    'Most pairs when the board is clear wins. 2 to 6 players.',
  ],
  scoreUnit: 'pairs',
  splitScreen: false,
  maxPlayers: 6,
  bot: botFor<MemoryLogic>((g, b, now) {
    // Watch every flip (anyone's), remembering about three out of four cards.
    final seen = (b.memory['seen'] ??= <int, String>{}) as Map<int, String>;
    final judged = (b.memory['judged'] ??= <int>{}) as Set<int>;
    for (final id in g.picks) {
      if (judged.add(id * 1000 + g.pairs.reduce((a, c) => a + c)) && b.chance(0.75)) seen[id] = g.cards[id].symbol;
    }
    if (g.finished || g.showingMismatch || g.turn != b.seat || g.picks.length >= 2) return;
    if (!b.thinkFirst((g.picks.length, g.pairs.reduce((a, c) => a + c), g.picks.firstOrNull), now, 700, 1300)) return;
    final open = [for (final c in g.cards) if (!c.matched && !g.picks.contains(c.id)) c.id];
    seen.removeWhere((id, _) => g.cards[id].matched);
    int? partner(String symbol, int not) => seen.entries.where((e) => e.value == symbol && e.key != not && open.contains(e.key)).map((e) => e.key).firstOrNull;
    int? target;
    if (g.picks.isEmpty) {
      // A pair I already know about?
      for (final e in seen.entries) {
        if (open.contains(e.key) && partner(e.value, e.key) != null) {
          target = e.key;
          break;
        }
      }
    } else {
      target = partner(g.cards[g.picks.first].symbol, g.picks.first);
    }
    final unknown = open.where((id) => !seen.containsKey(id)).toList();
    g.flip(target ?? (unknown.isNotEmpty ? b.pick(unknown) : b.pick(open)));
  }),
  play: (players, onFinished) => TickingPlay<MemoryLogic>(
    create: () => MemoryLogic(players: players.length),
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
      padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
      child: Column(children: [
        GameHud(players: players, scores: g.pairs, turn: g.finished ? null : g.turn),
        GameStatus(
          player: current,
          turnText: g.showingMismatch ? null : '${current.whose} TURN',
          message: g.finished ? '🎉 BOARD CLEAR!' : (g.showingMismatch ? 'NO MATCH…' : null),
        ),
        const SizedBox(height: Space.xs),
        Expanded(
          child: _board(LayoutBuilder(builder: (context, c) {
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
                  ownerSeat: card.matched ? PlayerPalette.indexOf(players[card.matchedBy!].color) : null,
                  onTap: () {
                    if (g.flip(card.id)) {
                      haptic(HapticWeight.selection);
                      GameAudio.sfx('tap');
                    }
                  },
                );
              },
            );
          })),
        ),
      ]),
    );
  }

  /// The flat app lays the cards on a dark board panel, like Guess the Person.
  Widget _board(Widget grid) => flatStyle
      ? Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: FlatColors.board, borderRadius: BorderRadius.circular(24)), child: grid)
      : grid;
}

/// Flat app: each memory symbol stands for one cartoon person (distinct looks, no near-twins).
const _faceIds = [11, 16, 1, 12, 5, 3, 2, 4, 9, 19, 15, 28];
Person _faceFor(String symbol) {
  final id = _faceIds[MemoryLogic.symbols.indexOf(symbol) % _faceIds.length];
  return allPeople.firstWhere((p) => p.id == id);
}

/// Diagonal lattice on the card backs.
class _CardBackPattern extends CustomPainter {
  const _CardBackPattern();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 1.2;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)));
    for (var x = -size.height; x < size.width + size.height; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card that flips around its vertical axis.
class _FlipCard extends StatelessWidget {
  final bool faceUp;
  final String symbol;
  final Color? ownerColor;
  final int? ownerSeat; // matched: the owner's shape in the corner
  final VoidCallback onTap;
  const _FlipCard({super.key, required this.faceUp, required this.symbol, required this.ownerColor, this.ownerSeat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !faceUp,
      label: faceUp ? 'Card $symbol' : 'Hidden card',
      excludeSemantics: true,
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
              child: Stack(fit: StackFit.expand, children: [
                flatStyle ? (showFace ? _flatFace() : _flatBack()) : (showFace ? _face() : _back()),
                if (showFace && ownerSeat != null)
                  Positioned(
                    right: 4,
                    top: 4,
                    width: 16,
                    height: 16,
                    child: CustomPaint(painter: PlayerShapePainter(PlayerPalette.shape(ownerSeat!), ownerColor!, outline: Colors.white)),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _back() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 6)],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7B4DFF), Color(0xFF4D2BD6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: CustomPaint(
            painter: const _CardBackPattern(),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18), border: Border.all(color: Colors.white70, width: 2)),
                child: const FittedBox(child: Text('🧠', style: TextStyle(fontSize: 22))),
              ),
            ),
          ),
        ),
      );

  /// White card with a big blue "?".
  Widget _flatBack() => Container(
        decoration: flatTile(radius: 12),
        alignment: Alignment.center,
        child: const FittedBox(
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Text('?', style: TextStyle(color: FlatColors.sky, fontSize: 48, fontWeight: FontWeight.w900, height: 1)),
          ),
        ),
      );

  /// The person's face with their name on a dark strip; matched cards get the owner's colour.
  Widget _flatFace() {
    final p = _faceFor(symbol);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ownerColor ?? Colors.white, width: ownerColor == null ? 2 : 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(3, 4, 3, 0), child: PersonPortrait(p))),
          Container(
            color: ownerColor ?? FlatColors.strip,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
          ),
        ]),
      ),
    );
  }

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
