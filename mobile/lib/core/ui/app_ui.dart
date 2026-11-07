import 'package:flutter/material.dart';
import 'app_theme_ext.dart';
import 'party_logo.dart';

export 'app_theme_ext.dart';
export 'party_logo.dart';

/// Thin aliases to the design tokens (tokens.dart); new code reads `context.tk` instead.
class AppColors {
  static const navy = Brand.navy;
  static const night = Brand.night;
  static const deep = Brand.deep;
  static const blue = Brand.blue;
  static const red = Brand.red;
  static const gold = Brand.gold;
  static const purple = Brand.purple;
  static const green = Brand.green;
  static const text = NeonPalette.text;
  static const muted = NeonPalette.textMuted;
  static const glass = NeonPalette.surfaceStrong;
  static const stroke = NeonPalette.stroke;
}

/// The token set app screens use when no theme says otherwise.
final appTokens = GameTokens.neon;

/// The app theme. App screens follow the phone's light or dark setting.
ThemeData buildAppTheme([Brightness brightness = Brightness.dark]) {
  final dark = brightness == Brightness.dark;
  final tk = dark ? GameTokens.neon : GameTokens.flatSet;
  final scheme = ColorScheme.fromSeed(seedColor: Brand.gold, brightness: brightness).copyWith(
    primary: Brand.gold,
    onPrimary: Brand.onGold,
    secondary: dark ? Brand.goldLine : Brand.goldDeep,
    surface: tk.card,
    onSurface: tk.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: Fonts.body,
    colorScheme: scheme,
    extensions: [tk],
    scaffoldBackgroundColor: tk.bg,
    appBarTheme: AppBarTheme(backgroundColor: tk.bg, foregroundColor: tk.onBg, centerTitle: true, elevation: 0),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: tk.flat ? FlatPalette.strip : NeonPalette.cardRaised, contentTextStyle: const TextStyle(color: NeonPalette.text, fontWeight: FontWeight.w500)),
    dialogTheme: DialogThemeData(backgroundColor: tk.card),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.goldDeep : tk.text.withValues(alpha: 0.24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tk.flat ? FlatPalette.surface : NeonPalette.surfaceStrong,
      border: OutlineInputBorder(borderRadius: Radii.rButton, borderSide: BorderSide(color: tk.stroke)),
      enabledBorder: OutlineInputBorder(borderRadius: Radii.rButton, borderSide: BorderSide(color: tk.stroke)),
      focusedBorder: OutlineInputBorder(borderRadius: Radii.rButton, borderSide: const BorderSide(color: Brand.gold, width: 2)),
      hintStyle: TextStyle(color: tk.textMuted),
    ),
  );
}

/// The page surface: one calm neutral. Colour lives in the game previews.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(color: context.tk.bg, child: child);
}

/// The app logo.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 180});
  @override
  Widget build(BuildContext context) => PartyLogoIcon(size: size);
}

/// Heading for a section of a page.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Row(children: [
          Expanded(child: Text(text, style: context.tk.styles.bodyStrong)),
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
            color: widget.colors.first,
            borderRadius: Radii.rLg,
            border: Border.all(color: AppColors.stroke),
            boxShadow: [if (!_down) BoxShadow(color: shadow, offset: const Offset(0, 3))],
          ),
          child: Opacity(opacity: enabled ? 1 : 0.55, child: widget.child),
        ),
      ),
    );
  }
}
