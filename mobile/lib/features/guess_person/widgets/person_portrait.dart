import 'dart:math';
import 'package:flutter/material.dart';
import '../models/person.dart';
import 'gp_theme.dart';

/// Cartoon portrait drawn from the person's attributes, so what you see always
/// matches the answers. Uses [Person.image] instead when that asset exists.
class PersonPortrait extends StatelessWidget {
  final Person person;
  const PersonPortrait(this.person, {super.key});

  @override
  Widget build(BuildContext context) {
    final drawn = CustomPaint(painter: _PortraitPainter(person), size: Size.infinite);
    final img = person.image;
    if (img == null) return drawn;
    return Image.asset(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => drawn);
  }
}

const _skin = {'light': Color(0xFFF6D2B4), 'tan': Color(0xFFD9A273), 'dark': Color(0xFF8D5A3B)};
const _hair = {'black': Color(0xFF2B2B2B), 'brown': Color(0xFF6B4226), 'blonde': Color(0xFFF2C94C), 'red': Color(0xFFC8501E)};
const _shirt = {'red': Color(0xFFE74C3C), 'blue': Color(0xFF3498DB), 'green': Color(0xFF27AE60), 'yellow': Color(0xFFF4D03F)};
const _gold = Color(0xFFFFB800);

class _PortraitPainter extends CustomPainter {
  final Person p;
  _PortraitPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    final dx = (size.width - s) / 2, dy = (size.height - s) / 2;
    Offset o(double x, double y) => Offset(dx + x * s, dy + y * s);
    Rect r(double l, double t, double rr, double b) => Rect.fromPoints(o(l, t), o(rr, b));
    Paint fill(Color c) => Paint()..color = c;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * s
      ..strokeCap = StrokeCap.round;

    final skin = _skin[p.skinTone] ?? _skin['light']!;
    final hair = _hair[p.hairColor] ?? Colors.grey;
    final shirt = _shirt[p.shirtColor] ?? Colors.grey;
    final female = p.gender == Gender.female;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fill(GpColors.portraitBgs[p.id % GpColors.portraitBgs.length]));

    // Long hair sits behind the head and falls to the shoulders.
    if (p.hasLongHair) canvas.drawRRect(RRect.fromRectAndRadius(r(0.25, 0.22, 0.75, 0.80), Radius.circular(0.16 * s)), fill(hair));

    // Shirt, neck, ears.
    canvas.drawRRect(RRect.fromRectAndCorners(r(0.14, 0.76, 0.86, 1.08), topLeft: Radius.circular(0.18 * s), topRight: Radius.circular(0.18 * s)), fill(shirt));
    canvas.drawRect(r(0.43, 0.60, 0.57, 0.79), fill(skin));
    canvas.drawPath(Path()..moveTo(o(0.43, 0.76).dx, o(0.43, 0.76).dy)..lineTo(o(0.5, 0.84).dx, o(0.5, 0.84).dy)..lineTo(o(0.57, 0.76).dx, o(0.57, 0.76).dy)..close(), fill(skin));
    canvas.drawCircle(o(0.30, 0.45), 0.045 * s, fill(skin));
    canvas.drawCircle(o(0.70, 0.45), 0.045 * s, fill(skin));

    // Head.
    canvas.drawOval(Rect.fromCenter(center: o(0.5, 0.43), width: 0.40 * s, height: 0.46 * s), fill(skin));

    // Top hair (also visible at the sides under a hat).
    canvas.drawArc(Rect.fromCenter(center: o(0.5, 0.37), width: 0.44 * s, height: 0.38 * s), pi, pi, true, fill(hair));
    if (p.hasLongHair) {
      canvas.drawRRect(RRect.fromRectAndRadius(r(0.27, 0.32, 0.33, 0.62), Radius.circular(0.03 * s)), fill(hair));
      canvas.drawRRect(RRect.fromRectAndRadius(r(0.67, 0.32, 0.73, 0.62), Radius.circular(0.03 * s)), fill(hair));
    }

    // Beard covers the lower face; the mouth is redrawn on top.
    if (p.hasBeard) {
      canvas.drawArc(Rect.fromCenter(center: o(0.5, 0.47), width: 0.41 * s, height: 0.50 * s), 0, pi, true, fill(hair));
      canvas.drawRRect(RRect.fromRectAndRadius(r(0.40, 0.505, 0.60, 0.545), Radius.circular(0.02 * s)), fill(hair));
    }

    // Eyebrows, eyes, lashes.
    final brow = Color.lerp(hair, Colors.black, 0.3)!;
    canvas.drawLine(o(0.385, 0.395), o(0.455, 0.39), stroke(brow, 0.018));
    canvas.drawLine(o(0.545, 0.39), o(0.615, 0.395), stroke(brow, 0.018));
    final eye = fill(const Color(0xFF1E1B3A));
    canvas.drawCircle(o(0.42, 0.445), 0.024 * s, eye);
    canvas.drawCircle(o(0.58, 0.445), 0.024 * s, eye);
    canvas.drawCircle(o(0.427, 0.438), 0.008 * s, fill(Colors.white));
    canvas.drawCircle(o(0.587, 0.438), 0.008 * s, fill(Colors.white));
    if (female) {
      final lash = stroke(const Color(0xFF1E1B3A), 0.010);
      canvas.drawLine(o(0.395, 0.432), o(0.375, 0.418), lash);
      canvas.drawLine(o(0.605, 0.432), o(0.625, 0.418), lash);
    }

    // Nose and mouth.
    canvas.drawArc(Rect.fromCenter(center: o(0.5, 0.49), width: 0.05 * s, height: 0.04 * s), 0.2, pi - 0.4, false, stroke(Color.lerp(skin, Colors.black, 0.35)!, 0.012));
    if (female) {
      canvas.drawArc(Rect.fromCenter(center: o(0.5, 0.555), width: 0.11 * s, height: 0.06 * s), 0.15, pi - 0.3, true, fill(const Color(0xFFD6455D)));
    } else {
      canvas.drawArc(Rect.fromCenter(center: o(0.5, 0.55), width: 0.11 * s, height: 0.06 * s), 0.2, pi - 0.4, false,
          stroke(p.hasBeard ? const Color(0xFFF3B7B7) : const Color(0xFF7A3B3B), 0.016));
    }

    // Cheeks.
    canvas.drawCircle(o(0.37, 0.51), 0.025 * s, fill(const Color(0x33FF5E5B)));
    canvas.drawCircle(o(0.63, 0.51), 0.025 * s, fill(const Color(0x33FF5E5B)));

    // Glasses: dark frames with a light lens tint so they read on every skin tone.
    if (p.hasGlasses) {
      final lens = fill(const Color(0x55FFFFFF));
      final frame = stroke(const Color(0xFF111111), 0.016);
      for (final x in [0.42, 0.58]) {
        canvas.drawCircle(o(x, 0.445), 0.058 * s, lens);
        canvas.drawCircle(o(x, 0.445), 0.058 * s, frame);
      }
      canvas.drawLine(o(0.478, 0.44), o(0.522, 0.44), frame);
      canvas.drawLine(o(0.362, 0.44), o(0.31, 0.43), frame);
      canvas.drawLine(o(0.638, 0.44), o(0.69, 0.43), frame);
    }

    // Hat.
    if (p.hasHat) {
      const hatColor = Color(0xFF5B2C83);
      canvas.drawRRect(RRect.fromRectAndRadius(r(0.31, 0.06, 0.69, 0.27), Radius.circular(0.07 * s)), fill(hatColor));
      canvas.drawRect(r(0.31, 0.20, 0.69, 0.245), fill(const Color(0xFFFFC93C)));
      canvas.drawRRect(RRect.fromRectAndRadius(r(0.22, 0.25, 0.78, 0.31), Radius.circular(0.03 * s)), fill(hatColor));
    }

    // Accessories.
    switch (p.accessory) {
      case 'earrings':
        canvas.drawCircle(o(0.30, 0.51), 0.022 * s, fill(_gold));
        canvas.drawCircle(o(0.70, 0.51), 0.022 * s, fill(_gold));
      case 'necklace':
        canvas.drawArc(Rect.fromCenter(center: o(0.5, 0.74), width: 0.22 * s, height: 0.16 * s), 0.1, pi - 0.2, false, stroke(_gold, 0.016));
        canvas.drawCircle(o(0.5, 0.82), 0.022 * s, fill(_gold));
      case 'bowtie':
        final bt = fill(const Color(0xFF1E1B3A));
        canvas.drawPath(Path()..moveTo(o(0.5, 0.81).dx, o(0.5, 0.81).dy)..lineTo(o(0.41, 0.77).dx, o(0.41, 0.77).dy)..lineTo(o(0.41, 0.85).dx, o(0.41, 0.85).dy)..close(), bt);
        canvas.drawPath(Path()..moveTo(o(0.5, 0.81).dx, o(0.5, 0.81).dy)..lineTo(o(0.59, 0.77).dx, o(0.59, 0.77).dy)..lineTo(o(0.59, 0.85).dx, o(0.59, 0.85).dy)..close(), bt);
        canvas.drawCircle(o(0.5, 0.81), 0.02 * s, bt);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.p.id != p.id;
}
