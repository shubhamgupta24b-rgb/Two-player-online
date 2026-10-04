import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Design tokens: the raw scales every screen is built from. Widgets read the flavour-aware
/// set through `context.tk` (see app_theme_ext.dart); the consts here are for places that
/// can't (const constructors, painters) and for the AppColors/FlatColors aliases.
/// See docs/design-system.md.

/// Spacing scale (dp).
abstract final class Space {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
}

/// Corner radii (dp).
abstract final class Radii {
  static const double sm = 8, md = 12, lg = 16, xl = 24, pill = 999;
  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
}

/// Durations and curves. Use [Motion.of] so "reduce motion" turns animations off.
abstract final class Motion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const standard = Cubic(0.2, 0, 0, 1);
  static const emphasized = Cubic(0.05, 0.7, 0.1, 1);

  /// True when the system or the app's own setting asks for less motion.
  static final reduceSetting = ValueNotifier<bool>(false);
  static bool reduced(BuildContext context) => reduceSetting.value || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Minimum touch target (dp).
const double kTouchTarget = 48;

/// The logo palette.
abstract final class Brand {
  static const navy = Color(0xFF14207A);
  static const night = Color(0xFF0A0F3D);
  static const deep = Color(0xFF060827);
  static const blue = Color(0xFF2E8BFF);
  static const red = Color(0xFFFF3B5C);
  static const gold = Color(0xFFFFC93C);
  static const purple = Color(0xFF7B4DFF);
  static const green = Color(0xFF2ECC71);
  static const ink = Color(0xFF1E1B3A); // dark text on gold and white
}

/// Raw colours of the default "neon night" look.
abstract final class NeonPalette {
  static const bgTop = Color(0xFF151A4A);
  static const bg = Color(0xFF0B0E2E);
  static const bgBottom = Color(0xFF060820);
  static const glass = Color(0x14FFFFFF);
  static const glassStrong = Color(0x24FFFFFF);
  static const card = Color(0xFF1B2160);
  static const cardRaised = Color(0xFF242B74);
  static const sunken = Color(0x40000000);
  static const stroke = Color(0x26FFFFFF);
  static const strokeStrong = Color(0x4DFFFFFF);
  static const text = Colors.white;
  static const textMuted = Color(0xFFB9BEE8);
  static const textFaint = Color(0xFF9097CC);
}

/// Raw colours of the flat app's light board-game look. The sky is a touch deeper than the
/// old #4FA3D1 so white titles (and the light muted text) on it pass 4.5:1.
abstract final class FlatPalette {
  static const sky = Color(0xFF266E9F);
  static const skyLight = Color(0xFF2872A4);
  static const skyDeep = Color(0xFF256B9B);
  static const board = Color(0xFF235F86);
  static const strip = Color(0xFF3A3846);
  static const ink = Color(0xFF22212B);
  static const inkMuted = Color(0xFF52586A);
  static const tile = Colors.white;
  static const tileShade = Color(0xFFD9DEE6);
  static const option = Color(0xFFE8EAEE);
  static const mark = Color(0x1FFFFFFF);
  static const close = Color(0xFFC9302C);
}

/// Status colours (both flavours).
abstract final class StatusColors {
  static const success = Color(0xFF2ECC71);
  static const warn = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5E5B);
  static const info = Color(0xFF2E8BFF);
}

/// Player identity: colour + shape, so nobody is told apart by colour alone. Picked to stay
/// apart for red-green colour blindness (blue/orange/green differ in lightness too).
abstract final class PlayerPalette {
  static const colors = [
    Color(0xFF3D8BFF), // blue
    Color(0xFFFF5A4F), // vermilion
    Color(0xFF16B886), // green
    Color(0xFFF5B400), // amber
    Color(0xFFA86CF0), // violet
    Color(0xFFF0629F), // pink
  ];
  static const shapes = [PlayerShape.circle, PlayerShape.triangle, PlayerShape.square, PlayerShape.diamond, PlayerShape.star, PlayerShape.hexagon];
  static const glyphs = ['●', '▲', '■', '◆', '★', '⬢'];

  static Color color(int i) => colors[i % colors.length];
  static PlayerShape shape(int i) => shapes[i % shapes.length];

  /// Seat index of a player colour, or null for a colour not in the palette.
  static int? indexOf(Color c) {
    final i = colors.indexWhere((x) => x.toARGB32() == c.toARGB32());
    return i < 0 ? null : i;
  }
}

enum PlayerShape { circle, triangle, square, diamond, star, hexagon }

/// WCAG relative luminance.
double luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// White or ink, whichever reads better on [bg].
Color onColor(Color bg) => contrast(Colors.white, bg) >= contrast(Brand.ink, bg) ? Colors.white : Brand.ink;

final _deepCache = <int, Color>{};

/// [c] darkened just enough for white text on it to pass 4.5:1 (for name chips, buttons).
Color fillFor(Color c) => _deepCache.putIfAbsent(c.toARGB32(), () {
      var hsl = HSLColor.fromColor(c.withValues(alpha: 1));
      while (contrast(Colors.white, hsl.toColor()) < 4.5 && hsl.lightness > 0.05) {
        hsl = hsl.withLightness(hsl.lightness - 0.02);
      }
      return hsl.toColor();
    });
