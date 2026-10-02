import 'dart:math';
import 'package:flutter/material.dart';

/// The Party Games app icon, drawn in code so it is sharp at any size:
/// a party gamepad (four buttons in the player colours) wearing a gold crown,
/// with confetti on a navy-to-purple tile.
class PartyLogoPainter extends CustomPainter {
  /// Rounded tile (app icon) or full-bleed square (Android adaptive foreground).
  final bool rounded;

  /// How much of the tile the artwork fills; adaptive icons need it smaller.
  final double artScale;
  const PartyLogoPainter({this.rounded = true, this.artScale = 1});

  static const _blue = Color(0xFF4D96FF), _green = Color(0xFF2ECC71), _yellow = Color(0xFFFFD43B), _purple = Color(0xFFA855F7);
  static const _ink = Color(0xFF2A0B3D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final tile = Rect.fromLTWH(0, 0, s, s);
    final shape = rounded ? RRect.fromRectAndRadius(tile, Radius.circular(s * 0.22)) : RRect.fromRectXY(tile, 0, 0);

    canvas.save();
    canvas.clipRRect(shape);
    _background(canvas, s, tile);
    // Artwork, scaled around the centre.
    canvas.translate(s / 2, s / 2);
    canvas.scale(artScale);
    canvas.translate(-s / 2, -s / 2);
    _confetti(canvas, s);
    _gamepad(canvas, s);
    _crown(canvas, s);
    _sparkles(canvas, s);
    canvas.restore();

    if (rounded) {
      canvas.drawRRect(shape.deflate(s * 0.006), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = Colors.white.withValues(alpha: 0.14));
    }
  }

  void _background(Canvas canvas, double s, Rect tile) {
    canvas.drawRect(tile, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A1FA8), Color(0xFF1A1470), Color(0xFF0A0B3A)]).createShader(tile));
    void glow(Offset c, double r, Color color, double a) =>
        canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: a), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    glow(Offset(s * 0.5, s * 0.45), s * 0.55, const Color(0xFFFF4FA3), 0.38);
    glow(Offset(s * 0.1, s * 0.95), s * 0.5, const Color(0xFF2E8BFF), 0.35);
    glow(Offset(s * 0.95, s * 0.05), s * 0.4, const Color(0xFFFFC93C), 0.18);
    // Soft sunburst behind the gamepad.
    final ray = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final c = Offset(s * 0.5, s * 0.5);
    for (var i = 0; i < 16; i++) {
      final a = i * 2 * pi / 16;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + cos(a - 0.09) * s, c.dy + sin(a - 0.09) * s)
            ..lineTo(c.dx + cos(a + 0.09) * s, c.dy + sin(a + 0.09) * s)
            ..close(),
          ray);
    }
  }

  void _confetti(Canvas canvas, double s) {
    // (x, y, size, angle, colour, isCircle)
    const bits = [
      (0.14, 0.2, 0.05, 0.5, _yellow, false),
      (0.86, 0.24, 0.045, -0.4, _green, false),
      (0.1, 0.5, 0.03, 0.0, _blue, true),
      (0.9, 0.52, 0.035, 0.0, Color(0xFFFF5E7E), true),
      (0.2, 0.86, 0.045, -0.6, _purple, false),
      (0.82, 0.86, 0.05, 0.8, _yellow, false),
      (0.5, 0.9, 0.025, 0.0, _green, true),
      (0.3, 0.12, 0.025, 0.0, Color(0xFFFF5E7E), true),
      (0.72, 0.1, 0.04, 1.1, _blue, false),
    ];
    for (final (x, y, z, a, color, circle) in bits) {
      final p = Paint()..color = color;
      if (circle) {
        canvas.drawCircle(Offset(s * x, s * y), s * z / 2, p);
      } else {
        canvas.save();
        canvas.translate(s * x, s * y);
        canvas.rotate(a);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s * z, height: s * z * 0.45), Radius.circular(s * 0.006)), p);
        canvas.restore();
      }
    }
  }

  Path _padShape(double s) {
    final body = Path()..addRRect(RRect.fromLTRBR(s * 0.13, s * 0.4, s * 0.87, s * 0.68, Radius.circular(s * 0.13)));
    final grips = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.255, s * 0.665), radius: s * 0.125))
      ..addOval(Rect.fromCircle(center: Offset(s * 0.745, s * 0.665), radius: s * 0.125));
    return Path.combine(PathOperation.union, body, grips);
  }

  void _gamepad(Canvas canvas, double s) {
    final pad = _padShape(s);
    final bounds = pad.getBounds();
    // Drop shadow.
    canvas.drawPath(pad.shift(Offset(0, s * 0.03)), Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02));
    // Body.
    canvas.drawPath(pad, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF6B7A), Color(0xFFFF4757), Color(0xFFE8335C)]).createShader(bounds));
    // Gloss on the top half.
    canvas.save();
    canvas.clipPath(pad);
    canvas.drawRRect(RRect.fromLTRBR(s * 0.16, s * 0.415, s * 0.84, s * 0.5, Radius.circular(s * 0.06)), Paint()..color = Colors.white.withValues(alpha: 0.22));
    // Darker underside.
    canvas.drawRect(Rect.fromLTRB(0, s * 0.68, s, s), Paint()..color = const Color(0xFF9E1F4A).withValues(alpha: 0.35));
    canvas.restore();
    canvas.drawPath(pad, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeJoin = StrokeJoin.round
      ..color = _ink);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..color = _ink;
    // D-pad.
    final dc = Offset(s * 0.3, s * 0.54);
    final arm = s * 0.062, thick = s * 0.052;
    final cross = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: dc, width: arm * 2 + thick * 0.1, height: thick), Radius.circular(s * 0.012))),
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: dc, width: thick, height: arm * 2 + thick * 0.1), Radius.circular(s * 0.012))),
    );
    canvas.drawPath(cross, Paint()..color = Colors.white);
    canvas.drawPath(cross, outline);
    canvas.drawCircle(dc, s * 0.012, Paint()..color = const Color(0xFFDADDF0));

    // Four buttons, one per player colour.
    final bc = Offset(s * 0.7, s * 0.54);
    final d = s * 0.058, r = s * 0.033;
    for (final (o, color) in [(Offset(0, -d), _yellow), (Offset(d, 0), _green), (Offset(0, d), _blue), (Offset(-d, 0), _purple)]) {
      final c = bc + o;
      canvas.drawCircle(c, r, Paint()..color = color);
      canvas.drawCircle(c, r, outline);
      canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.35), r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
    // Start/select pills.
    for (final x in [0.455, 0.545]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * x, s * 0.5), width: s * 0.06, height: s * 0.024), Radius.circular(s * 0.012)), Paint()..color = _ink.withValues(alpha: 0.75));
    }
    // Speaker smile between the sticks.
    canvas.drawArc(Rect.fromCenter(center: Offset(s * 0.5, s * 0.565), width: s * 0.1, height: s * 0.06), 0.2, pi - 0.4, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.75));
  }

  void _crown(Canvas canvas, double s) {
    canvas.save();
    canvas.translate(s * 0.5, s * 0.31);
    canvas.rotate(-0.1);
    final w = s * 0.34, h = s * 0.2;
    final crown = Path()
      ..moveTo(-w * 0.42, h * 0.5)
      ..lineTo(-w * 0.5, -h * 0.32)
      ..lineTo(-w * 0.22, h * 0.02)
      ..lineTo(0, -h * 0.5)
      ..lineTo(w * 0.22, h * 0.02)
      ..lineTo(w * 0.5, -h * 0.32)
      ..lineTo(w * 0.42, h * 0.5)
      ..close();
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawPath(crown.shift(Offset(0, s * 0.015)), Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012));
    canvas.drawPath(crown, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF1A6), Color(0xFFFFC52E), Color(0xFFE09400)]).createShader(rect));
    final band = RRect.fromRectAndRadius(Rect.fromLTRB(-w * 0.44, h * 0.3, w * 0.44, h * 0.56), Radius.circular(s * 0.01));
    canvas.drawRRect(band, Paint()..color = const Color(0xFFE59E00));
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF5A2E00);
    canvas.drawPath(crown, outline);
    canvas.drawRRect(band, outline..strokeWidth = s * 0.012);
    for (final (x, y, c) in [(-0.5, -0.32, 0xFFFF4757), (0.0, -0.5, 0xFF4D96FF), (0.5, -0.32, 0xFF2ECC71)]) {
      final p = Offset(w * x, h * y);
      canvas.drawCircle(p, s * 0.022, Paint()..color = Color(c));
      canvas.drawCircle(p, s * 0.022, outline..strokeWidth = s * 0.01);
    }
    canvas.drawCircle(Offset(0, h * 0.43), s * 0.016, Paint()..color = const Color(0xFFFF4757));
    // Shine.
    canvas.drawLine(Offset(-w * 0.3, -h * 0.02), Offset(-w * 0.36, h * 0.22), Paint()
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.7));
    canvas.restore();
  }

  void _sparkles(Canvas canvas, double s) {
    void star(Offset c, double r) {
      final p = Path();
      for (var i = 0; i < 8; i++) {
        final a = -pi / 2 + i * pi / 4;
        final rr = i.isEven ? r : r * 0.28;
        final pt = c + Offset(cos(a) * rr, sin(a) * rr);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(p..close(), Paint()..color = Colors.white);
    }

    star(Offset(s * 0.77, s * 0.27), s * 0.045);
    star(Offset(s * 0.22, s * 0.32), s * 0.03);
    star(Offset(s * 0.6, s * 0.8), s * 0.028);
  }

  @override
  bool shouldRepaint(PartyLogoPainter old) => old.rounded != rounded || old.artScale != artScale;
}

/// Just the icon tile.
class PartyLogoIcon extends StatelessWidget {
  final double size;
  const PartyLogoIcon({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Party Games',
        child: SizedBox(width: size, height: size, child: const CustomPaint(painter: PartyLogoPainter())),
      );
}

/// Icon plus the PARTY GAMES wordmark, for the splash and login screens.
class PartyLogoFull extends StatelessWidget {
  final double width;
  final String? fontFamily; // only for rendering previews outside the app
  const PartyLogoFull({super.key, this.width = 260, this.fontFamily});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Party Games',
        child: ExcludeSemantics(
          child: SizedBox(
            width: width,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PartyLogoIcon(size: width * 0.62),
              SizedBox(height: 10 * width / 260),
              PartyWordmark(width: width, fontFamily: fontFamily),
            ]),
          ),
        ),
      );
}

/// "PARTY GAMES" in chunky outlined letters with the players pill underneath.
class PartyWordmark extends StatelessWidget {
  final double width;
  final String? fontFamily;
  const PartyWordmark({super.key, this.width = 260, this.fontFamily});

  @override
  Widget build(BuildContext context) {
    final f = width / 260;
    TextStyle word(Color fill) => TextStyle(fontFamily: fontFamily, fontSize: 46 * f, height: 1, fontWeight: FontWeight.w900, letterSpacing: 1.5 * f, color: fill, shadows: [Shadow(color: const Color(0xFFE8335C), offset: Offset(0, 4 * f))]);
    TextStyle stroke() => TextStyle(
        fontFamily: fontFamily,
        fontSize: 46 * f,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5 * f,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * f
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF2A0B3D));
    Widget outlined(String t, Color fill) => Stack(children: [Text(t, style: stroke()), Text(t, style: word(fill))]);
    return Semantics(
      label: 'Party Games',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                outlined('PARTY', Colors.white),
                SizedBox(width: 12 * f),
                outlined('GAMES', const Color(0xFFFFC93C)),
              ]),
            ),
            SizedBox(height: 10 * f),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * f, vertical: 5 * f),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B4DFF), Color(0xFF4D2BD6)]),
                borderRadius: BorderRadius.circular(20 * f),
                border: Border.all(color: Colors.white24, width: 1.5 * f),
              ),
              child: Text('★  2–6 PLAYERS  ★', style: TextStyle(fontFamily: fontFamily, color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13 * f, letterSpacing: 2 * f)),
            ),
          ]),
        ),
      ),
    );
  }
}
