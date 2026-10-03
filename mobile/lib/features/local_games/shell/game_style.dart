import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/app_flavor.dart';

/// The colour (and emoji) of the game being played, for backgrounds, bars and buttons.
class GameTheme extends InheritedWidget {
  final Color color;
  final String emoji;
  final bool flat; // drawn in the flat app's light board-game look
  const GameTheme({super.key, required this.color, required this.emoji, this.flat = false, required super.child});

  static Color colorOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GameTheme>()?.color ?? const Color(0xFFFFC93C);
  static bool flatOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GameTheme>()?.flat ?? false;

  @override
  bool updateShouldNotify(GameTheme old) => old.color != color || old.emoji != emoji || old.flat != flat;
}

/// Deep night-blue background with a glow in the game's own colour, so every game
/// feels like its own place.
class GameBackground extends StatelessWidget {
  final Color color;
  final Widget child;
  final bool flat; // the flat app's sky-blue board-game look
  const GameBackground({super.key, required this.color, required this.child, this.flat = false});

  @override
  Widget build(BuildContext context) => flat ? FlatBackground(child: child) : DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF151A4A), Color(0xFF0B0E2E), Color(0xFF060820)]),
        ),
        child: Stack(children: [
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Glow(color)))),
          Positioned.fill(child: child),
        ]),
      );
}

class _Glow extends CustomPainter {
  final Color color;
  _Glow(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color col, double a) =>
        canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: a), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    final w = size.width, h = size.height;
    glow(Offset(w * 0.5, -h * 0.05), max(w, h) * 0.55, color, 0.42);
    final hsl = HSLColor.fromColor(color);
    final partner = hsl.withHue((hsl.hue + 150) % 360).toColor();
    glow(Offset(-w * 0.1, h * 1.02), w * 0.9, partner, 0.22);
    glow(Offset(w * 1.1, h * 0.55), w * 0.6, color, 0.12);
    // A few soft sparkles.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (final (x, y, r) in const [(0.1, 0.08, 1.5), (0.88, 0.14, 2.0), (0.72, 0.38, 1.2), (0.16, 0.56, 1.4), (0.92, 0.74, 1.6), (0.36, 0.9, 1.3)]) {
      canvas.drawCircle(Offset(w * x, h * y), r, dot);
    }
  }

  @override
  bool shouldRepaint(_Glow old) => old.color != color;
}

/// A round frosted button (pause, back).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  const GlassIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.size = 40});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.18))),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(width: size, height: size, child: Icon(icon, color: Colors.white, size: size * 0.55)),
            ),
          ),
        ),
      );
}

/// A pill showing a number in the game's colour (scores, timers).
class ScorePill extends StatelessWidget {
  final String text;
  final Color? color;
  const ScorePill(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? GameTheme.colorOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.25)!]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1))])),
    );
  }
}
