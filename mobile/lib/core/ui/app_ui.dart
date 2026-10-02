import 'package:flutter/material.dart';
import 'party_logo.dart';

export 'party_logo.dart';

/// Colours taken from the app logo: deep navy, neon blue vs red, and gold.
class AppColors {
  static const navy = Color(0xFF14207A);
  static const night = Color(0xFF0A0F3D);
  static const deep = Color(0xFF060827);
  static const blue = Color(0xFF2E8BFF);
  static const red = Color(0xFFFF3B5C);
  static const gold = Color(0xFFFFC93C);
  static const purple = Color(0xFF7B4DFF);
  static const green = Color(0xFF2ECC71);
  static const text = Colors.white;
  static const muted = Color(0xFFAAB2E8);
  static const glass = Color(0x1AFFFFFF);
  static const stroke = Color(0x26FFFFFF);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.purple, brightness: Brightness.dark).copyWith(
    primary: AppColors.gold,
    onPrimary: AppColors.night,
    secondary: AppColors.blue,
    surface: AppColors.night,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.deep,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.night, foregroundColor: Colors.white, centerTitle: true),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.navy, contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.night),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glass,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.gold, width: 2)),
      hintStyle: const TextStyle(color: Colors.white38),
    ),
  );
}

/// Navy night background with soft blue and red glows, like the logo.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.navy, AppColors.night, AppColors.deep]),
        ),
        child: Stack(children: [
          const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Glows()))),
          Positioned.fill(child: child),
        ]),
      );
}

class _Glows extends CustomPainter {
  const _Glows();
  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color color) => canvas.drawCircle(
        c, r, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    glow(Offset(-size.width * 0.1, size.height * 0.12), size.width * 0.7, AppColors.blue);
    glow(Offset(size.width * 1.1, size.height * 0.35), size.width * 0.7, AppColors.red);
    glow(Offset(size.width * 0.5, size.height * 1.05), size.width * 0.8, AppColors.purple);
    // A few sparkles.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (final (x, y, r) in const [(0.12, 0.06, 1.6), (0.82, 0.1, 2.0), (0.6, 0.22, 1.2), (0.25, 0.42, 1.4), (0.9, 0.55, 1.8), (0.08, 0.75, 1.5), (0.7, 0.85, 1.3)]) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The app logo with a soft neon glow behind it.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 180});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.blue.withValues(alpha: 0.35), blurRadius: size * 0.3, offset: Offset(-size * 0.06, 0)),
            BoxShadow(color: AppColors.red.withValues(alpha: 0.3), blurRadius: size * 0.3, offset: Offset(size * 0.06, 0)),
          ],
        ),
        child: PartyLogoIcon(size: size),
      );
}

/// Small caps heading for a section of a page.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10, left: 2),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.6))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Rounded gradient card that sinks slightly when pressed.
class PressableCard extends StatefulWidget {
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  const PressableCard({super.key, required this.colors, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.semanticLabel});
  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final shadow = Color.lerp(widget.colors.last, Colors.black, 0.55)!;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.stroke),
            boxShadow: [if (!_down) BoxShadow(color: shadow, offset: const Offset(0, 5))],
          ),
          child: Opacity(opacity: enabled ? 1 : 0.55, child: widget.child),
        ),
      ),
    );
  }
}
