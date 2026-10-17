import 'package:flutter/material.dart';

/// Home-screen colours from the lavender preview.
/// One solid background, white cards, purple for the active tab and primary button.
class HomeColors {
  final Color bg;
  final Color card;
  final Color border;
  final Color text;
  final Color muted;
  final Color tabIdle;
  final Color gold;
  final Color blue;
  final Color online;
  final Color button;
  final Color buttonBorder;
  final Color line;
  final Color avatar;
  final Color shadow;

  const HomeColors({
    required this.bg,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.tabIdle,
    required this.gold,
    required this.blue,
    required this.online,
    required this.button,
    required this.buttonBorder,
    required this.line,
    required this.avatar,
    required this.shadow,
  });

  static const lavender = HomeColors(
    bg: Color(0xFFF2EEFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE4DDF8),
    text: Color(0xFF24213A),
    muted: Color(0xFF77728E),
    tabIdle: Color(0xFF77728E),
    gold: Color(0xFFF5C451),
    blue: Color(0xFF8655F6),
    online: Color(0xFF3DDC97),
    button: Color(0xFFFFFFFF),
    buttonBorder: Color(0xFFE4DDF8),
    line: Color(0xFFDDD4F4),
    avatar: Color(0xFFDED0FF),
    shadow: Color(0x14673078),
  );

  static const connecting = Color(0xFFE0A100);
  static const offlineDot = Color(0xFF9A94AE);

  static HomeColors of(BuildContext context) => context.mounted ? lavender : lavender;
}

/// Shared home measurements. Cards stay flat: one shadow level, no bevel.
abstract final class HomeMetrics {
  static const headerAvatar = 44.0;
  static const cardRadius = 15.0;
  static const gridGap = 10.0;
  static const gridPad = 16.0;
  static const imageAspect = 1.1;
  static const titleSize = 12.0;
  static const shadow = BoxShadow(color: Color(0x14673078), blurRadius: 12, offset: Offset(0, 3));
}
