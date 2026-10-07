import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const scrambleWords = [
  'APPLE', 'TIGER', 'CRICKET', 'GUITAR', 'PLANET', 'ROCKET', 'BANANA', 'GARDEN', 'MANGO', 'RIVER', 'PENCIL', 'CAMERA', //
  'SCHOOL', 'FRIEND', 'WINTER', 'SUMMER', 'MONKEY', 'DOCTOR', 'TRAIN', 'CASTLE', 'DRAGON', 'JUNGLE', 'BUTTER', 'COFFEE', //
  'LAPTOP', 'MOBILE', 'SILVER', 'PUZZLE', 'SPICY', 'SAMOSA', 'CANDLE', 'MIRROR', 'ORANGE', 'PIRATE', 'WIZARD', 'TICKET', //
  'BRIDGE', 'FOREST', 'HAMMER', 'ISLAND', 'KITTEN', 'LEMON', 'MARKET', 'NEEDLE', 'OCEAN', 'PARROT', 'QUEEN', 'RABBIT', //
  'SPIDER', 'TOMATO', 'VIOLIN', 'WALLET', 'YELLOW', 'ZEBRA', 'CLOUD', 'DANCE', 'EAGLE', 'FLOWER', 'GHOST', 'HONEY',
];

/// Word Scramble: 60 seconds. Tap the letters in order to rebuild the hidden word.
/// Each solved word scores its length. SKIP if you're stuck.
class WordScrambleLogic extends SoloLogic {
  static const durationMs = 60000;
  final Random _rng;
  late final List<String> deck = [...scrambleWords]..shuffle(_rng);
  int index = 0;
  late List<String> letters; // shuffled tiles
  final List<int> picked = []; // tile indexes in tapping order
  int solved = 0;
  bool wrongFlash = false;

  WordScrambleLogic({Random? random}) : _rng = random ?? Random() {
    _deal();
  }

  String get word => deck[index % deck.length];
  String get attempt => picked.map((i) => letters[i]).join();
  int get msLeft => max(0, durationMs - now);

  void _deal() {
    picked.clear();
    final w = word.split('');
    do {
      w.shuffle(_rng);
    } while (w.join() == word && word.length > 1);
    letters = w;
  }

  void tapLetter(int i) {
    if (over || picked.contains(i)) return;
    picked.add(i);
    wrongFlash = false;
    HapticFeedback.selectionClick().ignore();
    if (picked.length == letters.length) {
      if (attempt == word) {
        score += word.length;
        solved++;
        HapticFeedback.mediumImpact().ignore();
        index++;
        _deal();
      } else {
        wrongFlash = true;
        picked.clear();
      }
    }
    notifyListeners();
  }

  void undo() {
    if (picked.isNotEmpty) picked.removeLast();
    notifyListeners();
  }

  void skip() {
    if (over) return;
    index++;
    _deal();
    notifyListeners();
  }

  @override
  void step(int now) {
    if (now >= durationMs) return gameOver(1500);
    notifyListeners(); // the clock
  }
}

final wordScrambleInfo = LocalGameInfo(
  id: 'word_scramble',
  title: 'Word Scramble',
  emoji: '🔤',
  color: const Color(0xFF00897B),
  tagline: 'Unscramble as many as you can!',
  rules: const [
    'The letters of a word are mixed up. Tap them in the right order.',
    'Each word you solve scores its number of letters.',
    '60 seconds. Stuck? SKIP to the next word.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<WordScrambleLogic>(
    create: () => WordScrambleLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: '🔤 WORD SCRAMBLE',
      score: g.score,
      extra: '⏱${(g.msLeft / 1000).ceil()}s',
      child: Column(children: [
        const Spacer(),
        if (g.over) Text('The word was ${g.word}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(color: g.wrongFlash ? GpColors.no.withValues(alpha: 0.4) : Colors.white10, borderRadius: BorderRadius.circular(18)),
          child: FittedBox(
            child: Text(
              [for (var i = 0; i < g.letters.length; i++) i < g.picked.length ? g.letters[g.picked[i]] : '_'].join(' '),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 40, letterSpacing: 4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(g.wrongFlash ? 'Not quite! Try again' : '${g.solved} solved', style: TextStyle(color: g.wrongFlash ? GpColors.no : GpColors.muted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < g.letters.length; i++)
            Opacity(
              opacity: g.picked.contains(i) ? 0.25 : 1,
              child: Material(
                color: const Color(0xFF00897B),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: g.picked.contains(i) ? null : () => g.tapLetter(i),
                  child: SizedBox(width: 54, height: 60, child: Center(child: Text(g.letters[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)))),
                ),
              ),
            ),
        ]),
        const Spacer(),
        Row(children: [
          Expanded(child: GpButton('UNDO', icon: Icons.undo_rounded, outlined: true, onPressed: g.undo)),
          const SizedBox(width: 12),
          Expanded(child: GpButton('SKIP', icon: Icons.skip_next_rounded, color: Colors.white24, textColor: Colors.white, onPressed: g.skip)),
        ]),
      ]),
    ),
  ),
);
