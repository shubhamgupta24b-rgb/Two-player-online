import 'package:flutter/material.dart';

import '../../core/ui/app_ui.dart';

/// Home-screen colours from `home-final.html`.
/// Night uses the reference surfaces. Flat keeps the same layout on light surfaces.
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

  static const night = HomeColors(
    bg: Color(0xFF0B0E2E),
    card: Color(0xFF151A45),
    border: Color(0xFF252B55),
    text: Color(0xFFF0F0F5),
    muted: Color(0xFFA0A8C0),
    tabIdle: Color(0xFF6B7280),
    gold: Color(0xFFFFC93C),
    blue: Color(0xFF2E8BFF),
    online: Color(0xFF3DDC97),
    button: Color(0xFF1A2148),
    buttonBorder: Color(0xFF2A3158),
    line: Color(0xFF1A1F3A),
    avatar: Color(0xFF1E2448),
    shadow: Color(0x33000000),
  );

  static const flat = HomeColors(
    bg: Color(0xFFF4F6F8),
    card: Colors.white,
    border: Color(0xFFD9DEE6),
    text: Color(0xFF1C1A17),
    muted: Color(0xFF4A5568),
    tabIdle: Color(0xFF5A6478),
    gold: Color(0xFFB8860B),
    blue: Color(0xFF2E8BFF),
    online: Color(0xFF1F8A4C),
    button: Colors.white,
    buttonBorder: Color(0xFFD9DEE6),
    line: Color(0xFFE4E0D8),
    avatar: Color(0xFFE8EAEE),
    shadow: Color(0x1A000000),
  );

  static HomeColors of(BuildContext context) => context.tk.flat ? flat : night;
}

/// Shared home measurements. Cards stay flat: one shadow level, no bevel.
abstract final class HomeMetrics {
  static const headerAvatar = 44.0;
  static const cardRadius = 18.0;
  static const gridGap = 10.0;
  static const gridPad = 16.0;
  static const imageAspect = 1.05;
  static const titleSize = 14.0;
  static const shadow = BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 2));
}
