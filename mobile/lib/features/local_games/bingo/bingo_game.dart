import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
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

class _BingoTable extends StatelessWidget {
  final BingoLogic g;
  final List<GpPlayer> players;
  final int? me; // whose card this phone shows (online, or one person vs bots)
  final Set<int> bots;
  const _BingoTable({required this.g, required this.players, this.me, this.bots = const {}});

  @override
  Widget build(BuildContext context) {
    // One phone, several people: the card on screen is the caller's, after the phone is passed.
    final passing = me == null;
    final holder = me ?? (bots.contains(g.turn) ? _lastPerson() : g.turn);
    final covered = passing && !bots.contains(g.turn) && g.revealedFor != g.turn && !g.finished;
    final myTurn = holder == g.turn && !bots.contains(g.turn);
    final current = players[g.turn];
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
        child: Column(children: [
          Row(children: [
            const PauseButton(),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < players.length; i++) _ProgressChip(player: players[i], lines: g.lineCount(i), active: i == g.turn && !g.finished),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          _Letters(lines: g.lineCount(holder), color: players[holder].color),
          const SizedBox(height: 8),
          Text(
            g.finished
                ? '🎉 BINGO!'
                : myTurn
                    ? (passing ? '${current.whose} TURN: CALL A NUMBER' : 'YOUR TURN: CALL A NUMBER')
                    : '${current.name} is calling…',
            textAlign: TextAlign.center,
            style: TextStyle(color: g.finished ? GpColors.accent : current.color, fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 10),
          Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _Card(g: g, player: holder, color: players[holder].color, canCall: myTurn && !covered)))),
          const SizedBox(height: 10),
          if (g.called.isNotEmpty)
            Text('Called: ${g.called.reversed.take(8).join(' · ')}${g.called.length > 8 ? ' …' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
        ]),
      ),
      if (covered) _PassCover(player: current, onReveal: () => g.reveal(g.turn)),
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
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < BingoLogic.word.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < lines ? color : Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: i < lines ? Colors.white : Colors.white24, width: 2),
              boxShadow: [if (i < lines) BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
            ),
            child: Text(BingoLogic.word[i], style: TextStyle(color: i < lines ? Colors.white : Colors.white38, fontWeight: FontWeight.w900, fontSize: 24)),
          ),
      ]);
}

class _ProgressChip extends StatelessWidget {
  final GpPlayer player;
  final int lines;
  final bool active;
  const _ProgressChip({required this.player, required this.lines, required this.active});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? player.color : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: player.color, width: 2),
        ),
        child: Text('${player.name} · ${lines == 0 ? '—' : BingoLogic.word.substring(0, min(lines, 5))}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: GpColors.card, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 18)]),
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
                          HapticFeedback.selectionClick().ignore();
                          g.call(n);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: inLine ? color : (isMarked ? color.withValues(alpha: 0.35) : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: n == last ? GpColors.ink : color.withValues(alpha: 0.5), width: n == last ? 3 : 1.5),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text('$n', style: TextStyle(color: inLine ? Colors.white : GpColors.ink, fontWeight: FontWeight.w900, fontSize: 26)),
                        ),
                      ),
                      if (isMarked && !inLine) const FittedBox(child: Text('✕', style: TextStyle(color: Color(0x99E5484D), fontSize: 40, fontWeight: FontWeight.w900))),
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

/// One phone, several people: hides the card until the player whose turn it is taps.
class _PassCover extends StatelessWidget {
  final GpPlayer player;
  final VoidCallback onReveal;
  const _PassCover({required this.player, required this.onReveal});
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Container(
          color: GpColors.bgBottom.withValues(alpha: 0.97),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('📲', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            const Text('PASS THE PHONE TO', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text(player.name.toUpperCase(), style: TextStyle(color: player.color, fontWeight: FontWeight.w900, fontSize: 32)),
            const SizedBox(height: 18),
            GpButton('SHOW MY CARD', icon: Icons.visibility_rounded, color: player.color, textColor: Colors.white, onPressed: onReveal),
          ]),
        ),
      );
}
