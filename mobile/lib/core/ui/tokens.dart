import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Design tokens ("The floor after dinner", docs/design-system.md): the raw scales every
/// screen is built from. Widgets read the flavour-aware set through `context.tokens` (see
/// app_theme_ext.dart); the consts here are for const constructors, painters and the
/// AppColors/FlatColors aliases.

/// Bundled font families (assets/fonts, OFL).
abstract final class Fonts {
  static const display = 'Bricolage Grotesque'; // expressive titles and game scores
  static const body = 'DM Sans'; // readable labels, controls and body text
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
  static const double tile = 6, card = 12, chip = 12, button = 14, board = 20, pill = 999;
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
  static List<BoxShadow> edge(Color c, {double depth = 3}) => [BoxShadow(color: c, offset: Offset(0, depth))];
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
  static const navy = Color(0xFF2A2723); // raised warm neutral (kept name: used across games)
  static const night = Color(0xFF1E1C19);
  static const deep = Color(0xFF161513);
  static const blue = Color(0xFF2E8BFF);
  static const red = Color(0xFFE5484D);
  static const gold = Color(0xFFF6A91B); // marigold: the one accent
  static const goldDeep = Color(0xFFB87708); // button bottom edge
  static const onGold = Color(0xFF2A1C05); // text on marigold
  static const purple = Color(0xFF8E6BE0);
  static const green = Color(0xFF3FB37A);
  static const ink = Color(0xFF211C16); // dark text on light
  static const indigo = Color(0xFF2A2723); // hero cards, card backs
  static const indigoDeep = Color(0xFF1E1C19);
  static const goldLine = Color(0xFFE8B65A); // marigold hairlines and labels on dark
}

/// Raw colours of the dark look.
abstract final class NeonPalette {
  static const bgTop = Color(0xFF161513);
  static const bg = Color(0xFF161513);
  static const bgBottom = Color(0xFF161513);
  static const surface = Color(0x0FFFF5E6);
  static const surfaceStrong = Color(0x1AFFF5E6);
  static const stroke = Color(0x1AFFF5E6);
  static const overlay = Color(0xB3161513);
  static const text = Color(0xFFF5EFE4);
  static const textMuted = Color(0xFFC0B8AA);
  static const label = Color(0xFFA89F91);
  static const sheet = Color(0xFF1E1C19);
  // Older names.
  static const glass = surface;
  static const glassStrong = surfaceStrong;
  static const card = Color(0xFF211F1B);
  static const cardRaised = Color(0xFF2B2824);
  static const sunken = Color(0x40000000);
  static const strokeStrong = Color(0x33FFF5E6);
  static const textFaint = label;
}

/// Raw colours of the light look (the name is historical: `t.flat` means light).
abstract final class FlatPalette {
  static const skyLight = Color(0xFFF6F2EA);
  static const sky = Color(0xFFF6F2EA);
  static const skyDeep = Color(0xFFF6F2EA);
  static const surface = Color(0xFFFFFDF9);
  static const surfaceStrong = Color(0xFFEEE8DC);
  static const stroke = Color(0xFFE2DBCE);
  static const overlay = Color(0xB8211C16);
  static const ink = Color(0xFF211C16); // text
  static const inkMuted = Color(0xFF5E554A); // textMuted
  static const label = Color(0xFF6B6256);
  static const board = Color(0xFF3A342C);
  static const strip = Color(0xFF2C2721);
  static const tile = Color(0xFFFFFDF9);
  static const tileShade = stroke;
  static const option = Color(0xFFEEE8DC);
  static const mark = Color(0x00FFFFFF);
  static const close = Color(0xFFC6383D);
}

/// Status colours (both flavours).
abstract final class StatusColors {
  static const success = Color(0xFF4CC38A);
  static const warn = Color(0xFFF2A63B);
  static const danger = Color(0xFFEF6A6E);
  static const info = Color(0xFF5AA2F0);
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
