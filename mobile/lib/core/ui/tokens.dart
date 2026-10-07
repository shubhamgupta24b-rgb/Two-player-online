import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Design tokens ("Party Night", docs/ui-redesign/UI_SPEC.md section 1): the raw scales every
/// screen is built from. Widgets read the flavour-aware set through `context.tokens` (see
/// app_theme_ext.dart); the consts here are for const constructors, painters and the
/// AppColors/FlatColors aliases.

/// Bundled font families (assets/fonts, OFL).
abstract final class Fonts {
  static const display = 'Lilita One'; // headings, scores, timers, announcements
  static const body = 'Nunito'; // everything else (600/700/800/900)
}

/// Spacing scale (dp).
abstract final class Space {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;

  /// Screen padding: 16 horizontal, 14 top, 22 bottom (plus SafeArea).
  static const screen = EdgeInsets.fromLTRB(16, 14, 16, 22);
}

/// Corner radii (dp). Spec: 6 tiles, 10 cards, 14 chips/banners, 18 player cards/buttons,
/// 24 boards/scene frames.
abstract final class Radii {
  static const double tile = 6, card = 10, chip = 14, button = 18, board = 24, pill = 999;
  // Older names, still used: sm 8 · md 12 · lg 16 · xl 24.
  static const double sm = 8, md = 12, lg = 16, xl = 24;
  static const rTile = BorderRadius.all(Radius.circular(tile));
  static const rCard = BorderRadius.all(Radius.circular(card));
  static const rChip = BorderRadius.all(Radius.circular(chip));
  static const rButton = BorderRadius.all(Radius.circular(button));
  static const rBoard = BorderRadius.all(Radius.circular(board));
  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
}

/// Shadows: small `0 4 10 rgba(0,0,0,0.35)`, large `0 14 34 rgba(0,0,0,0.5)`.
abstract final class Shadows {
  static const small = [BoxShadow(color: Color(0x59000000), blurRadius: 10, offset: Offset(0, 4))];
  static const large = [BoxShadow(color: Color(0x80000000), blurRadius: 34, offset: Offset(0, 14))];

  /// The darker "bottom edge" of a pressable thing (4–6 px), which sinks when pressed.
  static List<BoxShadow> edge(Color c, {double depth = 5}) => [BoxShadow(color: c, offset: Offset(0, depth))];
}

/// Durations and curves. Use [Motion.of] so "reduce motion" turns animations off.
abstract final class Motion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const standard = Curves.easeOutCubic;
  static const pop = Curves.easeOutBack;
  static const emphasized = Cubic(0.05, 0.7, 0.1, 1);

  /// True when the system or the app's own setting asks for less motion.
  static final reduceSetting = ValueNotifier<bool>(false);
  static bool reduced(BuildContext context) => reduceSetting.value || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Minimum touch target (dp).
const double kTouchTarget = 48;

/// The logo palette and the spec's shared accents (same in both flavours).
abstract final class Brand {
  static const navy = Color(0xFF14207A);
  static const night = Color(0xFF0A0F3D);
  static const deep = Color(0xFF060827);
  static const blue = Color(0xFF2E8BFF);
  static const red = Color(0xFFFF3B5C);
  static const gold = Color(0xFFFFC93C);
  static const goldDeep = Color(0xFFA87A12); // button bottom edge
  static const onGold = Color(0xFF1A1440); // text on gold
  static const purple = Color(0xFF7B4DFF);
  static const green = Color(0xFF2ECC71);
  static const ink = Color(0xFF1E1B3A); // dark text on white
  static const indigo = Color(0xFF3B2D9A); // hero cards, card backs
  static const indigoDeep = Color(0xFF1F1666);
  static const goldLine = Color(0xFFE9C46A); // gold hairlines and labels on indigo
}

/// Raw colours of the default "Party Night" look (spec 1.1, Night column).
abstract final class NeonPalette {
  static const bgTop = Color(0xFF151A4A);
  static const bg = Color(0xFF0B0E2E); // bgMid
  static const bgBottom = Color(0xFF060820);
  static const surface = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const surfaceStrong = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const stroke = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const overlay = Color(0xA80A0E28); // rgba(10,14,40,0.66)
  static const text = Colors.white;
  static const textMuted = Color(0xFFC3C9EE);
  static const label = Color(0xFFAAB2E8);
  static const sheet = Color(0xFF121640); // bottom sheets (Pause mockup)
  // Older names.
  static const glass = surface;
  static const glassStrong = surfaceStrong;
  static const card = Color(0xFF1B2160);
  static const cardRaised = Color(0xFF242B74);
  static const sunken = Color(0x40000000);
  static const strokeStrong = Color(0x38FFFFFF);
  static const textFaint = label;
}

/// Raw colours of the flat app (spec 1.1, Flat column, and section 7).
abstract final class FlatPalette {
  static const skyLight = Color(0xFF6BB8E0); // bgTop
  static const sky = Color(0xFF4FA3D1); // bgMid
  static const skyDeep = Color(0xFF4494C4); // bgBottom (spec #3E8FBF, lightened a touch so ink text passes 4.5:1)
  static const surface = Colors.white;
  static const surfaceStrong = Color(0xFFF2F5F9);
  static const stroke = Color(0xFFD9DEE6);
  static const overlay = Color(0xB822212B); // rgba(34,33,43,0.72)
  static const ink = Color(0xFF22212B); // text
  static const inkMuted = Color(0xFF4A5568); // textMuted
  static const label = Color(0xFF5A6478);
  static const board = Color(0xFF2B6488);
  static const strip = Color(0xFF3A3846);
  static const tile = Colors.white;
  static const tileShade = stroke;
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

/// Player identity (spec 1.2): colour + shape, always both. Each marker is the shape filled
/// with the colour and a 1.5 px white outline. [tints] are for names drawn on dark overlays.
abstract final class PlayerPalette {
  static const colors = [
    Color(0xFF2E8BFF), // 1 blue
    Color(0xFFFF8A1F), // 2 orange
    Color(0xFF2ECC71), // 3 green
    Color(0xFFB07CFF), // 4 purple
    Color(0xFFFF5C8A), // 5 pink
    Color(0xFFE0A800), // 6 yellow
  ];
  static const tints = [
    Color(0xFF9CC9FF),
    Color(0xFFFFD2A8),
    Color(0xFFB5F0CD),
    Color(0xFFDDC9FF),
    Color(0xFFFFC2D4),
    Color(0xFFFFE7A0),
  ];
  static const shapes = [PlayerShape.circle, PlayerShape.diamond, PlayerShape.triangle, PlayerShape.roundedSquare, PlayerShape.star, PlayerShape.hexagon];
  static const glyphs = ['●', '◆', '▲', '■', '★', '⬢']; // for plain-text exports only, never as UI icons

  static Color color(int i) => colors[i % colors.length];
  static Color tint(int i) => tints[i % tints.length];
  static PlayerShape shape(int i) => shapes[i % shapes.length];

  /// Seat index of a player colour, or null for a colour not in the palette.
  static int? indexOf(Color c) {
    final i = colors.indexWhere((x) => x.toARGB32() == c.toARGB32());
    return i < 0 ? null : i;
  }

  /// The light name tint for a player colour (white when it isn't a palette colour).
  static Color tintFor(Color c) {
    final i = indexOf(c);
    return i == null ? Colors.white : tints[i];
  }
}

enum PlayerShape { circle, diamond, triangle, roundedSquare, star, hexagon }

/// The shape of seat [index] (0-based).
PlayerShape playerShapeFor(int index) => PlayerPalette.shape(index);

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
Color onColor(Color bg) => contrast(Colors.white, bg) >= contrast(Brand.onGold, bg) ? Colors.white : Brand.onGold;

final _deepCache = <int, Color>{};

/// [c] darkened just enough for white text on it to pass 4.5:1 (for name chips, buttons).
Color fillFor(Color c) => _deepCache.putIfAbsent(c.toARGB32(), () {
      var hsl = HSLColor.fromColor(c.withValues(alpha: 1));
      while (contrast(Colors.white, hsl.toColor()) < 4.5 && hsl.lightness > 0.05) {
        hsl = hsl.withLightness(hsl.lightness - 0.02);
      }
      return hsl.toColor();
    });
