import 'package:flutter/material.dart';
import 'tokens.dart';

/// The Party Games mark: a dark carrom coin on marigold, holding four player pieces.
/// No text, no gradient, centred and readable at any size.
class PartyLogoPainter extends CustomPainter {
  /// Rounded tile (in-app) or full-bleed square (app icon, Android adaptive foreground).
  final bool rounded;

  /// How much of the tile the artwork fills; adaptive icons need it smaller.
  final double artScale;

  /// False paints only the coin, for Android's adaptive foreground layer.
  final bool background;
  const PartyLogoPainter({this.rounded = true, this.artScale = 1, this.background = true});

  static const ground = Brand.gold;
  static const coin = Color(0xFF211C16);

  static Path _shape(PlayerShape s, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    switch (s) {
      case PlayerShape.circle:
        return Path()..addOval(rect);
      case PlayerShape.roundedSquare:
        return Path()..addRRect(RRect.fromRectAndRadius(rect.deflate(r * 0.1), Radius.circular(r * 0.28)));
      case PlayerShape.diamond:
        return Path()
          ..moveTo(c.dx, c.dy - r * 1.1)
          ..lineTo(c.dx + r * 1.1, c.dy)
          ..lineTo(c.dx, c.dy + r * 1.1)
          ..lineTo(c.dx - r * 1.1, c.dy)
          ..close();
      case PlayerShape.triangle:
      case PlayerShape.star:
      case PlayerShape.hexagon:
        return Path()
          ..moveTo(c.dx, c.dy - r * 1.1)
          ..lineTo(c.dx + r * 1.1, c.dy + r * 0.8)
          ..lineTo(c.dx - r * 1.1, c.dy + r * 0.8)
          ..close();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s / 1024);
    const tile = Rect.fromLTWH(0, 0, 1024, 1024);
    if (background) {
      final p = Paint()..color = ground;
      rounded ? canvas.drawRRect(RRect.fromRectAndRadius(tile, const Radius.circular(232)), p) : canvas.drawRect(tile, p);
    }
    canvas.translate(512, 512);
    canvas.scale(artScale);
    canvas.translate(-512, -512);
    const c = Offset(512, 512);
    canvas.drawCircle(c + const Offset(0, 22), 370, Paint()..color = Brand.goldDeep);
    canvas.drawCircle(c, 370, Paint()..color = coin);
    canvas.drawCircle(
        c,
        318,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = const Color(0xFF4A4238));
    const pieces = [
      (PlayerShape.circle, Offset(392, 392), Color(0xFF2E8BFF)),
      (PlayerShape.diamond, Offset(632, 392), Color(0xFFFF8A1F)),
      (PlayerShape.triangle, Offset(392, 638), Color(0xFF2ECC71)),
      (PlayerShape.roundedSquare, Offset(632, 632), Color(0xFFFF5C8A)),
    ];
    for (final (shape, at, color) in pieces) {
      canvas.drawPath(_shape(shape, at, 92), Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PartyLogoPainter old) => old.rounded != rounded || old.artScale != artScale || old.background != background;
}

/// The logo as a widget.
class PartyLogoIcon extends StatelessWidget {
  final double size;
  const PartyLogoIcon({super.key, this.size = 120});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Party Games',
        image: true,
        child: SizedBox(width: size, height: size, child: const CustomPaint(painter: PartyLogoPainter())),
      );
}

/// The logo with the name under it.
class PartyLogoFull extends StatelessWidget {
  final double width;
  final String? fontFamily;
  const PartyLogoFull({super.key, this.width = 260, this.fontFamily});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PartyLogoIcon(size: width * 0.62),
          SizedBox(height: width * 0.06),
          FittedBox(child: Text('Party Games', style: TextStyle(fontFamily: fontFamily ?? Fonts.display, fontSize: width * 0.16, color: Theme.of(context).extension<ThemeExtension<dynamic>>() == null ? Colors.white : null))),
        ]),
      );
}
