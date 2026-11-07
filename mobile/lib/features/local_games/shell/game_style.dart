import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';

/// The colour (and emoji) of the game being played, for backgrounds, bars and buttons.
class GameTheme extends InheritedWidget {
  final Color color;
  final String emoji;
  final bool flat; // drawn in the flat app's light board-game look
  final String? id; // the game's id (e.g. for its records)
  const GameTheme(
      {super.key,
      required this.color,
      required this.emoji,
      this.flat = false,
      this.id,
      required super.child});

  static Color colorOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameTheme>()?.color ??
      const Color(0xFFFFC93C);
  static bool flatOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameTheme>()?.flat ?? false;
  static String? idOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameTheme>()?.id;

  @override
  bool updateShouldNotify(GameTheme old) =>
      old.color != color ||
      old.emoji != emoji ||
      old.flat != flat ||
      old.id != id;
}

/// Quiet shared surface lets the board and player colours carry the game.
class GameBackground extends StatelessWidget {
  final Color color;
  final Widget child;
  final bool flat;
  const GameBackground(
      {super.key, required this.color, required this.child, this.flat = false});

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.tk.bg, child: child);
}

/// A round frosted button (pause, back): the shared [AppIconButton].
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  const GlassIconButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.size = 40});

  @override
  Widget build(BuildContext context) => AppIconButton(
      icon: icon, tooltip: tooltip, onPressed: onPressed, size: size);
}

/// A pill showing a number in the game's colour (scores, timers).
class ScorePill extends StatelessWidget {
  final String text;
  final Color? color;
  const ScorePill(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c = fillFor(color ??
        GameTheme.colorOf(
            context)); // white digits stay readable on light game colours
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.25)!]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: c.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              fontFeatures: [FontFeature.tabularFigures()],
              shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1))])),
    );
  }
}
