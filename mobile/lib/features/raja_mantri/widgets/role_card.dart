import 'dart:math';
import 'package:flutter/material.dart';
import '../rmcs_role.dart';

/// Every card is designed at this size and scaled to fit with a FittedBox.
const _cardW = 200.0, _cardH = 290.0;
const rmcsCardAspect = _cardW / _cardH;

/// A playing card that flips in 3D between its back and [role]'s face.
/// With [role] null the card can only show its back.
class RoleCard extends StatelessWidget {
  final RmcsRole? role;
  final bool faceUp;
  final bool highlight;
  final Color? highlightColor;
  final Duration duration;
  const RoleCard({super.key, required this.role, required this.faceUp, this.highlight = false, this.highlightColor, this.duration = const Duration(milliseconds: 650)});

  @override
  Widget build(BuildContext context) {
    final up = faceUp && role != null;
    return AspectRatio(
      aspectRatio: rmcsCardAspect,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: up ? 1 : 0),
        duration: duration,
        curve: Curves.easeInOutCubic,
        builder: (context, v, _) {
          final front = v > 0.5;
          // Lift the card a little mid-flip so it feels physical.
          final lift = 1 + 0.08 * sin(v * pi);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(v * pi)
              ..scaleByDouble(lift, lift, 1, 1),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(front ? pi : 0),
              child: _Frame(
                highlight: highlight,
                highlightColor: highlightColor ?? (front && role != null ? role!.glow : const Color(0xFFFFD34D)),
                child: FittedBox(child: front && role != null ? RoleCardFace(role: role!) : const RoleCardBack()),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  final Widget child;
  final bool highlight;
  final Color highlightColor;
  const _Frame({required this.child, required this.highlight, required this.highlightColor});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6)),
            if (highlight) BoxShadow(color: highlightColor.withValues(alpha: 0.85), blurRadius: 22, spreadRadius: 3),
          ],
        ),
        child: child,
      );
}

/// Face-down card: deep crimson with a gold lattice and the four roles in a medallion.
class RoleCardBack extends StatelessWidget {
  const RoleCardBack({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: _cardW,
        height: _cardH,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFFFFE28A), Color(0xFFC8901E), Color(0xFFFFE28A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const RadialGradient(colors: [Color(0xFF9E2747), Color(0xFF5A0F27)], radius: 0.9),
          ),
          child: CustomPaint(
            painter: const _LatticePainter(),
            child: Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A0B1F),
                  border: Border.all(color: const Color(0xFFFFD66B), width: 4),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                ),
                padding: const EdgeInsets.all(14),
                child: const FittedBox(
                  child: Column(children: [
                    Text('👑  🧠', style: TextStyle(fontSize: 26)),
                    SizedBox(height: 4),
                    Text('👮  🕵️', style: TextStyle(fontSize: 26)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x55FFD66B)
      ..strokeWidth = 1.4;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(13)));
    const step = 22.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), p);
    }
    canvas.restore();
    final inner = RRect.fromRectAndRadius(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), const Radius.circular(9));
    canvas.drawRRect(inner, Paint()
      ..color = const Color(0xAAFFD66B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Face-up card for [role]: themed colours, background pattern, emblem, corner indices.
class RoleCardFace extends StatelessWidget {
  final RmcsRole role;
  const RoleCardFace({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final metal = role == RmcsRole.raja
        ? const [Color(0xFFFFF4C2), Color(0xFFD99B16), Color(0xFFFFF0A8)]
        : role == RmcsRole.chor
            ? const [Color(0xFF7D5BA6), Color(0xFF241733), Color(0xFF7D5BA6)]
            : const [Color(0xFFF2F5FA), Color(0xFF9AA7BA), Color(0xFFF2F5FA)];
    final corner = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(role.letter, style: TextStyle(color: role.ink, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
      Text(role.emoji, style: const TextStyle(fontSize: 15)),
    ]);
    return Container(
      width: _cardW,
      height: _cardH,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: metal, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: LinearGradient(colors: role.gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: CustomPaint(
          painter: _PatternPainter(role),
          child: Stack(children: [
            Positioned(left: 10, top: 8, child: corner),
            Positioned(right: 10, bottom: 8, child: RotatedBox(quarterTurns: 2, child: corner)),
            Positioned.fill(
              top: 26,
              child: Column(children: [
                SizedBox(width: 128, height: 112, child: _Emblem(role)),
                const SizedBox(height: 6),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 172), child: FittedBox(fit: BoxFit.scaleDown, child: _Ribbon(role))),
                const SizedBox(height: 6),
                Text(role.subtitle, style: TextStyle(color: role.ink, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Text(role.pointsLine,
                      textAlign: TextAlign.center, style: TextStyle(color: role.ink.withValues(alpha: 0.85), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  final RmcsRole role;
  const _Ribbon(this.role);
  @override
  Widget build(BuildContext context) {
    final dark = role == RmcsRole.raja;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF5A3500) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: role.glow, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(role.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(role.title, style: TextStyle(color: dark ? const Color(0xFFFFE08A) : Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 3, height: 1.15)),
      ]),
    );
  }
}

class _Emblem extends StatelessWidget {
  final RmcsRole role;
  const _Emblem(this.role);
  @override
  Widget build(BuildContext context) {
    if (role == RmcsRole.mantri) {
      // Chess knight on a chequered medallion, with a brain badge.
      return Stack(alignment: Alignment.center, children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF13245E), border: Border.all(color: const Color(0xFF9BE1FF), width: 3)),
          child: const ClipOval(child: CustomPaint(painter: _ChessPainter())),
        ),
        const Text('♞', style: TextStyle(color: Colors.white, fontSize: 70, height: 1.1, shadows: [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 3))])),
        const Positioned(right: 4, top: 0, child: Text('🧠', style: TextStyle(fontSize: 30))),
      ]);
    }
    return CustomPaint(painter: _EmblemPainter(role));
  }
}

class _ChessPainter extends CustomPainter {
  const _ChessPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const n = 6;
    final s = size.width / n;
    final p = Paint()..color = const Color(0x332E9BFF);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if ((r + c).isEven) canvas.drawRect(Rect.fromLTWH(c * s, r * s, s, s), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Crown (Raja), shield (Sipahi) or thief's mask (Chor).
class _EmblemPainter extends CustomPainter {
  final RmcsRole role;
  _EmblemPainter(this.role);

  @override
  void paint(Canvas canvas, Size size) {
    switch (role) {
      case RmcsRole.raja:
        _crown(canvas, size);
      case RmcsRole.sipahi:
        _shield(canvas, size);
      case RmcsRole.chor:
        _mask(canvas, size);
      case RmcsRole.mantri:
        break;
    }
  }

  void _crown(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // Soft halo.
    canvas.drawCircle(Offset(w / 2, h * 0.55), h * 0.5, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.55), radius: h * 0.5)));
    final crown = Path()
      ..moveTo(w * 0.12, h * 0.82)
      ..lineTo(w * 0.06, h * 0.3)
      ..lineTo(w * 0.32, h * 0.55)
      ..lineTo(w * 0.5, h * 0.14)
      ..lineTo(w * 0.68, h * 0.55)
      ..lineTo(w * 0.94, h * 0.3)
      ..lineTo(w * 0.88, h * 0.82)
      ..close();
    final rect = Offset.zero & s;
    canvas.drawPath(crown, Paint()..shader = const LinearGradient(colors: [Color(0xFFFFF3B0), Color(0xFFFFC21A), Color(0xFFC98200)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(rect));
    final outline = Paint()
      ..color = const Color(0xFF6B3F00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(crown, outline);
    // Band.
    final band = RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.1, h * 0.74, w * 0.9, h * 0.92), const Radius.circular(4));
    canvas.drawRRect(band, Paint()..color = const Color(0xFFE09A00));
    canvas.drawRRect(band, outline);
    // Jewels.
    for (final (x, y, c) in [(0.06, 0.3, 0xFFFF3B5C), (0.5, 0.14, 0xFF3BD1FF), (0.94, 0.3, 0xFFFF3B5C)]) {
      canvas.drawCircle(Offset(w * x, h * y), 7, Paint()..color = Color(c));
      canvas.drawCircle(Offset(w * x, h * y), 7, outline..strokeWidth = 2.5);
    }
    for (final (x, c) in [(0.3, 0xFF2ECC71), (0.5, 0xFFFF3B5C), (0.7, 0xFF2ECC71)]) {
      canvas.drawCircle(Offset(w * x, h * 0.83), 5.5, Paint()..color = Color(c));
    }
    canvas.drawCircle(Offset(w * 0.5, h * 0.58), 8, Paint()..color = const Color(0xFFB0124A));
    canvas.drawCircle(Offset(w * 0.47, h * 0.55), 2.5, Paint()..color = Colors.white70);
  }

  void _shield(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    Path shield(double inset) => Path()
      ..moveTo(w * 0.2 + inset, h * 0.06 + inset)
      ..quadraticBezierTo(w * 0.5, h * 0.0 + inset, w * 0.8 - inset, h * 0.06 + inset)
      ..lineTo(w * 0.8 - inset, h * 0.48)
      ..quadraticBezierTo(w * 0.78 - inset, h * 0.8, w * 0.5, h * 0.98 - inset * 1.4)
      ..quadraticBezierTo(w * 0.22 + inset, h * 0.8, w * 0.2 + inset, h * 0.48)
      ..close();
    final rect = Offset.zero & s;
    final outer = shield(0);
    canvas.drawPath(outer.shift(const Offset(0, 4)), Paint()..color = Colors.black38);
    canvas.drawPath(outer, Paint()..shader = const LinearGradient(colors: [Color(0xFFF1F4F8), Color(0xFF8B99AD)], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect));
    final inner = shield(7);
    canvas.drawPath(inner, Paint()..shader = const LinearGradient(colors: [Color(0xFF2F6BD8), Color(0xFF15306B)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(rect));
    canvas.drawPath(outer, Paint()
      ..color = const Color(0xFF1B2433)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    // Badge star.
    final star = Path();
    final c = Offset(w * 0.5, h * 0.45);
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? h * 0.24 : h * 0.1;
      final a = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(a) * r, sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFD34D));
    canvas.drawPath(star, Paint()
      ..color = const Color(0xFF7A5200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  void _mask(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // Purple spotlight.
    canvas.drawCircle(Offset(w / 2, h * 0.5), h * 0.5, Paint()..shader = RadialGradient(colors: [const Color(0xFFB57BFF).withValues(alpha: 0.55), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.5), radius: h * 0.5)));
    // Hat brim and crown.
    final hat = Path()
      ..moveTo(w * 0.28, h * 0.32)
      ..quadraticBezierTo(w * 0.3, h * 0.04, w * 0.5, h * 0.06)
      ..quadraticBezierTo(w * 0.7, h * 0.04, w * 0.72, h * 0.32)
      ..close();
    canvas.drawPath(hat, Paint()..color = const Color(0xFF1A1424));
    canvas.drawRect(Rect.fromLTRB(w * 0.29, h * 0.25, w * 0.71, h * 0.31), Paint()..color = const Color(0xFF8E5BD8));
    canvas.drawOval(Rect.fromLTRB(w * 0.08, h * 0.28, w * 0.92, h * 0.42), Paint()..color = const Color(0xFF120D1A));
    // Domino mask with eye holes.
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(w * 0.06, h * 0.55)
      ..quadraticBezierTo(w * 0.1, h * 0.44, w * 0.3, h * 0.46)
      ..quadraticBezierTo(w * 0.5, h * 0.5, w * 0.7, h * 0.46)
      ..quadraticBezierTo(w * 0.9, h * 0.44, w * 0.94, h * 0.55)
      ..quadraticBezierTo(w * 0.9, h * 0.8, w * 0.68, h * 0.76)
      ..quadraticBezierTo(w * 0.55, h * 0.73, w * 0.5, h * 0.66)
      ..quadraticBezierTo(w * 0.45, h * 0.73, w * 0.32, h * 0.76)
      ..quadraticBezierTo(w * 0.1, h * 0.8, w * 0.06, h * 0.55)
      ..close()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.31, h * 0.6), width: w * 0.2, height: h * 0.12))
      ..addOval(Rect.fromCenter(center: Offset(w * 0.69, h * 0.6), width: w * 0.2, height: h * 0.12));
    canvas.drawPath(mask.shift(const Offset(0, 3)), Paint()..color = Colors.black54);
    canvas.drawPath(mask, Paint()..color = const Color(0xFF0B0810));
    canvas.drawPath(mask, Paint()
      ..color = const Color(0xFFB57BFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2);
    // Glinting eyes.
    for (final x in [0.31, 0.69]) {
      canvas.drawCircle(Offset(w * x, h * 0.6), 3.2, Paint()..color = const Color(0xFFEFFF6B));
    }
    // Mask ties.
    final tie = Paint()
      ..color = const Color(0xFF0B0810)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.06, h * 0.56), Offset(w * 0.0, h * 0.72), tie);
    canvas.drawLine(Offset(w * 0.94, h * 0.56), Offset(w * 1.0, h * 0.72), tie);
    // Loot bag.
    canvas.drawCircle(Offset(w * 0.5, h * 0.9), h * 0.09, Paint()..color = const Color(0xFF8A6A3A));
    final tp = TextPainter(text: const TextSpan(text: '₹', style: TextStyle(color: Color(0xFFFFE08A), fontSize: 13, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(w * 0.5 - tp.width / 2, h * 0.9 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.role != role;
}

/// Subtle per-role background: sunburst, chessboard, guard stripes, or night sky.
class _PatternPainter extends CustomPainter {
  final RmcsRole role;
  _PatternPainter(this.role);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(13)));
    final c = Offset(size.width / 2, size.height * 0.3);
    switch (role) {
      case RmcsRole.raja:
        final ray = Paint()..color = Colors.white.withValues(alpha: 0.18);
        for (var i = 0; i < 18; i++) {
          final a = i * 2 * pi / 18;
          canvas.drawPath(
              Path()
                ..moveTo(c.dx, c.dy)
                ..lineTo(c.dx + cos(a - 0.08) * 400, c.dy + sin(a - 0.08) * 400)
                ..lineTo(c.dx + cos(a + 0.08) * 400, c.dy + sin(a + 0.08) * 400)
                ..close(),
              ray);
        }
      case RmcsRole.mantri:
        const s = 25.0;
        final p = Paint()..color = Colors.white.withValues(alpha: 0.06);
        for (var y = 0.0; y < size.height; y += s) {
          for (var x = 0.0; x < size.width; x += s) {
            if (((x + y) / s).round().isEven) canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
          }
        }
      case RmcsRole.sipahi:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..strokeWidth = 9;
        for (var x = -size.height; x < size.width; x += 24) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
        }
      case RmcsRole.chor:
        final star = Paint()..color = Colors.white.withValues(alpha: 0.5);
        const pts = [(0.15, 0.1), (0.8, 0.14), (0.62, 0.05), (0.28, 0.28), (0.9, 0.42), (0.1, 0.55), (0.85, 0.8), (0.2, 0.88)];
        for (final (x, y) in pts) {
          canvas.drawCircle(Offset(size.width * x, size.height * y), 1.4, star);
        }
        canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.1), 10, Paint()..color = const Color(0x55FFF3B0));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.role != role;
}
