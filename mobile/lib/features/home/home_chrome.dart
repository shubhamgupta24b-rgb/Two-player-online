import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/ui/tokens.dart';

/// Home colours from the dark/light lamp preview.
/// [blue] is the accent used by tabs and the primary mode button.
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

  static const dark = HomeColors(
    bg: Color(0xFF120F23),
    card: Color(0xFF1C1730),
    border: Color(0xFF382F5E),
    text: Color(0xFFF5F3EF),
    muted: Color(0xFFD2CDEA),
    tabIdle: Color(0xFFAAA4C4),
    gold: Color(0xFFF5C451),
    blue: Color(0xFFFF5C8A),
    online: Color(0xFF70C7A0),
    button: Color(0xFF251F40),
    buttonBorder: Color(0xFF382F5E),
    line: Color(0xFF382F5E),
    avatar: Color(0xFF2A1238),
    shadow: Color(0x40000000),
  );

  static const light = HomeColors(
    bg: Color(0xFFF5F2FC),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFD9D0F0),
    text: Color(0xFF1D1736),
    muted: Color(0xFF554D78),
    tabIdle: Color(0xFF756D98),
    gold: Color(0xFFF5C451),
    blue: Color(0xFFD6285F),
    online: Color(0xFF1FA855),
    button: Color(0xFFFFFFFF),
    buttonBorder: Color(0xFFD9D0F0),
    line: Color(0xFFD9D0F0),
    avatar: Color(0xFFFDE3EC),
    shadow: Color(0x1F462D8C),
  );

  static const connecting = Color(0xFFE0A100);
  static const offlineDot = Color(0xFF9A94AE);

  static HomeColors of(BuildContext context) => AppSettings.homeLight.value ? light : dark;

  BoxShadow get cardShadow => BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 3));
}

/// The hanging lamp from the home preview. Tap switches the saved home theme.
class HomeLampButton extends StatefulWidget {
  const HomeLampButton({super.key});

  @override
  State<HomeLampButton> createState() => _HomeLampButtonState();
}

class _HomeLampButtonState extends State<HomeLampButton> with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  void _toggle() {
    AppSettings.setHomeLight(!AppSettings.homeLight.value);
    if (!Motion.reduced(context)) {
      _swing.forward(from: 0);
    }
  }

  double _angle(double t) {
    if (t < 0.20) return 9 * (t / 0.20);
    if (t < 0.45) return 9 + (-6 - 9) * ((t - 0.20) / 0.25);
    if (t < 0.70) return -6 + (3 - -6) * ((t - 0.45) / 0.25);
    return 3 * (1 - ((t - 0.70) / 0.30));
  }

  @override
  Widget build(BuildContext context) {
    final lightOn = AppSettings.homeLight.value;
    return Semantics(
      button: true,
      toggled: lightOn,
      label: 'Switch between dark and light theme',
      child: GestureDetector(
        key: const Key('home-lamp'),
        onTap: _toggle,
        child: SizedBox(
          width: 70,
          height: 72,
          child: AnimatedBuilder(
            animation: _swing,
            builder: (context, child) {
              final degrees = _swing.isAnimating ? _angle(_swing.value) : 0.0;
              return Transform.rotate(alignment: Alignment.topCenter, angle: degrees * 3.1415926535 / 180, child: child);
            },
            child: CustomPaint(painter: _LampPainter(light: lightOn)),
          ),
        ),
      ),
    );
  }
}

class _LampPainter extends CustomPainter {
  final bool light;
  const _LampPainter({required this.light});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 70;
    final sy = size.height / 78;
    canvas.scale(sx, sy);
    final cord = Paint()
      ..color = const Color(0xFF8A8BA0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(35, 0), const Offset(35, 20), cord);
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF6D6), Color(0xE6FFC760), Color(0x00FF5C8A)],
        stops: [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: const Offset(35, 52), radius: 26));
    canvas.drawCircle(const Offset(35, 52), 26, glow);
    canvas.drawOval(Rect.fromCenter(center: const Offset(35, 48), width: 16, height: 18), Paint()..color = const Color(0xFFFFF6D6));
    final shade = Path()..moveTo(35, 16)..cubicTo(20, 16, 12, 30, 9, 42)..lineTo(61, 42)..cubicTo(58, 30, 50, 16, 35, 16)..close();
    final shadePaint = Paint()
      ..shader = LinearGradient(
        colors: light ? const [Color(0xFF6F63B0), Color(0xFF9A90E0), Color(0xFF5B509A)] : const [Color(0xFF3A3B43), Color(0xFF5A5B66), Color(0xFF2A2B31)],
      ).createShader(const Rect.fromLTWH(9, 16, 52, 26));
    canvas.drawPath(shade, shadePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(7, 40, 56, 4), const Radius.circular(2)), Paint()..color = const Color(0xFFFFCF3F));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(31, 12, 8, 6), const Radius.circular(2)), Paint()..color = const Color(0xFF8A8BA0));
  }

  @override
  bool shouldRepaint(covariant _LampPainter oldDelegate) => oldDelegate.light != light;
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
