import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';

/// A painted preview for every game: one real moment of play on its own colour field. These
/// carry nearly all the colour in the app, so the screens around them stay neutral.
///
/// Each scene is drawn on a 100 x 100 grid that covers the canvas, so wide tiles crop the top
/// and bottom. Keep the important part between y 18 and y 82.
void paintGamePreview(Canvas canvas, Size size, String id) {
  final scale = math.max(size.width, size.height) / 100;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.translate(size.width / 2, size.height / 2);
  canvas.scale(scale);
  canvas.translate(-50, -50);
  final s = _Scene(canvas);
  final scene = _scenes[id] ?? _scenes[_baseOf(id)] ?? _fallback;
  scene(s);
  canvas.restore();
}

String _baseOf(String id) => _scenes.keys.firstWhere(id.startsWith, orElse: () => '');

void _fallback(_Scene s) {
  s.bg(0xFF3A342C);
  s.icon(GameIcons.star, 34, 34, 32, 0xFFF6A91B);
}

const _cream = 0xFFFBF3E2;
const _ink = 0xFF2A1C05;
const _marigold = 0xFFF6A91B;
const _red = 0xFFD9423D;
const _blue = 0xFF2E7FD9;
const _green = 0xFF2FA866;
const _pink = 0xFFEF6C92;

class _Scene {
  final Canvas c;
  _Scene(this.c);
  Paint _p(int color) => Paint()..color = Color(color);

  void bg(int color) => c.drawRect(const Rect.fromLTWH(-200, -200, 500, 500), _p(color));
  void rect(double x, double y, double w, double h, int color, [double r = 0]) => c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), _p(color));
  void dot(double x, double y, double r, int color) => c.drawCircle(Offset(x, y), r, _p(color));
  void oval(double x, double y, double rx, double ry, int color) => c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), _p(color));
  void line(double x1, double y1, double x2, double y2, int color, double w) => c.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      _p(color)
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round);
  void ring(double x, double y, double r, int color, double w) => c.drawCircle(
      Offset(x, y),
      r,
      _p(color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w);
  void poly(List<double> xy, int color) {
    final p = Path()..moveTo(xy[0], xy[1]);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      p.lineTo(xy[i], xy[i + 1]);
    }
    c.drawPath(p..close(), _p(color));
  }

  void svg(String d, int color) => c.drawPath(svgPath(d), _p(color));
  void stroke(String d, int color, double w) => c.drawPath(
      svgPath(d),
      _p(color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
  void icon(GameIcons i, double x, double y, double size, [int color = _cream]) => paintIcon(c, i, Rect.fromLTWH(x, y, size, size), color: Color(color));
  void shadow(double x, double y, double rx, double ry, [double alpha = 0.22]) => c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), Paint()..color = Colors.black.withValues(alpha: alpha));

  void text(String t, double cx, double cy, double size, int color, {bool display = true}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: display ? Fonts.display : Fonts.body, fontSize: size, height: 1, color: Color(color), fontWeight: display ? FontWeight.w400 : FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void at(double x, double y, double angle, void Function() draw) {
    c.save();
    c.translate(x, y);
    c.rotate(angle);
    draw();
    c.restore();
  }

  /// A player piece: a carrom-cut shape with a contact shadow.
  void piece(int seat, double x, double y, double size) {
    final r = Rect.fromCenter(center: Offset(x, y), width: size, height: size);
    final path = PlayerShapePainter.pathFor(PlayerPalette.shape(seat), r);
    c.drawPath(path.shift(Offset(0, size * 0.1)), Paint()..color = Colors.black.withValues(alpha: 0.3));
    c.drawPath(path, Paint()..color = PlayerPalette.color(seat));
    c.drawPath(
        PlayerShapePainter.pathFor(PlayerPalette.shape(seat), r.deflate(size * 0.2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.05
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(PlayerPalette.color(seat), Colors.black, 0.25)!);
  }

  /// A centred card, turned by [a], with an optional face.
  void card(double x, double y, double w, double h, double a, int color, [void Function()? face]) {
    at(x, y, a, () {
      rect(-w / 2 + 0.5, -h / 2 + 1.4, w, h, 0x40000000, w * 0.14);
      rect(-w / 2, -h / 2, w, h, color, w * 0.14);
      face?.call();
    });
  }

  void person(double x, double y, double k, int color) {
    dot(x, y - 7 * k, 5 * k, color);
    svg('M${x - 9 * k} ${y + 12 * k}c0-8 ${4 * k}-${13 * k} ${9 * k}-${13 * k}s${9 * k} ${5 * k} ${9 * k} ${13 * k}z', color);
  }

  void die(double x, double y, double size, double a, int pips) {
    at(x, y, a, () {
      final h = size / 2;
      rect(-h, -h + size * .08, size, size, 0xFFD8CBB2, size * .22);
      rect(-h, -h, size, size, _cream, size * .22);
      const layouts = {
        1: [(0.0, 0.0)],
        2: [(-1.0, -1.0), (1.0, 1.0)],
        3: [(-1.0, -1.0), (0.0, 0.0), (1.0, 1.0)],
        4: [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)],
        5: [(-1.0, -1.0), (1.0, -1.0), (0.0, 0.0), (-1.0, 1.0), (1.0, 1.0)],
        6: [(-1.0, -1.0), (1.0, -1.0), (-1.0, 0.0), (1.0, 0.0), (-1.0, 1.0), (1.0, 1.0)],
      };
      for (final (px, py) in layouts[pips]!) {
        dot(px * size * .26, py * size * .26, size * .09, _ink);
      }
    });
  }
}

final Map<String, void Function(_Scene)> _scenes = {
  // ---- Party
  'guess_person': (s) {
    s.bg(0xFF2E6F8E);
    const skins = [0xFFE5B28A, 0xFFB57A4E, 0xFFF0CDA9, 0xFF8A5A36];
    const hair = [0xFF2A1C05, 0xFF8C4A1C, 0xFFD9A441, 0xFF3E3A36];
    var n = 0;
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 3; x++) {
        final cx = 22 + x * 28.0, cy = 34 + y * 32.0, i = n++ % 4, down = n == 2 || n == 6;
        s.rect(cx - 12, cy - 13, 24, 28, down ? 0xFF1F4D63 : _cream, 3);
        if (!down) {
          s.oval(cx, cy + 16, 8, 8, 0xFF4E8FB0);
          s.dot(cx, cy + 1, 7, skins[i]);
          s.svg('M${cx - 7} ${cy + 1}a7 7 0 0 1 14 0c-3-3-11-3-14 0z', hair[i]);
          s.dot(cx - 2.4, cy + 2, .8, _ink);
          s.dot(cx + 2.4, cy + 2, .8, _ink);
        }
      }
    }
    s.rect(6, 75, 88, 30, 0xFF2E6F8E);
    s.icon(GameIcons.magnifier, 58, 40, 30);
  },
  'guess_who': (s) => _scenes['guess_person']!(s),
  'raja_mantri': (s) {
    s.bg(0xFF8A1C3A);
    for (final (x, a, face) in const [(24.0, -.3, 0), (41.0, -.1, 1), (59.0, .1, 2)]) {
      s.card(x, 52, 26, 36, a, 0xFFE9DCC2, () {
        s.line(-8, -8 + face * 3.0, 8, -8 + face * 3.0, 0xFFB7A684, 1.2);
        s.line(-8, 4, 8, 4, 0xFFB7A684, 1.2);
        s.line(-8, 10, 4, 10, 0xFFB7A684, 1.2);
      });
    }
    s.card(74, 48, 30, 42, .22, _cream, () {
      s.icon(GameIcons.crown, -11, -16, 22);
      s.text('RAJA', 0, 12, 7, 0xFF8A1C3A);
    });
  },
  'find_spy': (s) {
    s.bg(0xFF23303D);
    s.dot(50, 32, 40, 0xFF2F4152);
    for (final (x, k) in const [(20.0, .95), (40.0, 1.0), (80.0, .95)]) {
      s.person(x, 58, k * 1.25, 0xFF5D7286);
    }
    s.person(60, 56, 1.35, _ink);
    s.rect(50, 40, 20, 3, _ink, 1);
    s.svg('M53 40l2-8h10l2 8z', _ink);
    s.rect(53.5, 46.5, 5.5, 2.8, _marigold, 1);
    s.rect(61, 46.5, 5.5, 2.8, _marigold, 1);
    s.icon(GameIcons.magnifier, 4, 16, 28);
  },
  'undercover': (s) {
    s.bg(0xFF4A2F73);
    s.card(26, 40, 40, 26, -.14, _cream, () {
      s.text('Mango', 0, 0, 7, _ink);
    });
    s.card(40, 62, 40, 26, .08, _cream, () {
      s.text('Mango', 0, 0, 7, _ink);
    });
    s.card(74, 48, 40, 26, .16, _marigold, () {
      s.text('Papaya', 0, 0, 7, _ink);
    });
  },
  'mafia': (s) {
    s.bg(0xFF1A2340);
    s.dot(74, 30, 15, 0xFFF5E2A6);
    s.dot(67, 26, 13, 0xFF1A2340);
    for (final (x, y) in const [(14.0, 22.0), (28.0, 34.0), (46.0, 20.0), (88.0, 56.0), (34.0, 14.0)]) {
      s.dot(x, y, .8, _cream);
    }
    s.rect(-5, 72, 110, 40, 0xFF0F1528);
    for (final (x, w, h) in const [(8.0, 16.0, 26.0), (26.0, 13.0, 18.0), (41.0, 18.0, 32.0), (62.0, 14.0, 22.0), (78.0, 18.0, 30.0)]) {
      s.rect(x, 74 - h, w, h, 0xFF0F1528);
    }
    s.rect(46, 50, 4, 5, _marigold);
    s.rect(14, 56, 3.5, 4.5, _marigold);
    s.rect(84, 52, 4, 5, _marigold);
    s.person(66, 76, 1, 0xFF05070F);
  },
  'charades': (s) {
    s.bg(0xFFD9542B);
    s.oval(50, 88, 34, 6, 0xFFB0401F);
    s.dot(50, 34, 8, _cream);
    s.stroke('M50 42v22M50 64 40 84M50 64l10 20M50 48 32 34M50 48l18-14', _cream, 5);
    s.icon(GameIcons.clapper, 72, 58, 20);
    s.rect(14, 26, 12, 3, _cream, 1.5);
    s.at(20, 27, .7, () => s.rect(-6, -1.5, 12, 3, _cream, 1.5));
  },
  'draw_guess': (s) {
    s.bg(0xFF2F9E8F);
    s.card(46, 50, 62, 50, -.04, _cream, () {
      s.stroke('M-20 8c6-16 14-16 18-2s12 12 20-4', _red, 2.4);
      s.dot(-20, 8, 2.8, _ink);
      s.stroke('M-16 12l-4 6M-8 10l-2 8', _ink, 1.6);
    });
    s.at(76, 62, .7, () {
      s.rect(-4, -22, 8, 34, _marigold, 1.4);
      s.poly([-4, 12, 4, 12, 0, 20], _ink);
      s.rect(-4, -24, 8, 5, _red, 1.4);
    });
  },
  'heads_up': (s) {
    s.bg(0xFFEBB02F);
    s.dot(50, 70, 24, 0xFFB57A4E);
    s.svg('M26 66a24 24 0 0 1 48 0c-8-9-40-9-48 0z', _ink);
    s.dot(41, 74, 2, _ink);
    s.dot(59, 74, 2, _ink);
    s.stroke('M44 84c4 3 8 3 12 0', _ink, 1.8);
    s.at(50, 34, -.03, () {
      s.rect(-24, -14, 48, 28, _ink, 4);
      s.rect(-21.5, -11.5, 43, 23, _cream, 2);
      s.text('Tiger', 0, 0, 10, _ink);
    });
  },
  'quiz_battle': (s) {
    s.bg(0xFF3F4FB5);
    s.oval(50, 76, 34, 8, 0xFF2E3B8F);
    s.rect(24, 58, 52, 18, 0xFF22296B, 4);
    s.svg('M30 58a20 22 0 0 1 40 0z', _red);
    s.svg('M34 52a16 14 0 0 1 16-14', 0x55FFFFFF);
    s.icon(GameIcons.bolt, 12, 18, 18, _marigold);
    s.icon(GameIcons.bolt, 72, 16, 16, _marigold);
    s.text('A', 22, 45, 11, _cream);
    s.text('C', 80, 44, 11, _cream);
  },
  'most_likely': (s) {
    s.bg(0xFFE3603F);
    s.person(50, 34, 1.15, _cream);
    for (final (x, y, a) in const [(14.0, 72.0, -.72), (86.0, 72.0, -2.42), (50.0, 84.0, -1.57)]) {
      s.at(x, y, a, () {
        s.rect(-3, -3, 22, 6, _ink, 3);
        s.poly([19, -5, 27, 0, 19, 5], _ink);
      });
    }
  },
  'would_rather': (s) {
    s.rect(-50, -50, 100, 200, 0xFF2E7FD9);
    s.rect(50, -50, 100, 200, 0xFFD9423D);
    s.icon(GameIcons.mango, 13, 34, 28);
    s.icon(GameIcons.watermelon, 59, 34, 28);
    s.dot(50, 50, 11, _cream);
    s.text('or', 50, 50, 10, _ink);
  },
  'truth_dare': (s) {
    s.bg(0xFF0F7E72);
    s.oval(50, 54, 40, 28, 0xFF0B5F56);
    s.at(50, 52, -.75, () {
      s.rect(-30, -8.5, 44, 17, 0xFF2B6F41, 8);
      s.rect(10, -4, 20, 8, 0xFF2B6F41, 2);
      s.rect(28, -5, 6, 10, 0xFF8C5D2C, 1.5);
      s.rect(-18, -8.5, 16, 17, _cream);
    });
    s.text('T', 22, 22, 13, _cream);
    s.text('D', 80, 82, 13, _marigold);
  },
  'hand_cricket': (s) {
    s.bg(0xFF3C8D4B);
    s.oval(50, 88, 60, 18, 0xFF2F7440);
    s.rect(30, 22, 16, 52, 0xFFE5D2A8, 2);
    s.stroke('M38 22v52', 0xFFC8B282, .8);
    s.icon(GameIcons.bat, 44, 34, 40);
    s.icon(GameIcons.paper, 4, 44, 28);
    s.dot(70, 24, 5.5, _red);
    s.stroke('M66 21c3 3 5 5 7 7', _cream, .8);
  },
  'rock_paper_scissors': (s) {
    s.bg(0xFF6D49A8);
    s.at(26, 50, .2, () => s.icon(GameIcons.rock, -19, -19, 38));
    s.at(74, 50, -.2, () => s.icon(GameIcons.paper, -19, -19, 38));
    s.icon(GameIcons.bolt, 41, 36, 18, _marigold);
  },

  // ---- Boards and cards
  'colour_clash': (s) {
    s.bg(0xFF1F7A52);
    for (final (x, y, a, col, label) in const [(26.0, 54.0, -.42, _blue, '7'), (42.0, 48.0, -.14, _marigold, '3'), (59.0, 48.0, .14, _green, '+2')]) {
      s.card(x, y, 30, 44, a, col, () {
        s.oval(0, 0, 11, 16, _cream);
        s.text(label, 0, 0, 12, col);
      });
    }
    s.card(75, 54, 30, 44, .42, _ink, () {
      s.at(0, 0, .5, () {
        s.oval(0, 0, 11, 16, _cream);
        s.svg('M0 -16a11 16 0 0 1 11 16H0z', _red);
        s.svg('M11 0a11 16 0 0 1-11 16V0z', _blue);
        s.svg('M0 16a11 16 0 0 1-11-16H0z', _marigold);
        s.svg('M-11 0a11 16 0 0 1 11-16V0z', _green);
      });
      s.text('+4', 0, 0, 10, _cream);
    });
  },
  'ludo': (s) {
    s.bg(0xFF2C2721);
    s.at(50, 50, -.08, () {
      s.rect(-36, -34.5, 72, 72, 0xFF171411, 4);
      s.rect(-36, -36, 72, 72, _cream, 4);
      s.rect(-36, -36, 27, 27, _blue, 4);
      s.rect(9, -36, 27, 27, 0xFFFF8A1F, 4);
      s.rect(-36, 9, 27, 27, _green, 4);
      s.rect(9, 9, 27, 27, _pink, 4);
      for (var i = 0; i < 3; i++) {
        s.rect(-9 + i * 6.0, -36, 5, 72, 0xFFE8DCC4);
        s.rect(-36, -9 + i * 6.0, 72, 5, 0xFFE8DCC4);
      }
      s.rect(-3, -30, 6, 22, _blue);
      s.rect(8, -3, 22, 6, 0xFFFF8A1F);
      s.rect(-30, -3, 22, 6, _green);
      s.rect(-3, 8, 6, 22, _pink);
      s.poly([-9, -9, 9, -9, 0, 0], 0xFF2C2721);
      s.piece(0, -24, -24, 10);
      s.piece(1, 24, -24, 10);
      s.piece(2, -24, 24, 10);
      s.piece(4, 24, 24, 10);
      s.piece(0, 0, 18, 10);
    });
    s.die(78, 76, 18, .24, 6);
  },
  'ludo_teams': (s) => _scenes['ludo']!(s),
  'snakes_ladders': (s) {
    s.bg(0xFF2D8F85);
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        s.rect(15 + x * 14.0, 15 + y * 14.0, 14, 14, (x + y).isEven ? _cream : 0xFFF2C988);
      }
    }
    s.line(30, 80, 60, 24, 0xFF8C5D2C, 2.2);
    s.line(38, 84, 68, 28, 0xFF8C5D2C, 2.2);
    for (var i = 1; i < 6; i++) {
      s.line(30 + i * 5.0, 80 - i * 9.3, 38 + i * 5.0, 84 - i * 9.3, 0xFFC98F4F, 1.8);
    }
    s.stroke('M78 30c-14 4-2 14-16 18s-2 14-18 20', _red, 5);
    s.dot(79, 29, 4.6, _red);
    s.dot(80.5, 28, 1, _cream);
    s.piece(1, 62, 72, 9);
  },
  'bingo': (s) {
    s.bg(0xFFC7362F);
    s.at(50, 52, -.05, () {
      s.rect(-32, -32, 64, 64, _cream, 3);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final cx = -24 + x * 16.0, cy = -24 + y * 16.0;
          s.text('${(x * 7 + y * 11 + 3) % 25 + 1}', cx, cy, 6.5, _ink, display: false);
          if (x == y) s.dot(cx, cy, 6.6, 0xCCF6A91B);
        }
      }
    });
    s.dot(82, 22, 10, _marigold);
    s.text('7', 82, 22, 11, _ink);
  },
  'battleship': (s) {
    s.bg(0xFF1B4F7A);
    for (var i = 0; i < 7; i++) {
      s.line(8 + i * 14.0, -10, 8 + i * 14.0, 110, 0xFF2C6A9C, .5);
      s.line(-10, 8 + i * 14.0, 110, 8 + i * 14.0, 0xFF2C6A9C, .5);
    }
    s.svg('M14 50h60l-8 14H24z', 0xFF4C5866);
    s.rect(36, 40, 20, 10, 0xFF5E6B7A, 1.5);
    s.rect(50, 32, 3, 8, 0xFF3C4652);
    s.dot(64, 44, 8, _marigold);
    s.dot(66, 38, 5, _red);
    s.dot(72, 26, 3.4, 0xFF39414B);
    s.ring(26, 24, 4, _cream, 1.3);
    s.ring(82, 74, 4, _cream, 1.3);
  },
  'checkers': (s) {
    s.bg(0xFF4E2F1B);
    for (var y = 0; y < 7; y++) {
      for (var x = 0; x < 7; x++) {
        if ((x + y).isEven) s.rect(1.5 + x * 14.0, 1.5 + y * 14.0, 14, 14, 0xFFE8CFA2);
      }
    }
    void man(double x, double y, int col, int edge) {
      s.dot(x, y + 1.2, 6, edge);
      s.dot(x, y, 6, col);
      s.ring(x, y, 3.8, edge, .8);
    }

    man(36.5, 50, _red, 0xFF8F2422);
    man(64.5, 36, _ink, 0xFF000000);
    man(50.5, 64, _red, 0xFF8F2422);
    man(22.5, 36, _ink, 0xFF000000);
    man(78.5, 64, _red, 0xFF8F2422);
    s.icon(GameIcons.crownKing, 72, 57, 13);
    s.stroke('M38 48l10-8', _marigold, 1.4);
  },
  'dots_boxes': (s) {
    s.bg(0xFF2F5C8F);
    s.rect(14, 14, 72, 72, _cream, 2);
    s.rect(30, 30, 20, 20, 0x882E8BFF);
    s.rect(50, 30, 20, 20, 0x88FF8A1F);
    s.text('A', 40, 40, 11, _blue);
    s.text('R', 60, 40, 11, 0xFFC8620F);
    s.stroke('M30 30h40M30 50h40M30 30v20M50 30v20M70 30v20M30 70h20', _ink, 1.5);
    s.stroke('M50 50v20', _red, 2.2);
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        s.dot(20 + x * 20.0 - 0 + 10 - 10 + 0, 20 + y * 20.0 + 10 - 10, 1.5, _ink);
      }
    }
  },
  'connect_four': (s) {
    s.bg(0xFF2F8F6F);
    s.rect(14, 22, 72, 66, 0xFFE4C598, 5);
    const rows = [
      [0, 0, 0, 0, 0],
      [0, 0, 0, 2, 0],
      [0, 0, 2, 1, 0],
      [1, 2, 1, 1, 0],
      [2, 1, 2, 1, 2],
    ];
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        final v = rows[y][x];
        s.dot(25 + x * 12.5, 31 + y * 12.3, 4.8, v == 0 ? 0xFF38332B : (v == 1 ? _marigold : _red));
      }
    }
    s.dot(62.5, 13, 5, _marigold);
  },
  'tic_tac_toe': (s) {
    s.bg(0xFFBC9F78);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        s.rect(15 + x * 23, 16 + y * 23, 21, 21, _cream, 3);
      }
    }
    s.stroke('M21 22l11 11M32 22 21 33M47 45l10 11M57 45 47 56', _marigold, 3.6);
    s.stroke('M70 67l10 11M80 67 70 78', _marigold, 3.6);
    s.ring(72, 27, 6, _blue, 3);
    s.ring(26, 72, 6, _blue, 3);
    s.stroke('M17 18 86 84', _red, 1.8);
  },
  'memory': (s) {
    s.bg(0xFFB8A58B);
    void back(double x, double y) => s.card(x, y, 22, 28, 0, 0xFF365D56, () {
          s.stroke('M0 -6 6 0 0 6 -6 0Z', 0xFFE6C183, 1.2);
        });
    void front(double x, double y, GameIcons i) => s.card(x, y, 22, 28, 0, _cream, () => s.icon(i, -8, -8, 16));
    back(26, 34);
    front(50, 34, GameIcons.cherry);
    back(74, 34);
    back(26, 66);
    back(50, 66);
    front(74, 66, GameIcons.cherry);
  },

  // ---- Action
  'crush_it': (s) {
    s.rect(-50, -50, 200, 100, 0xFFE3603F);
    s.rect(-50, 50, 200, 100, 0xFF2E7FD9);
    s.icon(GameIcons.rock, 34, 8, 30);
    s.at(50, 77, math.pi, () => s.icon(GameIcons.rock, -15, -15, 30));
    s.rect(-10, 47, 120, 6, _cream);
    s.text('38', 18, 30, 15, _cream);
    s.text('41', 82, 72, 15, _cream);
  },
  'basketball_hoops': (s) {
    s.bg(0xFFB8602A);
    s.rect(30, 12, 40, 28, _cream, 2);
    s.rect(41, 22, 18, 13, 0xFFB8602A);
    s.rect(43, 24, 14, 9, _cream);
    s.rect(34, 40, 32, 3, _red, 1.5);
    s.stroke('M36 43l4 15h20l4-15M43 43l2 15M57 43l-2 15M38 49h24', _cream, 1);
    s.at(50, 38, .3, () => s.icon(GameIcons.ball, -11, -22, 22));
    s.stroke('M52 86c2-8 2-14 0-20', 0x66FBF3E2, 2);
    s.stroke('M36 88c2-6 4-10 8-14', 0x44FBF3E2, 2);
  },
  'fruit_duel': (s) {
    s.bg(0xFF2B2A52);
    s.at(50, 50, -.5, () {
      s.at(0, -9, -.2, () => s.svg('M-24 0a24 24 0 0 0 48 0z', 0xFF2B6F41));
      s.at(0, -9, -.2, () => s.svg('M-21 0a21 21 0 0 0 42 0z', _red));
    });
    s.at(52, 54, -.5, () => s.icon(GameIcons.watermelon, -24, -12, 48));
    s.stroke('M12 84 90 18', _cream, 2.4);
    s.dot(24, 28, 2, _red);
    s.dot(80, 72, 2.4, _red);
  },
  'paint_fight': (s) {
    s.bg(0xFFF4EFE3);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final v = (x * 3 + y * 5 + x * y) % 7;
        if (v < 3 && x + y < 9) s.rect(-6 + x * 14.0, -6 + y * 14.0, 14, 14, _blue);
        if (v > 3 && x + y > 5) s.rect(-6 + x * 14.0, -6 + y * 14.0, 14, 14, _pink);
      }
    }
    s.piece(0, 32, 40, 13);
    s.piece(4, 70, 62, 13);
  },
  'air_hockey': (s) {
    s.bg(0xFFDCEAF0);
    s.line(-10, 50, 110, 50, _red, 1.2);
    s.ring(50, 50, 16, 0xFF2E7FD9, 1);
    s.rect(32, -8, 36, 16, 0xFFB7CCD6, 3);
    s.rect(32, 92, 36, 16, 0xFFB7CCD6, 3);
    s.stroke('M50 54c6 4 12 6 20 6', 0x552E7FD9, 2);
    s.icon(GameIcons.puck, 38, 38, 24);
    s.icon(GameIcons.mallet, 62, 56, 28);
    s.at(26, 28, 0, () => s.icon(GameIcons.mallet, -14, -14, 28));
  },
  'ping_pong': (s) {
    s.bg(0xFF1F7D6C);
    s.rect(-10, 48, 120, 4, _cream);
    s.line(50, -10, 50, 110, 0x88FBF3E2, 1);
    s.rect(14, 12, 28, 6, _red, 3);
    s.rect(58, 82, 28, 6, _blue, 3);
    s.dot(62, 36, 4.6, _cream);
    s.stroke('M30 20 62 36', 0x66FBF3E2, 2);
  },
  'snake_duel': (s) {
    s.bg(0xFF1F2A24);
    for (var i = 0; i < 8; i++) {
      s.line(-2 + i * 14.0, -10, -2 + i * 14.0, 110, 0xFF2A382F, .5);
      s.line(-10, -2 + i * 14.0, 110, -2 + i * 14.0, 0xFF2A382F, .5);
    }
    s.stroke('M12 76h26V40h22V24', _green, 7);
    s.dot(60, 22, 5, 0xFF7BE0A4);
    s.stroke('M90 28H72v26H40v20', _marigold, 7);
    s.dot(40, 76, 5, 0xFFFFD36E);
  },
  'reaction_tap': (s) {
    s.bg(0xFF2FAE6E);
    s.dot(50, 50, 30, 0xFF4BCB8B);
    s.icon(GameIcons.bolt, 28, 28, 44, _cream);
    s.text('212', 80, 22, 11, _cream);
    s.text('ms', 80, 31, 6, _cream, display: false);
  },
  'penalty': (s) {
    s.bg(0xFF3A9150);
    s.rect(-10, 62, 120, 50, 0xFF338046);
    s.stroke('M14 62V20h72v42', _cream, 2.4);
    for (var i = 1; i < 6; i++) {
      s.line(14 + i * 12.0, 20, 14 + i * 12.0, 62, 0x66FBF3E2, .6);
    }
    for (var i = 1; i < 4; i++) {
      s.line(14, 20 + i * 10.5, 86, 20 + i * 10.5, 0x66FBF3E2, .6);
    }
    s.at(34, 40, -.6, () {
      s.rect(-5, -14, 10, 28, 0xFFEB5B2E, 4);
      s.dot(0, -18, 4.4, 0xFFB57A4E);
      s.rect(-13, -12, 8, 3.5, 0xFFEB5B2E, 1.7);
      s.rect(5, -12, 8, 3.5, 0xFFEB5B2E, 1.7);
    });
    s.icon(GameIcons.football, 62, 26, 15);
    s.stroke('M52 82c2-16 8-30 16-42', 0x77FBF3E2, 1.6);
  },
  'math_duel': (s) {
    s.bg(0xFF23587F);
    s.rect(14, 22, 72, 32, 0xFF18405E, 4);
    s.text('7 × 8', 50, 38, 15, _cream);
    for (final (x, v, hit) in const [(24.0, '54', false), (50.0, '56', true), (76.0, '48', false)]) {
      s.rect(x - 11, 62, 22, 16, hit ? _marigold : 0xFF3E7BA6, 3);
      s.text(v, x, 70, 10, hit ? _ink : _cream);
    }
  },
  'nitro_knockout': (s) {
    s.bg(0xFF56606B);
    s.stroke('M-10 76C20 60 30 30 60 26s40 6 60 2', 0xFF6C7682, 24);
    s.stroke('M-10 76C20 60 30 30 60 26s40 6 60 2', 0xFFF4EFE3, .8);
    void kart(double x, double y, double a, int col) => s.at(x, y, a, () {
          s.rect(-11, -8.5, 6, 17, _ink, 2);
          s.rect(5, -8.5, 6, 17, _ink, 2);
          s.rect(-12, -6, 24, 12, col, 3.5);
          s.dot(-1, 0, 3.6, _cream);
        });
    kart(26, 58, -.7, _blue);
    s.dot(62, 30, 12, _marigold);
    s.dot(62, 30, 7, _red);
    for (final (x, y) in const [(46.0, 20.0), (78.0, 18.0), (80.0, 40.0), (46.0, 42.0)]) {
      s.dot(x, y, 2.2, _marigold);
    }
    kart(62, 30, .5, _pink);
    s.icon(GameIcons.rocket, 34, 28, 13);
  },
  'mini_golf': (s) {
    s.bg(0xFF2F8A4B);
    s.oval(50, 52, 44, 30, 0xFF47A862);
    s.svg('M18 70c8-8 16-8 20 0s-14 10-20 0z', 0xFFE8D39B);
    s.oval(70, 40, 5.5, 3, _ink);
    s.line(70, 40, 70, 16, _cream, 1.2);
    s.poly([70, 15, 84, 20, 70, 25], _red);
    s.dot(38, 58, 3.4, _cream);
    s.stroke('M41 56c8-4 16-8 25-14', 0xAAFBF3E2, 1.2);
  },
  'slingshot': (s) {
    s.bg(0xFF84C6E2);
    s.rect(-10, 74, 120, 40, 0xFF5D9E4C);
    s.stroke('M18 74V56M18 58l-5-9M18 58l5-9', 0xFF8C5D2C, 3);
    s.stroke('M13 49l-4 6M23 49l-14 6', _ink, 1);
    s.at(9, 56, 0, () => s.icon(GameIcons.bird, -6, -6, 12));
    s.stroke('M12 50c14-18 34-22 46-12', 0x99FBF3E2, 1.2);
    s.rect(64, 56, 5, 18, 0xFFC98F4F);
    s.rect(84, 56, 5, 18, 0xFFC98F4F);
    s.rect(62, 52, 29, 5, 0xFFC98F4F);
    s.icon(GameIcons.pig, 69, 40, 14);
    s.icon(GameIcons.pig, 70, 62, 13);
  },
  'archery': (s) {
    s.bg(0xFFB9DDEA);
    s.rect(-10, 78, 120, 40, 0xFF7FB35A);
    s.line(54, 60, 40, 84, 0xFF8C5D2C, 3);
    s.line(54, 60, 68, 84, 0xFF8C5D2C, 3);
    s.dot(54, 46, 28, 0xFF8C5D2C);
    s.dot(54, 46, 26, _cream);
    s.dot(54, 46, 20, _ink);
    s.dot(54, 46, 14, _blue);
    s.dot(54, 46, 9, _red);
    s.dot(54, 46, 4.6, _marigold);
    s.line(55, 45, 92, 18, 0xFF8C5D2C, 1.6);
    s.stroke('M92 18l5-2M92 18l1 5', _red, 1.4);
  },
  'shooting_gallery': (s) {
    s.bg(0xFF7A2E3A);
    s.rect(-10, -10, 120, 28, 0xFFB8434E);
    for (var i = 0; i < 7; i++) {
      s.dot(-4 + i * 18.0, 18, 9, i.isEven ? _cream : 0xFFB8434E);
    }
    s.rect(-10, 60, 120, 6, 0xFF4E1D25);
    s.icon(GameIcons.duck, 12, 38, 24);
    s.icon(GameIcons.duck, 66, 38, 24);
    s.icon(GameIcons.rabbit, 40, 36, 24);
    s.ring(52, 48, 12, _marigold, 1.6);
    s.line(52, 32, 52, 64, _marigold, 1);
    s.line(36, 48, 68, 48, _marigold, 1);
  },
  'bottle_smash': (s) {
    s.bg(0xFFE28A3A);
    s.rect(-10, 72, 120, 40, 0xFF8C5D2C);
    for (final (x, y, a) in const [(36.0, 60.0, 0.0), (52.0, 60.0, 0.0), (68.0, 60.0, .24), (44.0, 38.0, -.16)]) {
      s.at(x, y, a, () => s.icon(GameIcons.bottle, -11, -11, 22));
    }
    s.at(62, 32, 1.1, () => s.icon(GameIcons.bottle, -11, -11, 22));
    s.icon(GameIcons.cricketBall, 8, 28, 16);
    s.stroke('M26 36c8 0 16-1 24-1', 0x88FBF3E2, 1.4);
  },
  'fruit_merge_battle': (s) {
    s.rect(-50, -50, 100, 200, 0xFF8E3B6B);
    s.rect(50, -50, 100, 200, 0xFF2F6F8E);
    for (final x in const [24.0, 76.0]) {
      s.rect(x - 19, 26, 38, 54, 0x44FBF3E2, 3);
      s.icon(GameIcons.watermelon, x - 14, 34, 28);
      s.icon(GameIcons.orange, x - 16, 60, 18);
      s.icon(GameIcons.cherry, x + 2, 62, 16);
    }
  },

  // ---- Solo
  'fruit_merge': (s) {
    s.bg(0xFFD86A3C);
    s.stroke('M20 20v60c0 2 2 4 4 4h52c2 0 4-2 4-4V20', _cream, 2.4);
    s.icon(GameIcons.watermelon, 28, 44, 38);
    s.icon(GameIcons.orange, 22, 66, 20);
    s.icon(GameIcons.apple, 60, 68, 16);
    s.icon(GameIcons.strawberry, 42, 12, 16);
    s.line(50, 28, 50, 44, 0x66FBF3E2, 1);
  },
  'game_2048': (s) {
    s.bg(0xFF3A342C);
    const vals = [
      [2, 4, 8, 0],
      [0, 16, 32, 4],
      [2, 8, 64, 128],
      [4, 2, 256, 512],
    ];
    const ramp = {0: 0xFF4A4338, 2: 0xFFF3E9D2, 4: 0xFFF2DDAE, 8: 0xFFF2BC6B, 16: 0xFFEF9F4E, 32: 0xFFE9793C, 64: 0xFFD9542B, 128: 0xFFF6C944, 256: 0xFFF2B51F, 512: 0xFFF6A91B};
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        final v = vals[y][x];
        final cx = 19 + x * 21.0, cy = 19 + y * 21.0;
        s.rect(cx - 10, cy - 10, 20, 20, ramp[v]!, 2.4);
        if (v > 0) s.text('$v', cx, cy, v > 64 ? 7.5 : 9.5, v < 8 ? _ink : (v >= 128 ? _ink : _cream));
      }
    }
  },
  'classic_snake': (s) {
    s.bg(0xFFBFD08A);
    for (var i = 0; i < 8; i++) {
      s.line(-2 + i * 14.0, -10, -2 + i * 14.0, 110, 0xFFAFC179, .5);
      s.line(-10, -2 + i * 14.0, 110, -2 + i * 14.0, 0xFFAFC179, .5);
    }
    s.stroke('M14 74h44V40H30', 0xFF2B4A2F, 8);
    s.dot(30, 40, 5.6, 0xFF1B3320);
    s.dot(28, 38, 1, _cream);
    s.icon(GameIcons.apple, 66, 22, 15);
  },
  'flappy_jump': (s) {
    s.bg(0xFF74C7D9);
    s.rect(60, -10, 18, 44, _green, 2);
    s.rect(57, 28, 24, 7, 0xFF23864F, 2);
    s.rect(60, 66, 18, 50, _green, 2);
    s.rect(57, 62, 24, 7, 0xFF23864F, 2);
    s.rect(-10, 86, 120, 20, 0xFFE8D39B);
    s.oval(14, 24, 11, 4, _cream);
    s.at(36, 48, -.3, () => s.icon(GameIcons.bird, -11, -11, 22));
    s.stroke('M10 60c6 2 10 0 16-4', 0x77FBF3E2, 1.4);
  },
  'minesweeper': (s) {
    s.bg(0xFF6E8A62);
    const open = {'1,1': '1', '2,1': '2', '3,1': '1', '1,2': '1', '2,2': '', '3,2': '3', '1,3': '1', '2,3': '1', '3,3': '2'};
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        final k = '$x,$y', cx = 16 + x * 17.0, cy = 16 + y * 17.0;
        final o = open.containsKey(k);
        s.rect(cx - 8, cy - 8, 16, 16, o ? 0xFFEFE6D0 : ((x + y).isEven ? 0xFF8BA67E : 0xFF7F9A72), 1.5);
        if (o && open[k]!.isNotEmpty) s.text(open[k]!, cx, cy, 9, open[k] == '1' ? _blue : (open[k] == '2' ? 0xFF1F7A52 : _red));
      }
    }
    s.icon(GameIcons.flag, 65, 9, 14);
    s.icon(GameIcons.mine, 75, 75, 16);
  },
  'brick_breaker': (s) {
    s.bg(0xFF262B47);
    const row = [_red, 0xFFF08A3C, _marigold, _green, _blue];
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 6; x++) {
        if (y == 3 && x % 3 == 1 || y == 2 && x == 4) continue;
        s.rect(5 + x * 15.4, 16 + y * 8.0, 14, 6.8, row[y], 1.2);
      }
    }
    s.rect(30, 80, 30, 5, _cream, 2.5);
    s.dot(58, 56, 3.2, _cream);
    s.stroke('M46 78 58 56 72 48', 0x55FBF3E2, 1);
  },
  'whack_mole': (s) {
    s.bg(0xFF5E9E4C);
    for (final (x, y) in const [(24.0, 40.0), (76.0, 36.0), (50.0, 70.0)]) {
      s.oval(x, y, 15, 6, 0xFF3F2C1C);
    }
    s.icon(GameIcons.mole, 37, 46, 26);
    s.oval(50, 72, 15, 4, 0xFF5E9E4C);
    s.oval(50, 77, 16, 5, 0xFF5E9E4C);
    s.at(68, 42, .7, () => s.icon(GameIcons.hammer, -18, -18, 36));
  },
  'piano_tiles': (s) {
    s.bg(0xFFF5EFE4);
    for (var i = 1; i < 4; i++) {
      s.line(i * 25.0, -10, i * 25.0, 110, 0xFFD9D0BF, .8);
    }
    s.rect(0, -6, 25, 30, _ink);
    s.rect(50, 18, 25, 30, _ink);
    s.rect(25, 46, 25, 30, _marigold);
    s.rect(75, 72, 25, 34, _ink);
    s.dot(37.5, 66, 4, 0x55000000);
  },
  'word_scramble': (s) {
    s.bg(0xFF23706F);
    const word = ['M', 'A', 'N', 'G', 'O'];
    const off = [(-34.0, 8.0, -.2), (-17.0, -10.0, .12), (0.0, 6.0, -.1), (17.0, -8.0, .2), (34.0, 8.0, -.14)];
    for (var i = 0; i < 5; i++) {
      final (dx, dy, a) = off[i];
      s.at(50 + dx, 50 + dy, a, () {
        s.rect(-7.5, -7, 15, 16, 0xFFC4B28F, 2);
        s.rect(-7.5, -8, 15, 15, _cream, 2);
        s.text(word[(i * 2 + 1) % 5], 0, 0, 10, _ink);
      });
    }
  },
  'stack_tower': (s) {
    s.bg(0xFF4C8FBF);
    const cols = [0xFFD9423D, 0xFFEF7D3A, 0xFFF6A91B, 0xFF7BB85A, 0xFF3F9A8F];
    for (var i = 0; i < 5; i++) {
      final w = 44.0 - i * 4, x = 50 - w / 2 + (i.isEven ? 0 : 2);
      s.rect(x, 74 - i * 10.0, w, 9, cols[i], 1);
    }
    s.rect(26, 22, 26, 9, 0xFF2F7F9E, 1);
    s.stroke('M18 26H8M92 26H62', 0x66FBF3E2, 1.2);
  },
  'simon_says': (s) {
    s.bg(0xFF1F2030);
    s.svg('M48 48V14A34 34 0 0 0 14 48z', _green);
    s.svg('M52 48V14A34 34 0 0 1 86 48z', 0xFFFF5E5B);
    s.svg('M48 52H14A34 34 0 0 0 48 86z', _marigold);
    s.svg('M52 52V86A34 34 0 0 0 86 52z', _blue);
    s.dot(50, 50, 10, 0xFF1F2030);
    s.dot(50, 50, 4, _cream);
  },
  'ball_sort': (s) {
    s.bg(0xFF4C3A78);
    const tubes = [
      [_red, _blue, _red],
      [_marigold, _marigold, _marigold],
      [_blue, _green, _blue],
    ];
    for (var t = 0; t < 3; t++) {
      final x = 24.0 + t * 26;
      s.rect(x - 9, 26, 18, 54, 0x33FBF3E2, 9);
      for (var i = 0; i < 3; i++) {
        s.dot(x, 70 - i * 15.0, 7, tubes[t][i]);
      }
    }
    s.dot(50, 18, 7, _marigold);
  },
  'sliding_puzzle': (s) {
    s.bg(0xFF7C4B2A);
    s.rect(12, 12, 76, 76, 0xFF4E2F1B, 4);
    const nums = [1, 2, 3, 4, 5, 6, 7, 0, 8];
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        final n = nums[y * 3 + x];
        if (n == 0) continue;
        final cx = 27 + x * 23.0 + (n == 8 ? -4 : 0), cy = 27 + y * 23.0;
        s.rect(cx - 10.5, cy - 9.5, 21, 21, 0xFF9C6B3D, 2);
        s.rect(cx - 10.5, cy - 10.5, 21, 20, 0xFFD8A968, 2);
        s.text('$n', cx, cy - .5, 11, _ink);
      }
    }
  },
  'sudoku': (s) {
    s.bg(0xFF2F4B7A);
    s.rect(14, 14, 72, 72, _cream, 2);
    for (var i = 1; i < 6; i++) {
      s.line(14 + i * 12.0, 14, 14 + i * 12.0, 86, i == 3 ? _ink : 0xFFC8BDA8, i == 3 ? 1.2 : .5);
      s.line(14, 14 + i * 12.0, 86, 14 + i * 12.0, i % 2 == 0 && i != 4 ? _ink : 0xFFC8BDA8, i % 2 == 0 && i != 4 ? 1.2 : .5);
    }
    for (final (x, y, n, pen) in const [(0, 0, '5', false), (2, 1, '3', false), (4, 0, '7', false), (1, 3, '6', false), (3, 2, '9', true), (5, 4, '1', false), (2, 4, '8', true), (4, 5, '2', false), (0, 5, '4', false)]) {
      s.text(n, 20 + x * 12.0, 20.5 + y * 12.0, 8, pen ? _blue : _ink);
    }
  },
  'hangman': (s) {
    s.bg(0xFFEFE3CB);
    s.stroke('M18 78h34M30 78V20h26v8', 0xFF5C4630, 3);
    s.ring(56, 34, 6, _ink, 1.8);
    s.stroke('M56 40v16M56 44l-7 7M56 44l7 7', _ink, 1.8);
    for (final (x, ch) in const [(58.0, 'M'), (68.0, ''), (78.0, 'N'), (88.0, '')]) {
      s.line(x - 3.5, 80, x + 3.5, 80, _ink, 1.2);
      if (ch.isNotEmpty) s.text(ch, x, 74, 9, _ink);
    }
  },
  'dino_run': (s) {
    s.bg(0xFFE9B872);
    s.dot(80, 24, 9, 0xFFF7D79A);
    s.rect(-10, 72, 120, 40, 0xFFB7793F);
    s.icon(GameIcons.cactus, 64, 50, 24);
    s.svg('M18 52c0-8 6-14 16-14h6c3 0 4 2 4 4s-1 4-4 4h-4c0 10-6 16-14 16l-8 2z', 0xFF3F6B3D);
    s.stroke('M24 62l-2 8M30 60l2 7', 0xFF3F6B3D, 3);
    s.dot(38, 41.5, 1.2, _cream);
    s.stroke('M46 34c4-3 8-3 12 0', 0x88FBF3E2, 1.2);
  },
  'block_drop': (s) {
    s.bg(0xFF1F2A44);
    s.rect(22, 8, 56, 84, 0xFF161E33, 2);
    void cell(int x, int y, int col) {
      s.rect(24 + x * 10.6, 8 + y * 10.5, 9.8, 9.8, col, 1.4);
    }

    for (final (x, y) in const [(0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (0, 6), (1, 6), (3, 6), (4, 6), (0, 5), (4, 5)]) {
      cell(x, y, x < 2 ? _blue : (x > 2 ? _pink : _green));
    }
    for (final (x, y) in const [(2, 1), (2, 2), (2, 3), (3, 3)]) {
      cell(x, y, _marigold);
    }
  },
  'bubble_shooter': (s) {
    s.bg(0xFF1E4F7A);
    const cols = [_red, _marigold, _green, _blue, _pink];
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 6 - (y % 2); x++) {
        s.dot(12 + x * 15.0 + (y % 2) * 7.5, 16 + y * 13.0, 7, cols[(x * 2 + y * 3) % 5]);
      }
    }
    s.stroke('M50 82 72 56 56 44', 0x77FBF3E2, 1.2);
    s.dot(50, 82, 7, _green);
  },
  'sky_jumper': (s) {
    s.bg(0xFF7DC9E8);
    s.oval(20, 24, 12, 4.5, _cream);
    s.oval(82, 46, 12, 4.5, _cream);
    s.rect(14, 72, 26, 5, _green, 2.5);
    s.rect(62, 58, 26, 5, _green, 2.5);
    s.rect(38, 28, 26, 5, 0xFF2F8BC9, 2.5);
    s.dot(50, 44, 7.5, 0xFF56B25E);
    s.dot(46.5, 38.5, 2.6, _cream);
    s.dot(53.5, 38.5, 2.6, _cream);
    s.dot(46.8, 38.5, 1.1, _ink);
    s.dot(53.8, 38.5, 1.1, _ink);
    s.stroke('M30 70c6-12 12-20 18-24', 0x88FBF3E2, 1.3);
  },
  'space_shooter': (s) {
    s.bg(0xFF14162E);
    for (final (x, y) in const [(10.0, 20.0), (30.0, 44.0), (74.0, 16.0), (88.0, 58.0), (18.0, 74.0), (60.0, 34.0)]) {
      s.dot(x, y, .7, _cream);
    }
    s.icon(GameIcons.ufo, 18, 16, 22);
    s.icon(GameIcons.alien, 42, 14, 18);
    s.icon(GameIcons.ufo, 64, 18, 20);
    s.line(50, 62, 50, 40, _marigold, 1.6);
    s.icon(GameIcons.rocket, 38, 58, 24);
  },
  'color_switch': (s) {
    s.bg(0xFF22213A);
    void arc(double start, int col) => s.c.drawArc(Rect.fromCircle(center: const Offset(50, 40), radius: 24), start, math.pi / 2 - .06, false, s._p(col)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7);
    arc(0, _red);
    arc(math.pi / 2, _marigold);
    arc(math.pi, _blue);
    arc(-math.pi / 2, _pink);
    s.icon(GameIcons.star, 44, 34, 12, _cream);
    s.dot(50, 74, 5.4, _marigold);
    s.stroke('M50 82v8', 0x55F6A91B, 2);
  },

  // ---- Added with the newer games
  'chess': (s) {
    s.bg(0xFF3E2A1C);
    for (var y = 0; y < 7; y++) {
      for (var x = 0; x < 7; x++) {
        if ((x + y).isEven) s.rect(1.5 + x * 14.0, 1.5 + y * 14.0, 14, 14, 0xFFE8CFA2);
      }
    }
    void pawn(double x, double y, int c) {
      s.dot(x, y - 8, 5, c);
      s.svg('M${x - 4} ${y - 4}h8l3 12h-14z', c);
      s.rect(x - 9, y + 7, 18, 4, c, 1.5);
    }

    pawn(36.5, 52, _cream);
    pawn(64.5, 38, _ink);
    s.at(64.5, 66, 0, () {
      s.dot(0, -14, 3, _ink);
      s.rect(-1, -24, 2, 8, _ink);
      s.rect(-4, -22, 8, 2, _ink);
      s.svg('M-7 -12h14l3 18h-20z', _ink);
      s.rect(-11, 5, 22, 4, _ink, 1.5);
    });
  },
  'backgammon': (s) {
    s.bg(0xFF6B3F24);
    s.rect(8, 14, 84, 72, 0xFFE3C796, 3);
    s.rect(47, 14, 6, 72, 0xFF6B3F24);
    for (var i = 0; i < 6; i++) {
      final x = 11.0 + i * 6 + (i > 2 ? 3 : 0);
      final x2 = 53.0 + i * 6.2;
      for (final px in [x, x2]) {
        final col = (i + (px > 50 ? 1 : 0)).isEven ? 0xFF9E2A2B : 0xFF2C4A3E;
        s.poly([px, 14, px + 6, 14, px + 3, 44], col);
        s.poly([px, 86, px + 6, 86, px + 3, 56], col == 0xFF9E2A2B ? 0xFF2C4A3E : 0xFF9E2A2B);
      }
    }
    for (final (x, y, c) in const [(17.0, 20.0, _cream), (17.0, 27.0, _cream), (17.0, 34.0, _cream), (71.0, 80.0, _ink), (71.0, 73.0, _ink)]) {
      s.dot(x, y, 3.4, c);
    }
    s.die(38, 52, 13, -.2, 5);
    s.die(62, 48, 13, .22, 3);
  },
  'uno': (s) {
    s.bg(0xFF9E2A2B);
    s.card(30, 54, 32, 46, -.3, _blue, () => s.text('5', 0, 0, 16, _cream));
    s.card(50, 50, 32, 46, 0, _marigold, () => s.text('2', 0, 0, 16, _ink));
    s.card(72, 54, 32, 46, .3, _green, () {
      s.at(0, 0, .5, () => s.oval(0, 0, 10, 15, _cream));
      s.text('+2', 0, 0, 11, _green);
    });
  },
  'fruit_cut': (s) {
    s.bg(0xFF2F6F5A);
    s.icon(GameIcons.orange, 12, 22, 30);
    s.icon(GameIcons.apple, 58, 16, 30);
    s.icon(GameIcons.pear, 40, 54, 30);
    s.stroke('M6 72 94 26', _cream, 2);
    s.dot(30, 40, 1.8, 0xFFF2922C);
    s.dot(76, 48, 1.8, _red);
  },
  'slot_cars': (s) {
    s.bg(0xFF2B3A46);
    s.stroke('M22 30h56a14 14 0 0 1 0 40H22a14 14 0 0 1 0-40z', 0xFF505F6C, 16);
    s.stroke('M22 27h56a17 17 0 0 1 0 46H22a17 17 0 0 1 0-46z', _cream, .9);
    s.stroke('M22 33h56a11 11 0 0 1 0 34H22a11 11 0 0 1 0-34z', _marigold, .9);
    s.rect(38, 24, 15, 7, _red, 2.5);
    s.rect(58, 69, 15, 7, _blue, 2.5);
  },
  'carrom': (s) {
    s.bg(0xFF5C3A21);
    s.rect(10, 10, 80, 80, 0xFFE9CE9B, 3);
    for (final (x, y) in const [(14.0, 14.0), (86.0, 14.0), (14.0, 86.0), (86.0, 86.0)]) {
      s.dot(x, y, 5, 0xFF2A1C05);
    }
    s.ring(50, 50, 16, 0xFF8C5D2C, .8);
    for (final (x, y, c) in const [(50.0, 50.0, _red), (44.0, 44.0, _ink), (56.0, 44.0, _cream), (44.0, 56.0, _cream), (56.0, 56.0, _ink), (50.0, 40.0, _ink)]) {
      s.dot(x, y, 4, c);
    }
    s.dot(36, 80, 6, _blue);
    s.stroke('M38 76 46 62', 0x888C5D2C, 1.2);
  },
  'eight_ball_pool': (s) {
    s.bg(0xFF1F6F4E);
    s.dot(64, 42, 9, _ink);
    s.dot(64, 42, 4, _cream);
    s.text('8', 64, 42, 6, _ink);
    s.dot(40, 30, 7, _red);
    s.dot(82, 66, 7, _marigold);
    s.dot(30, 68, 7, _cream);
    s.line(4, 96, 25, 72, 0xFFC98F4F, 2.2);
    s.stroke('M34 63 58 46', 0x77FBF3E2, 1);
  },
  'darts': (s) {
    s.bg(0xFF2B2A33);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      s.at(50, 50, a, () => s.poly([0, 0, -9.5, -35, 9.5, -35], i.isEven ? 0xFF2A1C05 : _cream));
    }
    s.ring(50, 50, 36, _red, 2.4);
    s.ring(50, 50, 21, _green, 2.2);
    s.dot(50, 50, 4.4, _red);
    s.line(52, 48, 78, 22, 0xFF8E98A3, 1.8);
    s.poly([78, 22, 86, 20, 80, 28], _marigold);
  },
  'hot_potato': (s) {
    s.bg(0xFFD9542B);
    s.oval(50, 54, 22, 17, 0xFFB98148);
    s.oval(46, 50, 3, 2, 0xFF8C5D2C);
    s.oval(58, 58, 3, 2, 0xFF8C5D2C);
    s.stroke('M38 30c-4-6 4-8 0-14M50 28c-4-6 4-8 0-14M62 30c-4-6 4-8 0-14', _cream, 2);
    s.icon(GameIcons.paper, 4, 54, 24);
    s.icon(GameIcons.paper, 72, 54, 24);
  },
  'hungry_hippos': (s) {
    s.bg(0xFF35A0A8);
    s.oval(50, 62, 30, 22, 0xFF7A4FB5);
    s.oval(50, 74, 22, 9, 0xFF55337F);
    s.dot(36, 44, 6, _cream);
    s.dot(64, 44, 6, _cream);
    s.dot(36, 44, 2.4, _ink);
    s.dot(64, 44, 2.4, _ink);
    for (final (x, y, c) in const [(20.0, 24.0, _marigold), (50.0, 22.0, _red), (80.0, 26.0, _cream)]) {
      s.dot(x, y, 4, c);
    }
  },
  'j_fishing': (s) {
    s.bg(0xFF2E7FB8);
    s.rect(-10, -10, 120, 34, 0xFF9FD3E8);
    s.line(70, -5, 50, 62, _cream, .8);
    s.oval(38, 66, 15, 8, _marigold);
    s.poly([52, 66, 62, 58, 62, 74], _marigold);
    s.dot(32, 64, 1.4, _ink);
    s.stroke('M-5 30c10-4 20 4 30 0s20 4 30 0 20 4 30 0 20 4 30 0', _cream, .9);
  },
  'j_fireworks': (s) {
    s.bg(0xFF171A38);
    void burst(double x, double y, double r, int c) {
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5;
        s.line(x + math.cos(a) * r * .35, y + math.sin(a) * r * .35, x + math.cos(a) * r, y + math.sin(a) * r, c, 1.6);
      }
    }

    burst(34, 38, 22, _pink);
    burst(70, 32, 18, _marigold);
    burst(62, 66, 14, _green);
    s.rect(-10, 84, 120, 20, 0xFF0B0D1E);
  },
  'j_knifeHit': (s) {
    s.bg(0xFF3A2B4F);
    s.dot(50, 36, 24, 0xFFC98F4F);
    s.ring(50, 36, 16, 0xFF8C5D2C, 1);
    s.ring(50, 36, 8, 0xFF8C5D2C, 1);
    for (final a in const [.6, 2.4, 4.2]) {
      s.at(50, 36, a, () {
        s.poly([-2.4, 22, 2.4, 22, 0, 12], 0xFFD9DEE3);
        s.rect(-2.6, 22, 5.2, 12, 0xFF2A1C05, 1);
      });
    }
    s.poly([46, 80, 54, 80, 50, 62], 0xFFD9DEE3);
    s.rect(46, 80, 8, 14, _red, 1.5);
  },
  'j_flappyDunk': (s) {
    s.bg(0xFF7CC4D8);
    s.ring(66, 42, 13, _red, 2.6);
    s.stroke('M56 46l4 14h12l4-14', _cream, 1);
    s.icon(GameIcons.ball, 22, 44, 20);
    s.svg('M22 50c-8-6-14-4-16 2 6 0 10 2 16 4z', _cream);
    s.svg('M42 50c8-6 14-4 16 2-6 0-10 2-16 4z', _cream);
  },
  'j_hungryHippos': (s) => _scenes['hungry_hippos']!(s),
  'j_hotPotato': (s) => _scenes['hot_potato']!(s),
  'j_findIt': (s) {
    s.bg(0xFFE7B24A);
    for (final (x, y, i) in const [(18.0, 22.0, GameIcons.apple), (66.0, 18.0, GameIcons.star), (20.0, 62.0, GameIcons.bottle), (70.0, 66.0, GameIcons.duck)]) {
      s.icon(i, x, y, 16, 0xFF8C5D2C);
    }
    s.icon(GameIcons.magnifier, 32, 30, 38);
  },
  'j_soccerStars': (s) {
    s.bg(0xFF3A9150);
    s.ring(50, 50, 18, _cream, 1);
    s.line(50, -10, 50, 110, _cream, 1);
    s.dot(30, 38, 8, _blue);
    s.dot(30, 38, 4.6, _cream);
    s.dot(72, 64, 8, _red);
    s.dot(72, 64, 4.6, _cream);
    s.icon(GameIcons.football, 44, 44, 12);
  },
  'j_ringToss': (s) {
    s.bg(0xFF8E3B6B);
    s.rect(-10, 76, 120, 30, 0xFFC98F4F);
    for (final x in const [28.0, 50.0, 72.0]) {
      s.rect(x - 2, 44, 4, 34, _cream, 2);
    }
    c0(s) => s.c.drawOval(const Rect.fromLTWH(38, 54, 24, 8), s._p(_marigold)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6);
    c0(s);
    s.c.drawOval(const Rect.fromLTWH(58, 18, 24, 10), s._p(_green)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6);
  },
};
