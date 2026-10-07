import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

const hangmanWords = {
  '🎬 Bollywood': ['SHOLAY', 'DANGAL', 'LAGAAN', 'BAAHUBALI', 'PATHAAN', 'ANDHADHUN', 'BARFI', 'QUEEN', 'DEVDAS', 'SWADES', 'KAHAANI', 'PADMAAVAT'],
  '🍛 Food': ['BIRYANI', 'SAMOSA', 'DOSA', 'PANEER', 'JALEBI', 'PAKORA', 'KHICHDI', 'RASGULLA', 'CHOLE', 'PARATHA', 'LASSI', 'MOMOS'],
  '🐾 Animals': ['ELEPHANT', 'GIRAFFE', 'PEACOCK', 'KANGAROO', 'DOLPHIN', 'PENGUIN', 'TIGER', 'CHEETAH', 'OCTOPUS', 'RHINO', 'ZEBRA', 'CAMEL'],
  '🌍 Countries': ['INDIA', 'JAPAN', 'BRAZIL', 'CANADA', 'EGYPT', 'NEPAL', 'FRANCE', 'MEXICO', 'KENYA', 'NORWAY', 'TURKEY', 'BHUTAN'],
  '🏏 Sports': ['CRICKET', 'KABADDI', 'HOCKEY', 'TENNIS', 'BADMINTON', 'FOOTBALL', 'CHESS', 'BOXING', 'ARCHERY', 'CYCLING', 'KHOKHO', 'SWIMMING'],
  '🏙️ Cities': ['MUMBAI', 'DELHI', 'JAIPUR', 'KOLKATA', 'CHENNAI', 'PUNE', 'GOA', 'AGRA', 'LUCKNOW', 'INDORE', 'SHIMLA', 'MYSORE'],
};

/// Hangman: guess the word one letter at a time. 6 wrong guesses and the drawing is
/// complete. Every word you get is a point; the game ends when you miss one.
class HangmanLogic extends SoloLogic {
  static const lives = 6;
  final Random rng;
  late String category, word;
  final Set<String> guessed = {};
  int wrong = 0;
  int? wonAt;
  final List<String> _used = [];

  HangmanLogic({Random? random}) : rng = random ?? Random() {
    _next();
  }

  void _next() {
    final cats = hangmanWords.keys.toList();
    do {
      category = cats[rng.nextInt(cats.length)];
      final list = hangmanWords[category]!;
      word = list[rng.nextInt(list.length)];
    } while (_used.contains(word) && _used.length < 40);
    _used.add(word);
    guessed.clear();
    wrong = 0;
  }

  bool get won => word.split('').every(guessed.contains);
  String get shown => [for (final ch in word.split('')) guessed.contains(ch) || over ? ch : '_'].join(' ');

  void guess(String letter) {
    if (over || wonAt != null || guessed.contains(letter)) return;
    guessed.add(letter);
    if (!word.contains(letter)) {
      wrong++;
      HapticFeedback.heavyImpact().ignore();
      if (wrong >= lives) gameOver(2200);
    } else {
      HapticFeedback.selectionClick().ignore();
      if (won) {
        score++;
        wonAt = now;
      }
    }
    notifyListeners();
  }

  @override
  void step(int now) {
    final at = wonAt;
    if (at != null && now - at > 1200) {
      wonAt = null;
      _next();
      notifyListeners();
    }
  }
}

final hangmanInfo = LocalGameInfo(
  id: 'hangman',
  title: 'Hangman',
  emoji: '🪢',
  color: const Color(0xFF8D6E63),
  tagline: 'Guess the word before you run out of lives!',
  rules: const [
    'A secret word and its category. Tap letters to guess.',
    'A wrong letter costs a life: 6 and the drawing is done.',
    'Every word you get is a point. Miss one and the game ends.',
  ],
  scoreUnit: 'words',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<HangmanLogic>(
    create: () => HangmanLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: g.wonAt != null ? '🎉 GOT IT!' : (g.over ? '💀 IT WAS ${g.word}' : '🪢 HANGMAN'),
      score: g.score,
      extra: '${g.category} · ❤️ ${HangmanLogic.lives - g.wrong}',
      child: Column(children: [
        Expanded(flex: 5, child: CustomPaint(size: Size.infinite, painter: _GallowsPainter(g.wrong, g.over && !g.won))),
        const SizedBox(height: 8),
        FittedBox(
          child: Text(g.shown,
              style: TextStyle(color: g.wonAt != null ? GpColors.yes : (g.over ? GpColors.no : Colors.white), fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ),
        const SizedBox(height: 14),
        // Keys at least 48dp wide: 7 a row where they fit, else 6.
        LayoutBuilder(builder: (context, c) {
          const gap = 5.0;
          final perRow = c.maxWidth >= 7 * kTouchTarget + 6 * gap ? 7 : 6;
          final keyW = ((c.maxWidth - gap * (perRow - 1)) / perRow).clamp(kTouchTarget, 58.0);
          return Wrap(alignment: WrapAlignment.center, spacing: gap, runSpacing: 6, children: [
            for (final l in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
              SizedBox(
                width: keyW,
                height: 50,
                child: Semantics(
                  button: !g.guessed.contains(l),
                  label: g.guessed.contains(l) ? '$l, ${g.word.contains(l) ? 'in the word' : 'not in the word'}' : l,
                  excludeSemantics: true,
                  child: Material(
                    color: !g.guessed.contains(l) ? Colors.white : (g.word.contains(l) ? fillFor(context.tk.success) : Colors.white12),
                    borderRadius: Radii.rMd,
                    elevation: g.guessed.contains(l) ? 0 : 2,
                    child: InkWell(
                      borderRadius: Radii.rMd,
                      onTap: g.guessed.contains(l)
                          ? null
                          : () {
                              haptic(HapticWeight.selection);
                              GameAudio.sfx(g.word.contains(l) ? 'pop' : 'tap');
                              g.guess(l);
                            },
                      child: Center(
                        child: Text(l,
                            style: TextStyle(color: !g.guessed.contains(l) ? Brand.ink : (g.word.contains(l) ? Colors.white : Colors.white38), fontWeight: FontWeight.w900, fontSize: 19)),
                      ),
                    ),
                  ),
                ),
              ),
          ]);
        }),      ]),
    ),
  ),
);

class _GallowsPainter extends CustomPainter {
  final int wrong;
  final bool lost;
  _GallowsPainter(this.wrong, this.lost);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    final cx = w / 2;
    final wood = Paint()
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 90, h * 0.95), Offset(cx + 40, h * 0.95), wood);
    canvas.drawLine(Offset(cx - 60, h * 0.95), Offset(cx - 60, h * 0.06), wood);
    canvas.drawLine(Offset(cx - 60, h * 0.06), Offset(cx + 30, h * 0.06), wood);
    canvas.drawLine(Offset(cx - 60, h * 0.2), Offset(cx - 35, h * 0.06), wood..strokeWidth = 5);
    final rope = Paint()
      ..color = const Color(0xFFD7CCC8)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx + 30, h * 0.06), Offset(cx + 30, h * 0.18), rope);
    final body = Paint()
      ..color = lost ? const Color(0xFFFF8A80) : Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final head = h * 0.08;
    if (wrong > 0) canvas.drawCircle(Offset(cx + 30, h * 0.18 + head), head, body);
    final neck = h * 0.18 + head * 2, hip = h * 0.62;
    if (wrong > 1) canvas.drawLine(Offset(cx + 30, neck), Offset(cx + 30, hip), body);
    if (wrong > 2) canvas.drawLine(Offset(cx + 30, neck + 12), Offset(cx + 5, h * 0.48), body);
    if (wrong > 3) canvas.drawLine(Offset(cx + 30, neck + 12), Offset(cx + 55, h * 0.48), body);
    if (wrong > 4) canvas.drawLine(Offset(cx + 30, hip), Offset(cx + 8, h * 0.82), body);
    if (wrong > 5) canvas.drawLine(Offset(cx + 30, hip), Offset(cx + 52, h * 0.82), body);
  }

  @override
  bool shouldRepaint(_GallowsPainter old) => old.wrong != wrong || old.lost != lost;
}
