import 'package:flutter/material.dart';

/// Which app this build is. The second app ("Party Games Flat") is built from the same
/// code with `--dart-define=APP_STYLE=flat`: Guess the Person, Memory and the word games
/// get a bright flat board-game look (sky blue, white cards, dark name strips).
/// It is a compile-time constant, so colours can switch inside `const` expressions.
const bool flatStyle = String.fromEnvironment('APP_STYLE') == 'flat';

const String appName = flatStyle ? 'Party Games Flat' : 'Party Games';

/// Games that use the flat look in the flat app: the ones that are mostly words and cards.
const flatGames = {'memory', 'charades', 'heads_up', 'find_spy', 'undercover', 'mafia', 'most_likely', 'would_rather', 'truth_dare'};

bool isFlatGame(String id) => flatStyle && flatGames.contains(id);

class FlatColors {
  static const sky = Color(0xFF4FA3D1);
  static const skyLight = Color(0xFF6BB8E0);
  static const board = Color(0xFF2B6488);
  static const strip = Color(0xFF3A3846);
  static const ink = Color(0xFF22212B);
  static const tile = Colors.white;
  static const tileShade = Color(0xFFD9DEE6);
  static const option = Color(0xFFE8EAEE);
  static const mark = Color(0x1FFFFFFF);
  static const close = Color(0xFFD9534F);
}

/// Sky-blue background scattered with big faint question marks, like a board-game box.
class FlatBackground extends StatelessWidget {
  final Widget child;
  final Color color;
  const FlatBackground({super.key, required this.child, this.color = FlatColors.sky});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.12)!, color]),
        ),
        child: CustomPaint(painter: const QuestionMarksPainter(FlatColors.mark), child: child),
      );
}

class QuestionMarksPainter extends CustomPainter {
  final Color color;
  const QuestionMarksPainter(this.color);
  // (x, y, size, rotation) as fractions of the screen.
  static const _marks = [
    (0.85, 0.06, 0.28, 0.3),
    (0.08, 0.3, 0.22, -0.4),
    (0.9, 0.45, 0.2, 0.5),
    (0.15, 0.7, 0.3, 0.2),
    (0.75, 0.88, 0.26, -0.3),
    (0.45, 0.55, 0.16, 0.6),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, s, rot) in _marks) {
      final tp = TextPainter(
        text: TextSpan(text: '?', style: TextStyle(color: color, fontSize: size.width * s, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(QuestionMarksPainter old) => old.color != color;
}

/// White chunky tile with a darker bottom edge, the flat look's basic card.
BoxDecoration flatTile({double radius = 16, Color color = FlatColors.tile}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(color: Color.lerp(color, Colors.black, 0.22)!, offset: const Offset(0, 4))],
    );
