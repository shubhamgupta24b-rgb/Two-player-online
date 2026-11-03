import 'package:flutter/material.dart';
import 'tokens.dart';

/// The second app ("Party Games Flat") is built from the same code with
/// `--dart-define=APP_STYLE=flat`. It keeps its own name and app ID but shares one design,
/// so there is only one look to maintain.
const bool flatBuild = String.fromEnvironment('APP_STYLE') == 'flat';

/// Retired switch: the old sky-blue look. Always off.
const bool flatStyle = false;

const String appName = flatBuild ? 'Party Games Flat' : 'Party Games';

/// All games play on the dark surface.
bool isFlatGame(String id) => false;

/// Thin aliases to the flat token palette (tokens.dart); new code reads `context.tk`.
class FlatColors {
  static const sky = FlatPalette.sky;
  static const skyLight = FlatPalette.skyLight;
  static const board = FlatPalette.board;
  static const strip = FlatPalette.strip;
  static const ink = FlatPalette.ink;
  static const tile = FlatPalette.tile;
  static const tileShade = FlatPalette.tileShade;
  static const option = FlatPalette.option;
  static const mark = FlatPalette.mark;
  static const close = FlatPalette.close;
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
        text: TextSpan(text: '?', style: TextStyle(color: color, fontSize: size.width * s, fontWeight: FontWeight.w700)),
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
