import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../party/party_widgets.dart' show PassCover;
import '../shell/ticking_play.dart';

/// Bingo: everyone has a 5x5 card with 1-25 in a different order. Players take turns
/// calling a number; it's crossed off on every card. Each full row, column or diagonal
/// lights a letter of B-I-N-G-O. Five lines first wins (everyone who gets there on the
/// same call wins together).
class BingoLogic extends LocalGameLogic {
  static const size = 5;
  static const word = 'BINGO';
  static final List<List<int>> lines = [
    for (var r = 0; r < size; r++) [for (var c = 0; c < size; c++) r * size + c],
    for (var c = 0; c < size; c++) [for (var r = 0; r < size; r++) r * size + c],
    [for (var i = 0; i < size; i++) i * size + i],
    [for (var i = 0; i < size; i++) i * size + size - 1 - i],
  ];

  final int players;
  final List<List<int>> cards; // per player: the 25 numbers, cell by cell
  final List<int> called = [];
  int turn = 0;
  Set<int> winners = {};
  int revealedFor = -1; // one phone: whose card is uncovered (not part of the online state)

  BingoLogic({this.players = 2, Random? random})
      : cards = [
          for (var p = 0; p < players; p++) [for (var n = 1; n <= size * size; n++) n]..shuffle(random ?? Random()),
        ];

  @override
  bool get finished => winners.isNotEmpty;
  @override
  List<int> get scores => [for (var p = 0; p < players; p++) winners.contains(p) ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  bool isCalled(int n) => called.contains(n);
  bool marked(int player, int cell) => called.contains(cards[player][cell]);

  /// Lines completed on a player's card (5 = BINGO).
  int lineCount(int player) => lines.where((l) => l.every((cell) => marked(player, cell))).length;
  List<List<int>> doneLines(int player) => lines.where((l) => l.every((cell) => marked(player, cell))).toList();

  /// The player whose turn it is calls [number]. Returns false if it can't be called.
  bool call(int number) {
    if (forward('call', [number])) return false;
    if (finished || number < 1 || number > size * size || isCalled(number)) return false;
    called.add(number);
    winners = {for (var p = 0; p < players; p++) if (lineCount(p) >= size) p};
    if (!finished) turn = (turn + 1) % players;
    notifyListeners();
    return true;
  }

  void reveal(int player) {
    revealedFor = player;
    notifyListeners();
  }
}

/// The computer calls the number that helps its own lines most (and, a little, avoids
/// numbers that would finish someone else's line).
int bingoBotPick(BingoLogic g, int me, Random rng) {
  var best = -1;
  var bestScore = -1e9;
  for (var n = 1; n <= BingoLogic.size * BingoLogic.size; n++) {
    if (g.isCalled(n)) continue;
    double score = rng.nextDouble();
    for (var p = 0; p < g.players; p++) {
      final cell = g.cards[p].indexOf(n);
      for (final l in BingoLogic.lines.where((l) => l.contains(cell))) {
        final have = l.where((c) => g.marked(p, c)).length;
        final gain = (have + 1) * (have + 1).toDouble();
        score += p == me ? gain : -gain * 0.3;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = n;
    }
  }
  return best;
}

final bingoInfo = LocalGameInfo(
  id: 'bingo',
  title: 'Bingo',
  emoji: '🔢',
  color: const Color(0xFFFF6B35),
  tagline: 'Call numbers, complete lines, shout BINGO!',
  rules: const [
    'Everyone has a 5×5 card with the numbers 1-25 in a different order.',
    'On your turn, tap a number on your card to call it. It gets crossed off on every card.',
    'Every full row, column or diagonal lights a letter of B-I-N-G-O.',
    'Light all five letters first to win! 2 to 6 players.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  maxPlayers: 6,
  bot: botFor<BingoLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.called.length, now, 800, 1600)) return;
    g.call(bingoBotPick(g, b.seat, b.rng));
  }),
  online: RelaySpec<BingoLogic>(
    create: (n) => BingoLogic(players: n),
    save: (g) => {'cards': [for (final c in g.cards) ...c], 'called': g.called, 'turn': g.turn, 'win': g.winners.toList()},
    load: (g, s, me) {
      final cards = ints(s['cards']);
      for (var p = 0; p < g.players; p++) {
        g.cards[p].setAll(0, cards.sublist(p * 25, p * 25 + 25));
      }
      g.called
        ..clear()
        ..addAll(ints(s['called']));
      g.turn = asInt(s['turn']);
      g.winners = ints(s['win']).toSet();
    },
    apply: (g, from, name, a) {
      if (name == 'call' && from == g.turn) g.call(asInt(a[0]));
    },
    view: (context, g, players, me) => _BingoTable(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<BingoLogic>(
    create: () => BingoLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) {
      final bots = {for (var i = 0; i < players.length; i++) if (BotScope.isBot(context, i)) i};
      return _BingoTable(g: g, players: players, me: BotScope.humanSeat(context), bots: bots);
    },
  ),
);

// Board palette: a paper bingo ticket and a dabber.
const _ticket = Color(0xFFFFF8EC);
const _ticketInk = Color(0xFF1E1B3A);

class _BingoTable extends StatelessWidget {
  final BingoLogic g;
  final List<GpPlayer> players;
  final int? me; // whose card this phone shows (online, or one person vs bots)
  final Set<int> bots;
  const _BingoTable({required this.g, required this.players, this.me, this.bots = const {}});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // One phone, several people: the card on screen is the caller's, after the phone is passed.
    final passing = me == null;
    final holder = me ?? (bots.contains(g.turn) ? _lastPerson() : g.turn);
    final covered = passing && !bots.contains(g.turn) && g.revealedFor != g.turn && !g.finished;
    final myTurn = holder == g.turn && !bots.contains(g.turn);
    final current = players[g.turn];
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
        child: Column(children: [
          GameHud(
            players: players,
            turn: g.finished ? null : g.turn,
            extra: (i) => g.lineCount(i) == 0 ? '—' : BingoLogic.word.substring(0, min(g.lineCount(i), 5)),
          ),
          const SizedBox(height: Space.m),
          _Letters(lines: g.lineCount(holder), color: players[holder].color),
          GameStatus(
            player: current,
            height: 46,
            turnText: myTurn ? (passing ? '${current.whose} TURN: CALL A NUMBER' : 'YOUR TURN: CALL A NUMBER') : '${current.name} is calling…',
            message: g.finished ? '🎉 BINGO!' : null,
          ),
          Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _Card(g: g, player: holder, color: players[holder].color, canCall: myTurn && !covered)))),
          const SizedBox(height: Space.s),
          if (g.called.isNotEmpty)
            SizedBox(
              height: 40,
              child: Row(children: [
                Text('CALLED', style: t.styles.label),
                const SizedBox(width: Space.s),
                Expanded(
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final n in g.called.reversed.take(12))
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: n == g.called.last ? Brand.gold : t.glassStrong),
                        child: Text('$n', style: TextStyle(color: n == g.called.last ? Brand.ink : t.onBg, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
      if (covered) PassCover(player: current, holdLabel: 'HOLD TO SEE YOUR CARD', onReveal: () => g.reveal(g.turn)),
    ]);
  }

  int _lastPerson() {
    for (var i = g.turn - 1; i >= -players.length; i--) {
      final p = i % players.length;
      if (!bots.contains(p)) return p;
    }
    return 0;
  }
}

class _Letters extends StatelessWidget {
  final int lines;
  final Color color;
  const _Letters({required this.lines, required this.color});
  @override
  Widget build(BuildContext context) => Semantics(
        label: lines == 0 ? 'No lines yet' : '${BingoLogic.word.substring(0, min(lines, 5))}: $lines lines',
        excludeSemantics: true,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < BingoLogic.word.length; i++)
            AnimatedContainer(
              duration: Motion.of(context, Motion.slow),
              curve: Motion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < lines ? fillFor(color) : context.tk.glass,
                borderRadius: Radii.rMd,
                border: Border.all(color: i < lines ? Colors.white : context.tk.stroke, width: 2),
                boxShadow: [if (i < lines) BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
              ),
              child: Text(BingoLogic.word[i], style: TextStyle(color: i < lines ? Colors.white : context.tk.onBgMuted, fontWeight: FontWeight.w900, fontSize: 24)),
            ),
        ]),
      );
}

class _Card extends StatelessWidget {
  final BingoLogic g;
  final int player;
  final Color color;
  final bool canCall;
  const _Card({required this.g, required this.player, required this.color, required this.canCall});

  @override
  Widget build(BuildContext context) {
    final done = {for (final l in g.doneLines(player)) ...l};
    final last = g.called.isEmpty ? null : g.called.last;
    final dab = fillFor(color);
    return Container(
      padding: const EdgeInsets.all(Space.s),
      decoration: BoxDecoration(
        color: _ticket,
        borderRadius: Radii.rXl,
        border: Border.all(color: dab, width: 3),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 18), const BoxShadow(color: Colors.black45, offset: Offset(0, 6))],
      ),
      child: GridView.count(
        crossAxisCount: BingoLogic.size,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var cell = 0; cell < 25; cell++)
            Builder(builder: (context) {
              final n = g.cards[player][cell];
              final isMarked = g.isCalled(n);
              final inLine = done.contains(cell);
              return Semantics(
                button: canCall && !isMarked,
                label: isMarked ? '$n, crossed off' : '$n',
                child: GestureDetector(
                  onTap: canCall && !isMarked
                      ? () {
                          haptic(HapticWeight.selection);
                          GameAudio.sfx('pop');
                          g.call(n);
                        }
                      : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: inLine ? dab : Colors.white,
                      borderRadius: Radii.rSm,
                      border: Border.all(color: n == last ? Brand.ink : dab.withValues(alpha: 0.35), width: n == last ? 3 : 1.5),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      // The dabber's ink blot over a called number.
                      if (isMarked && !inLine)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: Motion.reduced(context) ? 1 : 0.4, end: 1),
                          duration: Motion.of(context, Motion.normal),
                          curve: Curves.easeOutBack,
                          builder: (_, s, child) => Transform.scale(scale: s, child: child),
                          child: FractionallySizedBox(
                            widthFactor: 0.82,
                            heightFactor: 0.82,
                            child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.45))),
                          ),
                        ),
                      FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text('$n', style: TextStyle(color: inLine ? Colors.white : _ticketInk, fontWeight: FontWeight.w900, fontSize: 26, fontFeatures: const [FontFeature.tabularFigures()])),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}