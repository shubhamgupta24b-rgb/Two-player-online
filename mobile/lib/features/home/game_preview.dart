import 'package:flutter/material.dart';

/// Local preview manifest. Each id maps to the scene the card draws.
/// Previews are painted in the app, so the home screen does not fetch images.
const gamePreviewManifest = <String, String>{
  'memory': 'Face-down cards and one matched pair',
  'smash_karts': 'Kart on a track with a bumper',
  'ludo': 'Ludo board, four bases, and a rolled six',
  'ludo_teams': 'Ludo centre with partners across the board',
  'air_hockey': 'Air-hockey table, two mallets, and a puck',
  'tic_tac_toe': 'Noughts-and-crosses grid',
  'connect_four': 'Vertical board with a line of discs',
  'battleship': 'Sea grid, a ship, a hit, and misses',
  'checkers': 'Checkerboard with a jumping piece and a king',
  'snakes_ladders': 'Numbered board, a ladder, and a snake',
  'archery': 'Target with an arrow in the gold',
  'bingo': 'Bingo card with a marked line',
  'colour_clash': 'Hand of colour cards and a wild',
  'raja_mantri': 'Four role chits with the crown in front',
  'guess_person': 'Secret person card and yes or no',
  'guess_who': 'Two portrait boards and a question',
  'dots_boxes': 'Dots with lines and one claimed box',
  'ping_pong': 'Table, net, paddle, and ball',
  'basketball_hoops': 'Hoop and a ball going in',
  'paint_fight': 'Paint splats on a wall',
  'reaction_tap': 'Tap target with a bolt',
  'math_duel': 'Sum and two answer choices',
  'hand_cricket': 'Bat, ball, and stumps',
  'quiz_battle': 'Question card and two answers',
  'fruit_merge_battle': 'Two fruits merging into a larger one',
  'mini_golf': 'Green, hole, flag, and ball',
  'slingshot': 'Sling pulled toward a stack',
  'shooting_gallery': 'Ducks on a rail and a crosshair',
  'bottle_smash': 'Bottles, one of them smashed',
  'find_spy': 'A row of people, one in a mask',
  'mafia': 'Moon and a hidden figure',
  'undercover': 'Two word cards and a mask',
  'charades': 'Actor and a clapboard',
  'heads_up': 'Phone held on a forehead',
  'draw_guess': 'Sketch and a brush',
  'most_likely': 'Three people, one pointed out',
  'would_rather': 'Two choice cards',
  'truth_dare': 'Bottle spun toward a player',
  'rock_paper_scissors': 'Rock, paper, and scissors',
  'bike_race': 'Two riders in lanes',
  'hungry_hippos': 'Hippo heads and loose marbles',
  'tug_of_war': 'Rope pulled between two sides',
  'carrom': 'Carrom board, coins, and a striker',
  'eight_ball': 'Pool table, balls, cue, and pockets',
  'minesweeper_race': 'Two mine grids racing a flag',
  'fruit_merge': 'Fruit stacked into a bigger fruit',
  'fruit_cut': 'Sliced fruit and a cut trail',
  'chicken_jump': 'Chicken flying between pipes',
  'knife_hit': 'Log with knives stuck in it',
  'sweet_swap': 'Match-3 candy grid',
  'game_2048': 'Number tiles sliding together',
  'flappy_jump': 'Bird flying between pipes',
  'minesweeper': 'Mine grid with numbers and a flag',
  'brick_breaker': 'Bricks, a ball, and a paddle',
  'whack_mole': 'Holes with a mole popping up',
  'piano_tiles': 'Piano tiles, one lit to tap',
  'word_scramble': 'Scrambled letters and a word slot',
  'stack_tower': 'Blocks stacked with an offset',
  'simon_says': 'Four colour pads',
  'ball_sort': 'Tubes of coloured balls',
  'sliding_puzzle': 'Numbered tiles with an empty gap',
  'sudoku': 'Number grid with a few digits filled',
  'hangman': 'Gallows and a letter row',
  'dino_run': 'Runner jumping a cactus',
  'block_drop': 'Falling block over a stack',
  'bubble_shooter': 'Bubble cluster and a shooter',
  'sky_jumper': 'Jumper bouncing on platforms',
  'space_shooter': 'Ship firing at an alien',
  'color_switch': 'Colour wheel and a falling ball',
  'fruit_duel': 'Two fruit halves in a duel',
  'classic_snake': 'Snake crossing an apple',
  'snake_duel': 'Two snakes on one board',
  'penalty': 'Goal, keeper, and a ball',
  'crush_it': 'Blocks crushed by a hammer',
};

bool hasUniquePreview(String id) => previewSceneIds.contains(id) && gamePreviewManifest.containsKey(id);

Set<String> get previewSceneIds => _scenes.keys.toSet();

class GamePreview extends StatelessWidget {
  final String id;
  const GamePreview({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GamePreviewPainter(id),
      child: const SizedBox.expand(),
    );
  }
}

class GamePreviewPainter extends CustomPainter {
  final String id;
  const GamePreviewPainter(this.id);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.clipRect(Rect.fromLTWH(0, 0, side, side));
    final draw = _D(canvas, side);
    final scene = _scenes[id];
    if (scene == null) {
      _missing(draw);
    } else {
      scene(draw);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GamePreviewPainter old) => old.id != id;
}

const _ink = Color(0xFF1C1A17);
const _cream = Color(0xFFF6F1E6);
const _red = Color(0xFFE23D3D);
const _blue = Color(0xFF2E8BFF);
const _green = Color(0xFF2E9B57);
const _gold = Color(0xFFF0C14A);
const _wood = Color(0xFFC4A574);

class _D {
  final Canvas canvas;
  final double u;
  _D(this.canvas, double side) : u = side / 100;

  void fill(Color color) => canvas.drawRect(Rect.fromLTWH(0, 0, 100 * u, 100 * u), Paint()..color = color);

  void box(double x, double y, double w, double h, Color color, {double r = 3, Color? stroke, double sw = 1.2}) {
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x * u, y * u, w * u, h * u), Radius.circular(r * u));
    canvas.drawRRect(rect, Paint()..color = color);
    if (stroke != null) {
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw * u
          ..color = stroke,
      );
    }
  }

  void dot(double x, double y, double r, Color color, {Color? stroke, double sw = 1.2}) {
    canvas.drawCircle(Offset(x * u, y * u), r * u, Paint()..color = color);
    if (stroke != null) {
      canvas.drawCircle(
        Offset(x * u, y * u),
        r * u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw * u
          ..color = stroke,
      );
    }
  }

  void line(double x1, double y1, double x2, double y2, Color color, {double w = 1.6}) {
    canvas.drawLine(
      Offset(x1 * u, y1 * u),
      Offset(x2 * u, y2 * u),
      Paint()
        ..color = color
        ..strokeWidth = w * u
        ..strokeCap = StrokeCap.round,
    );
  }

  void poly(List<(double, double)> pts, Color color) {
    final path = Path()..moveTo(pts.first.$1 * u, pts.first.$2 * u);
    for (final p in pts.skip(1)) {
      path.lineTo(p.$1 * u, p.$2 * u);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void label(String text, double x, double y, Color color, {double size = 8}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size * u, fontWeight: FontWeight.w800, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x * u - painter.width / 2, y * u - painter.height / 2));
  }
}

void _missing(_D d) {
  d.fill(const Color(0xFF1A2148));
  d.box(28, 28, 44, 44, const Color(0xFF2A3158), r: 8, stroke: const Color(0xFF6B7280));
}

void _memory(_D d) {
  d.fill(const Color(0xFF1B3A4B));
  d.box(12, 22, 28, 40, const Color(0xFF2E6B8A), r: 4, stroke: _cream);
  d.box(18, 30, 16, 10, const Color(0xFF16324A), r: 2);
  d.box(46, 18, 18, 26, _cream, r: 3, stroke: _ink);
  d.dot(55, 31, 5, _red);
  d.box(66, 22, 18, 26, _cream, r: 3, stroke: _ink);
  d.dot(75, 35, 5, _red);
}

void _smash(_D d) {
  d.fill(const Color(0xFF2C3338));
  d.box(8, 28, 84, 44, const Color(0xFF3D4A40), r: 18);
  d.line(50, 32, 50, 68, _cream, w: 2);
  d.box(38, 40, 28, 16, _red, r: 6);
  d.dot(44, 56, 4, _ink);
  d.dot(60, 56, 4, _ink);
  d.box(70, 22, 14, 10, _gold, r: 2);
}

void _ludo(_D d) {
  d.fill(const Color(0xFF1E4E8C));
  d.box(16, 16, 68, 68, _cream, r: 4, stroke: _ink, sw: 1.4);
  d.box(20, 20, 22, 22, _red, r: 3);
  d.box(58, 20, 22, 22, _blue, r: 3);
  d.box(20, 58, 22, 22, _green, r: 3);
  d.box(58, 58, 22, 22, _gold, r: 3);
  d.dot(31, 31, 3, Colors.white);
  d.dot(69, 31, 3, Colors.white);
  d.dot(31, 69, 3, Colors.white);
  d.box(74, 72, 20, 20, Colors.white, r: 3, stroke: _ink);
  for (final p in const [(79.0, 78.0), (89.0, 78.0), (79.0, 86.0), (89.0, 86.0)]) {
    d.dot(p.$1, p.$2, 1.2, _ink);
  }
}

void _ludoTeams(_D d) {
  d.fill(const Color(0xFF1E4E8C));
  d.box(22, 22, 56, 56, _cream, r: 6, stroke: _ink);
  d.poly(const [(50, 28), (72, 50), (50, 72), (28, 50)], const Color(0xFFE7E2D6));
  d.dot(40, 40, 6, _red);
  d.dot(60, 60, 6, _gold);
  d.dot(60, 40, 6, _green);
  d.dot(40, 60, 6, _blue);
  d.line(40, 40, 60, 60, _ink, w: 1.2);
  d.line(60, 40, 40, 60, _ink, w: 1.2);
}

void _airHockey(_D d) {
  d.fill(const Color(0xFF14324A));
  d.box(14, 16, 72, 68, const Color(0xFFE7F6F8), r: 10, stroke: _ink);
  d.line(14, 50, 86, 50, _blue, w: 2);
  d.dot(50, 50, 5, _red, stroke: _ink);
  d.dot(32, 28, 8, _blue, stroke: _ink, sw: 2);
  d.dot(68, 72, 8, _red, stroke: _ink, sw: 2);
}

void _ticTac(_D d) {
  d.fill(const Color(0xFF243044));
  d.box(18, 16, 64, 68, _cream, r: 6);
  d.line(40, 20, 40, 80, _ink, w: 2);
  d.line(60, 20, 60, 80, _ink, w: 2);
  d.line(22, 38, 78, 38, _ink, w: 2);
  d.line(22, 58, 78, 58, _ink, w: 2);
  d.line(26, 24, 34, 34, _blue, w: 3);
  d.line(34, 24, 26, 34, _blue, w: 3);
  d.dot(70, 70, 6, Colors.transparent, stroke: _red, sw: 3);
}

void _connectFour(_D d) {
  d.fill(const Color(0xFF1A2744));
  d.box(16, 12, 68, 70, const Color(0xFF1E4E8C), r: 6);
  for (var c = 0; c < 7; c++) {
    for (var r = 0; r < 6; r++) {
      final filled = r >= 3 && c >= 1 && c <= 4 && r == 4;
      final yellow = r > 4 && c.isEven;
      d.dot(24 + c * 8.6, 20 + r * 10.0, 3.2, filled ? _red : (yellow ? _gold : const Color(0xFF0E2240)));
    }
  }
}

void _battleship(_D d) {
  d.fill(const Color(0xFF0E4C6E));
  d.box(14, 14, 72, 72, const Color(0xFF1565A8), r: 4, stroke: _cream, sw: 1);
  for (var i = 1; i < 6; i++) {
    d.line(14 + i * 12, 14, 14 + i * 12, 86, const Color(0x66FFFFFF), w: 1);
    d.line(14, 14 + i * 12, 86, 14 + i * 12, const Color(0x66FFFFFF), w: 1);
  }
  d.box(28, 40, 36, 10, const Color(0xFFB0BEC5), r: 3);
  d.dot(34, 28, 3, _red);
  d.dot(58, 62, 2.2, Colors.white);
  d.dot(70, 30, 2.2, Colors.white);
}

void _checkers(_D d) {
  d.fill(const Color(0xFF5B1826));
  for (var r = 0; r < 6; r++) {
    for (var c = 0; c < 6; c++) {
      d.box(16 + c * 11, 16 + r * 11, 11, 11, (r + c).isEven ? const Color(0xFFF5DEB3) : const Color(0xFF6D3B2B), r: 0);
    }
  }
  d.dot(32, 60, 4.5, _red, stroke: _ink);
  d.dot(54, 38, 4.5, _ink);
  d.dot(70, 22, 4.5, _gold, stroke: _ink);
  d.line(36, 56, 50, 42, _cream, w: 1.4);
}

void _snakes(_D d) {
  d.fill(const Color(0xFF1D583D));
  d.box(14, 12, 72, 76, _cream, r: 4, stroke: _ink);
  for (var i = 1; i < 5; i++) {
    d.line(14 + i * 14.4, 12, 14 + i * 14.4, 88, const Color(0xFFD7CBB2), w: 1);
    d.line(14, 12 + i * 15.2, 86, 12 + i * 15.2, const Color(0xFFD7CBB2), w: 1);
  }
  d.line(28, 70, 40, 36, _gold, w: 3);
  d.line(62, 28, 48, 62, _green, w: 3);
  d.dot(48, 62, 3, _red);
}

void _archery(_D d) {
  d.fill(const Color(0xFF245C3A));
  d.dot(50, 48, 28, _cream, stroke: _ink);
  d.dot(50, 48, 20, _red);
  d.dot(50, 48, 12, _cream);
  d.dot(50, 48, 5, _gold);
  d.line(78, 70, 52, 50, _ink, w: 2);
  d.poly(const [(50, 46), (56, 50), (50, 54)], _ink);
}

void _bingo(_D d) {
  d.fill(const Color(0xFF7C3B31));
  d.box(16, 14, 68, 74, _cream, r: 4, stroke: _ink);
  d.label('BINGO', 50, 22, _red, size: 8);
  for (var r = 0; r < 5; r++) {
    for (var c = 0; c < 5; c++) {
      final on = r == c;
      d.box(22 + c * 11, 30 + r * 10, 9, 8, on ? _gold : const Color(0xFFE7E0D4), r: 1);
    }
  }
}

void _clash(_D d) {
  d.fill(const Color(0xFF702531));
  d.box(18, 28, 28, 40, _blue, r: 4, stroke: _ink);
  d.label('7', 32, 48, Colors.white, size: 12);
  d.box(36, 22, 28, 40, _green, r: 4, stroke: _ink);
  d.box(54, 16, 28, 40, _ink, r: 4, stroke: _gold);
  d.label('+4', 68, 36, _gold, size: 10);
}

void _raja(_D d) {
  d.fill(const Color(0xFF471833));
  d.box(16, 30, 22, 32, _cream, r: 3);
  d.box(34, 26, 22, 32, const Color(0xFF8A1C3A), r: 3);
  d.box(52, 30, 22, 32, _cream, r: 3);
  d.box(34, 40, 28, 36, _gold, r: 4, stroke: _ink);
  d.poly(const [(48, 46), (44, 54), (52, 54)], _red);
  d.dot(48, 50, 2, _ink);
}

void _guessPerson(_D d) {
  d.fill(const Color(0xFF7C6534));
  d.box(22, 18, 40, 52, _cream, r: 6, stroke: _ink);
  d.dot(42, 36, 8, const Color(0xFFE7C39A));
  d.box(34, 48, 16, 14, _blue, r: 3);
  d.box(64, 22, 22, 16, Colors.white, r: 6);
  d.label('?', 75, 30, _ink, size: 10);
  d.box(18, 76, 28, 12, _green, r: 4);
  d.label('YES', 32, 82, Colors.white, size: 6);
  d.box(52, 76, 28, 12, _red, r: 4);
  d.label('NO', 66, 82, Colors.white, size: 6);
}

void _guessWho(_D d) {
  d.fill(const Color(0xFF3E4A28));
  d.box(10, 22, 36, 56, _cream, r: 4, stroke: _ink);
  d.box(54, 22, 36, 56, _cream, r: 4, stroke: _ink);
  for (var i = 0; i < 4; i++) {
    d.dot(20 + (i % 2) * 14, 36 + (i ~/ 2) * 18, 4, const Color(0xFFE7C39A));
    d.dot(64 + (i % 2) * 14, 36 + (i ~/ 2) * 18, 4, i == 2 ? _gold : const Color(0xFF8D6E63));
  }
}

void _dots(_D d) {
  d.fill(const Color(0xFF2C3E50));
  d.box(16, 16, 68, 68, _cream, r: 4);
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 4; c++) {
      d.dot(28 + c * 14, 28 + r * 14, 2, _ink);
    }
  }
  d.line(28, 28, 42, 28, _blue, w: 2);
  d.line(28, 28, 28, 42, _blue, w: 2);
  d.line(28, 42, 42, 42, _blue, w: 2);
  d.line(42, 28, 42, 42, _blue, w: 2);
  d.box(28, 28, 14, 14, const Color(0x552E8BFF), r: 0);
}

void _pong(_D d) {
  d.fill(const Color(0xFF1B3A2F));
  d.box(18, 14, 64, 72, const Color(0xFF2E7D4F), r: 4, stroke: _cream);
  d.line(18, 50, 82, 50, _cream, w: 2);
  d.box(40, 22, 18, 6, _cream, r: 2);
  d.dot(58, 64, 4, _gold);
}

void _hoops(_D d) {
  d.fill(const Color(0xFF243044));
  d.box(28, 22, 44, 6, _red, r: 2);
  d.line(28, 28, 40, 48, _cream, w: 1.4);
  d.line(72, 28, 60, 48, _cream, w: 1.4);
  d.line(40, 48, 60, 48, _cream, w: 1.4);
  d.dot(50, 62, 8, _gold, stroke: _ink);
}

void _paint(_D d) {
  d.fill(const Color(0xFFE7E2D6));
  d.dot(32, 40, 14, _red);
  d.dot(58, 36, 12, _blue);
  d.dot(48, 58, 16, _gold);
  d.dot(70, 64, 8, _green);
}

void _react(_D d) {
  d.fill(const Color(0xFF1A1440));
  d.dot(50, 50, 26, _gold, stroke: _ink, sw: 2);
  d.poly(const [(50, 34), (44, 52), (50, 52), (46, 66), (58, 46), (52, 46)], _ink);
}

void _math(_D d) {
  d.fill(const Color(0xFF243044));
  d.box(14, 22, 72, 28, _cream, r: 6);
  d.label('8 + 5', 50, 36, _ink, size: 12);
  d.box(16, 60, 30, 20, _blue, r: 6);
  d.label('13', 31, 70, Colors.white, size: 10);
  d.box(54, 60, 30, 20, const Color(0xFF3A4458), r: 6);
  d.label('12', 69, 70, _cream, size: 10);
}

void _cricket(_D d) {
  d.fill(const Color(0xFF1D583D));
  d.line(30, 78, 58, 28, _wood, w: 5);
  d.dot(66, 36, 6, _red);
  d.line(22, 70, 22, 86, _cream, w: 2);
  d.line(28, 70, 28, 86, _cream, w: 2);
  d.line(22, 70, 28, 70, _gold, w: 2);
}

void _quiz(_D d) {
  d.fill(const Color(0xFF2A2158));
  d.box(18, 16, 64, 40, _cream, r: 8);
  d.label('?', 50, 36, _blue, size: 18);
  d.box(18, 64, 28, 16, _green, r: 6);
  d.box(52, 64, 28, 16, _red, r: 6);
}

void _fruitBattle(_D d) {
  d.fill(const Color(0xFF3E2723));
  d.dot(32, 48, 16, _red);
  d.dot(68, 48, 16, _gold);
  d.dot(50, 48, 8, _green);
  d.line(44, 48, 56, 48, _cream, w: 2);
}

void _golf(_D d) {
  d.fill(const Color(0xFF1D583D));
  d.box(0, 58, 100, 42, const Color(0xFF2E9B57), r: 0);
  d.dot(62, 62, 6, _ink);
  d.line(62, 62, 62, 36, _cream, w: 2);
  d.poly(const [(62, 36), (74, 40), (62, 44)], _red);
  d.dot(28, 74, 4, Colors.white);
}

void _sling(_D d) {
  d.fill(const Color(0xFF87CEEB));
  d.line(24, 70, 24, 36, _wood, w: 3);
  d.line(24, 36, 40, 48, _ink, w: 1.5);
  d.dot(44, 50, 5, _red);
  d.box(64, 40, 18, 28, _wood, r: 2);
  d.box(68, 28, 14, 14, _green, r: 2);
}

void _gallery(_D d) {
  d.fill(const Color(0xFF5C3A1E));
  d.line(16, 62, 84, 62, _ink, w: 3);
  d.box(22, 40, 16, 12, _gold, r: 6);
  d.box(44, 36, 16, 12, _green, r: 6);
  d.box(66, 42, 16, 12, _gold, r: 6);
  d.dot(50, 24, 8, Colors.transparent, stroke: _red, sw: 2);
  d.line(42, 24, 58, 24, _red, w: 1.2);
  d.line(50, 16, 50, 32, _red, w: 1.2);
}

void _bottles(_D d) {
  d.fill(const Color(0xFF243044));
  d.box(18, 36, 12, 36, const Color(0xFF8D6E63), r: 3);
  d.box(36, 30, 12, 42, _green, r: 3);
  d.box(58, 48, 18, 10, _cream, r: 2);
  d.box(64, 58, 8, 16, const Color(0xFF8D6E63), r: 2);
  d.line(54, 44, 78, 52, _cream, w: 1.2);
}

void _spy(_D d) {
  d.fill(const Color(0xFF1A1440));
  for (var i = 0; i < 4; i++) {
    d.dot(20 + i * 20, 48, 10, i == 2 ? _gold : const Color(0xFF3A4458));
    d.box(14 + i * 20, 60, 12, 16, i == 2 ? _gold : const Color(0xFF2A3158), r: 3);
  }
  d.box(50, 40, 12, 6, _ink, r: 2);
}

void _mafia(_D d) {
  d.fill(const Color(0xFF12142C));
  d.dot(72, 24, 10, _cream);
  d.dot(78, 24, 8, const Color(0xFF12142C));
  d.dot(46, 48, 12, const Color(0xFF2A2158));
  d.box(34, 58, 24, 22, _ink, r: 6);
}

void _undercover(_D d) {
  d.fill(const Color(0xFF1A2744));
  d.box(14, 28, 32, 40, _cream, r: 4);
  d.label('CAT', 30, 48, _ink, size: 8);
  d.box(54, 28, 32, 40, const Color(0xFF2A2158), r: 4, stroke: _gold);
  d.label('BAT', 70, 48, _gold, size: 8);
}

void _charades(_D d) {
  d.fill(const Color(0xFF3E2723));
  d.dot(40, 40, 10, const Color(0xFFE7C39A));
  d.line(40, 50, 40, 74, _blue, w: 3);
  d.line(40, 58, 26, 48, _blue, w: 3);
  d.line(40, 58, 56, 46, _blue, w: 3);
  d.box(62, 22, 22, 16, _ink, r: 2);
  d.box(62, 30, 22, 8, _cream, r: 1);
}

void _heads(_D d) {
  d.fill(const Color(0xFF245C3A));
  d.dot(50, 62, 16, const Color(0xFFE7C39A));
  d.box(36, 28, 28, 40, const Color(0xFF1C1A17), r: 4, stroke: _cream);
  d.label('?', 50, 48, _gold, size: 14);
}

void _draw(_D d) {
  d.fill(const Color(0xFF5C3A1E));
  d.box(16, 16, 56, 64, _cream, r: 4, stroke: _ink);
  d.dot(36, 36, 6, _ink);
  d.line(28, 58, 48, 50, _blue, w: 2);
  d.line(70, 70, 84, 40, _wood, w: 3);
  d.poly(const [(84, 36), (88, 44), (80, 44)], _ink);
}

void _likely(_D d) {
  d.fill(const Color(0xFF2A2158));
  d.dot(28, 42, 10, const Color(0xFFE7C39A));
  d.dot(50, 38, 12, const Color(0xFFE7C39A));
  d.dot(72, 42, 10, const Color(0xFFE7C39A));
  d.line(50, 58, 50, 78, _gold, w: 3);
  d.poly(const [(50, 82), (44, 72), (56, 72)], _gold);
}

void _rather(_D d) {
  d.fill(const Color(0xFF243044));
  d.box(12, 22, 34, 56, _blue, r: 8);
  d.label('A', 29, 50, Colors.white, size: 16);
  d.box(54, 22, 34, 56, _red, r: 8);
  d.label('B', 71, 50, Colors.white, size: 16);
}

void _truth(_D d) {
  d.fill(const Color(0xFF3E2723));
  d.dot(50, 50, 8, _green, stroke: _ink);
  d.box(46, 28, 8, 22, _cream, r: 2);
  for (var i = 0; i < 4; i++) {
    d.dot(i.isEven ? 24 : 76, i < 2 ? 28 : 74, 6, const Color(0xFFE7C39A));
  }
}

void _rps(_D d) {
  d.fill(const Color(0xFF2C3E50));
  d.dot(28, 50, 14, const Color(0xFF8D6E63), stroke: _ink);
  d.box(44, 34, 20, 28, _cream, r: 3, stroke: _ink);
  d.line(78, 30, 70, 70, const Color(0xFFB0BEC5), w: 3);
  d.line(70, 70, 86, 70, const Color(0xFFB0BEC5), w: 3);
}

void _bike(_D d) {
  d.fill(const Color(0xFF1B5E20));
  d.line(20, 40, 80, 40, _cream, w: 1.2);
  d.line(20, 64, 80, 64, _cream, w: 1.2);
  d.dot(34, 48, 6, _red);
  d.dot(26, 56, 4, _ink);
  d.dot(42, 56, 4, _ink);
  d.dot(66, 36, 6, _blue);
  d.dot(58, 44, 4, _ink);
  d.dot(74, 44, 4, _ink);
}

void _hippos(_D d) {
  d.fill(const Color(0xFF1565A8));
  d.dot(28, 70, 16, _green, stroke: _ink);
  d.box(20, 64, 16, 6, _ink, r: 2);
  d.dot(72, 70, 16, _red, stroke: _ink);
  d.box(64, 64, 16, 6, _ink, r: 2);
  d.dot(40, 36, 5, Colors.white);
  d.dot(58, 28, 5, _gold);
  d.dot(50, 48, 4, Colors.white);
}

void _tug(_D d) {
  d.fill(const Color(0xFF5C3A1E));
  d.line(16, 52, 84, 52, _wood, w: 4);
  d.dot(24, 44, 8, _red);
  d.dot(76, 44, 8, _blue);
  d.box(46, 40, 8, 18, _cream, r: 1);
}

void _carrom(_D d) {
  d.fill(const Color(0xFF6D4C41));
  d.box(14, 14, 72, 72, const Color(0xFFE6D3A3), r: 6, stroke: _ink);
  for (final p in const [(22.0, 22.0), (78.0, 22.0), (22.0, 78.0), (78.0, 78.0)]) {
    d.dot(p.$1, p.$2, 4, _ink);
  }
  d.dot(44, 50, 5, _red);
  d.dot(56, 46, 4, _ink);
  d.dot(50, 60, 6, _cream, stroke: _ink);
}

void _eight(_D d) {
  d.fill(const Color(0xFF1B3A2F));
  d.box(12, 18, 76, 64, const Color(0xFF1B5E20), r: 8, stroke: _wood, sw: 3);
  for (final p in const [(20.0, 26.0), (80.0, 26.0), (20.0, 74.0), (80.0, 74.0)]) {
    d.dot(p.$1, p.$2, 4, _ink);
  }
  d.dot(40, 46, 4, Colors.white, stroke: _ink);
  d.dot(52, 50, 4, _gold, stroke: _ink);
  d.dot(62, 44, 4, _ink, stroke: _cream);
  d.line(70, 78, 58, 56, _wood, w: 3);
}

void _mineRace(_D d) {
  d.fill(const Color(0xFF243044));
  d.box(10, 22, 36, 56, _cream, r: 3);
  d.box(54, 22, 36, 56, _cream, r: 3);
  d.dot(22, 36, 3, _red);
  d.dot(66, 40, 3, _ink);
  d.line(78, 30, 78, 46, _gold, w: 2);
  d.poly(const [(78, 30), (88, 34), (78, 38)], _red);
}

void _fruitMerge(_D d) {
  d.fill(const Color(0xFF3E2723));
  d.dot(36, 62, 12, _red);
  d.dot(54, 66, 10, _gold);
  d.dot(50, 36, 16, _green, stroke: _ink);
}

void _fruitCut(_D d) {
  d.fill(const Color(0xFF1B3A2F));
  d.dot(36, 58, 16, _red);
  d.line(28, 50, 48, 68, _cream, w: 2);
  d.dot(68, 34, 10, _gold);
  d.line(22, 28, 78, 70, Colors.white, w: 2);
}

void _chicken(_D d) {
  d.fill(const Color(0xFF87CEEB));
  d.box(62, 8, 16, 28, _green, r: 2);
  d.box(62, 64, 16, 28, _green, r: 2);
  d.dot(32, 50, 10, _gold, stroke: _ink);
  d.poly(const [(40, 48), (48, 50), (40, 54)], _red);
}

void _knife(_D d) {
  d.fill(const Color(0xFF3E2723));
  d.dot(50, 46, 22, const Color(0xFF8D6E63), stroke: _ink);
  d.line(50, 28, 50, 8, const Color(0xFFB0BEC5), w: 3);
  d.line(32, 46, 12, 40, const Color(0xFFB0BEC5), w: 3);
  d.line(68, 50, 88, 58, const Color(0xFFB0BEC5), w: 3);
}

void _candy(_D d) {
  d.fill(const Color(0xFF2A2158));
  const shades = [_red, _blue, _green, _gold, Color(0xFF8E24AA)];
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 4; c++) {
      d.box(16 + c * 18, 14 + r * 18, 14, 14, shades[(r * 2 + c) % shades.length], r: 4);
    }
  }
}

void _g2048(_D d) {
  d.fill(const Color(0xFFBBADA0));
  d.box(14, 22, 32, 32, _cream, r: 4);
  d.label('2', 30, 38, _ink, size: 14);
  d.box(52, 22, 32, 32, _gold, r: 4);
  d.label('4', 68, 38, Colors.white, size: 14);
  d.box(32, 60, 36, 24, _red, r: 4);
  d.label('8', 50, 72, Colors.white, size: 12);
}

void _flappy(_D d) {
  d.fill(const Color(0xFF87CEEB));
  d.box(64, 8, 16, 30, _green, r: 2);
  d.box(64, 62, 16, 32, _green, r: 2);
  d.dot(32, 46, 8, _gold, stroke: _ink);
  d.poly(const [(38, 44), (46, 46), (38, 50)], _red);
}

void _mines(_D d) {
  d.fill(const Color(0xFF5C564C));
  d.box(16, 16, 68, 68, _cream, r: 3, stroke: _ink);
  for (var i = 1; i < 4; i++) {
    d.line(16 + i * 17, 16, 16 + i * 17, 84, const Color(0xFFD7CBB2), w: 1);
    d.line(16, 16 + i * 17, 84, 16 + i * 17, const Color(0xFFD7CBB2), w: 1);
  }
  d.label('1', 28, 28, _blue, size: 8);
  d.dot(62, 62, 5, _ink);
  d.line(78, 24, 78, 40, _gold, w: 2);
}

void _bricks(_D d) {
  d.fill(const Color(0xFF1A2744));
  for (var r = 0; r < 3; r++) {
    for (var c = 0; c < 5; c++) {
      d.box(12 + c * 16, 14 + r * 10, 14, 8, r == 0 ? _red : (r == 1 ? _gold : _blue), r: 1);
    }
  }
  d.dot(48, 62, 4, _cream);
  d.box(34, 80, 28, 6, _cream, r: 2);
}

void _mole(_D d) {
  d.fill(const Color(0xFF1D583D));
  for (final p in const [(30.0, 62.0), (70.0, 62.0), (50.0, 78.0)]) {
    d.box(p.$1 - 12, p.$2 - 6, 24, 12, const Color(0xFF3E2723), r: 6);
  }
  d.dot(50, 40, 12, const Color(0xFF8D6E63), stroke: _ink);
  d.dot(46, 38, 1.5, _ink);
  d.dot(54, 38, 1.5, _ink);
}

void _piano(_D d) {
  d.fill(const Color(0xFF12142C));
  for (var i = 0; i < 4; i++) {
    d.box(12 + i * 20, 16, 18, 68, i == 2 ? _gold : _cream, r: 2);
  }
}

void _scramble(_D d) {
  d.fill(const Color(0xFF243044));
  for (var i = 0; i < 4; i++) {
    d.box(12 + i * 20, 24, 16, 16, _cream, r: 3);
  }
  d.label('T', 20, 32, _ink, size: 8);
  d.label('A', 40, 32, _ink, size: 8);
  d.label('C', 60, 32, _ink, size: 8);
  d.label('S', 80, 32, _ink, size: 8);
  d.box(22, 58, 56, 16, const Color(0xFF1A2148), r: 3, stroke: _gold);
}

void _stack(_D d) {
  d.fill(const Color(0xFF87CEEB));
  d.box(24, 70, 52, 10, _wood, r: 2);
  d.box(30, 58, 48, 10, _red, r: 2);
  d.box(20, 46, 44, 10, _blue, r: 2);
  d.box(36, 28, 48, 10, _gold, r: 2);
}

void _simon(_D d) {
  d.fill(const Color(0xFF12142C));
  d.dot(50, 50, 34, _ink);
  d.box(22, 18, 26, 26, _green, r: 8);
  d.box(52, 18, 26, 26, _red, r: 8);
  d.box(22, 52, 26, 26, _gold, r: 8);
  d.box(52, 52, 26, 26, _blue, r: 8);
  d.dot(50, 50, 8, _cream);
}

void _sort(_D d) {
  d.fill(const Color(0xFF2C3E50));
  const shades = [_red, _blue, _green, _gold];
  for (var t = 0; t < 4; t++) {
    d.box(14 + t * 20, 22, 14, 56, const Color(0x22FFFFFF), r: 8, stroke: _cream, sw: 1.4);
    for (var b = 0; b < 3; b++) {
      d.dot(21 + t * 20, 66 - b * 12, 4.5, shades[(t + b) % 4]);
    }
  }
}

void _slide(_D d) {
  d.fill(const Color(0xFF5C3A1E));
  const labels = ['1', '2', '3', '4', '', '5', '6', '7', '8'];
  for (var i = 0; i < 9; i++) {
    if (labels[i].isEmpty) continue;
    d.box(18 + (i % 3) * 22, 16 + (i ~/ 3) * 22, 18, 18, _cream, r: 3);
    d.label(labels[i], 27 + (i % 3) * 22, 25 + (i ~/ 3) * 22, _ink, size: 8);
  }
}

void _sudoku(_D d) {
  d.fill(const Color(0xFF243044));
  d.box(14, 14, 72, 72, _cream, r: 2);
  for (var i = 1; i < 4; i++) {
    d.line(14 + i * 18, 14, 14 + i * 18, 86, _ink, w: i == 2 ? 2 : 1);
    d.line(14, 14 + i * 18, 86, 14 + i * 18, _ink, w: i == 2 ? 2 : 1);
  }
  d.label('5', 23, 23, _ink, size: 8);
  d.label('3', 59, 41, _blue, size: 8);
  d.label('9', 77, 77, _ink, size: 8);
}

void _hangman(_D d) {
  d.fill(const Color(0xFFE7E2D6));
  d.line(24, 82, 70, 82, _ink, w: 2);
  d.line(34, 82, 34, 18, _ink, w: 2);
  d.line(34, 18, 58, 18, _ink, w: 2);
  d.line(58, 18, 58, 28, _ink, w: 2);
  d.dot(58, 34, 5, Colors.transparent, stroke: _ink, sw: 2);
  d.line(58, 40, 58, 58, _ink, w: 2);
  d.line(28, 74, 40, 74, _blue, w: 3);
  d.line(46, 74, 58, 74, _blue, w: 3);
  d.line(64, 74, 76, 74, _blue, w: 3);
}

void _dino(_D d) {
  d.fill(const Color(0xFFF4F1EA));
  d.line(8, 78, 92, 78, _ink, w: 2);
  d.box(22, 48, 22, 16, const Color(0xFF546E7A), r: 3);
  d.box(36, 40, 10, 10, const Color(0xFF546E7A), r: 2);
  d.line(22, 64, 26, 78, _ink, w: 2);
  d.line(38, 64, 42, 74, _ink, w: 2);
  d.box(68, 58, 10, 20, _green, r: 2);
}

void _drop(_D d) {
  d.fill(const Color(0xFF12142C));
  d.box(28, 62, 14, 14, _blue, r: 2);
  d.box(42, 62, 14, 14, _blue, r: 2);
  d.box(42, 48, 14, 14, _blue, r: 2);
  d.box(56, 62, 14, 14, _gold, r: 2);
  d.box(36, 18, 14, 14, _red, r: 2);
  d.box(50, 18, 14, 14, _red, r: 2);
  d.box(36, 32, 14, 14, _red, r: 2);
  d.box(50, 32, 14, 14, _red, r: 2);
}

void _bubbles(_D d) {
  d.fill(const Color(0xFF1A2744));
  const shades = [_red, _blue, _green, _gold, _red, _blue];
  for (var i = 0; i < 6; i++) {
    d.dot(30 + (i % 3) * 16, 24 + (i ~/ 3) * 16, 7, shades[i], stroke: Colors.white, sw: 1);
  }
  d.line(50, 88, 50, 70, _cream, w: 3);
  d.dot(50, 64, 6, _green, stroke: Colors.white);
}

void _sky(_D d) {
  d.fill(const Color(0xFF87CEEB));
  d.box(10, 70, 28, 8, _green, r: 2);
  d.box(48, 52, 28, 8, _green, r: 2);
  d.box(24, 32, 24, 8, _green, r: 2);
  d.dot(36, 24, 6, _gold, stroke: _ink);
}

void _space(_D d) {
  d.fill(const Color(0xFF0B1026));
  d.dot(20, 20, 1.2, Colors.white);
  d.dot(70, 16, 1.2, Colors.white);
  d.dot(80, 40, 1.2, Colors.white);
  d.poly(const [(50, 70), (40, 86), (60, 86)], _blue);
  d.line(50, 62, 50, 48, _gold, w: 2);
  d.dot(50, 28, 8, _green, stroke: _cream);
}

void _switch(_D d) {
  d.fill(const Color(0xFF12142C));
  d.dot(50, 42, 22, _red);
  d.box(28, 20, 22, 22, _blue, r: 0);
  d.box(50, 42, 22, 22, _gold, r: 0);
  d.dot(50, 78, 6, _cream);
}

void _duel(_D d) {
  d.fill(const Color(0xFF3E2723));
  d.dot(32, 50, 16, _red);
  d.line(48, 34, 48, 66, _cream, w: 2);
  d.dot(68, 50, 16, _green);
}

void _snake(_D d) {
  d.fill(const Color(0xFF1D583D));
  d.dot(30, 60, 6, _green);
  d.dot(42, 60, 6, _green);
  d.dot(54, 52, 6, _green);
  d.dot(54, 40, 6, const Color(0xFF7CDE6A), stroke: _ink);
  d.dot(74, 36, 5, _red);
}

void _snakeDuel(_D d) {
  d.fill(const Color(0xFF1D583D));
  d.dot(24, 40, 5, _green);
  d.dot(36, 40, 5, _green);
  d.dot(48, 48, 5, _green);
  d.dot(76, 64, 5, _gold);
  d.dot(64, 64, 5, _gold);
  d.dot(52, 56, 5, _gold);
  d.dot(50, 28, 4, _red);
}

void _penalty(_D d) {
  d.fill(const Color(0xFF1D583D));
  d.line(22, 30, 22, 78, _cream, w: 3);
  d.line(78, 30, 78, 78, _cream, w: 3);
  d.line(22, 30, 78, 30, _cream, w: 3);
  d.line(22, 78, 78, 78, _cream, w: 3);
  d.dot(50, 48, 8, _blue);
  d.dot(50, 70, 5, _cream, stroke: _ink);
}

void _crush(_D d) {
  d.fill(const Color(0xFF2C3E50));
  d.box(22, 48, 18, 18, _red, r: 3);
  d.box(44, 48, 18, 18, _blue, r: 3);
  d.box(66, 56, 14, 10, const Color(0xFF8D6E63), r: 2);
  d.box(40, 18, 28, 12, const Color(0xFFB0BEC5), r: 2);
  d.box(50, 30, 8, 16, _wood, r: 1);
}

final Map<String, void Function(_D)> _scenes = {
  'memory': _memory,
  'smash_karts': _smash,
  'ludo': _ludo,
  'ludo_teams': _ludoTeams,
  'air_hockey': _airHockey,
  'tic_tac_toe': _ticTac,
  'connect_four': _connectFour,
  'battleship': _battleship,
  'checkers': _checkers,
  'snakes_ladders': _snakes,
  'archery': _archery,
  'bingo': _bingo,
  'colour_clash': _clash,
  'raja_mantri': _raja,
  'guess_person': _guessPerson,
  'guess_who': _guessWho,
  'dots_boxes': _dots,
  'ping_pong': _pong,
  'basketball_hoops': _hoops,
  'paint_fight': _paint,
  'reaction_tap': _react,
  'math_duel': _math,
  'hand_cricket': _cricket,
  'quiz_battle': _quiz,
  'fruit_merge_battle': _fruitBattle,
  'mini_golf': _golf,
  'slingshot': _sling,
  'shooting_gallery': _gallery,
  'bottle_smash': _bottles,
  'find_spy': _spy,
  'mafia': _mafia,
  'undercover': _undercover,
  'charades': _charades,
  'heads_up': _heads,
  'draw_guess': _draw,
  'most_likely': _likely,
  'would_rather': _rather,
  'truth_dare': _truth,
  'rock_paper_scissors': _rps,
  'bike_race': _bike,
  'hungry_hippos': _hippos,
  'tug_of_war': _tug,
  'carrom': _carrom,
  'eight_ball': _eight,
  'minesweeper_race': _mineRace,
  'fruit_merge': _fruitMerge,
  'fruit_cut': _fruitCut,
  'chicken_jump': _chicken,
  'knife_hit': _knife,
  'sweet_swap': _candy,
  'game_2048': _g2048,
  'flappy_jump': _flappy,
  'minesweeper': _mines,
  'brick_breaker': _bricks,
  'whack_mole': _mole,
  'piano_tiles': _piano,
  'word_scramble': _scramble,
  'stack_tower': _stack,
  'simon_says': _simon,
  'ball_sort': _sort,
  'sliding_puzzle': _slide,
  'sudoku': _sudoku,
  'hangman': _hangman,
  'dino_run': _dino,
  'block_drop': _drop,
  'bubble_shooter': _bubbles,
  'sky_jumper': _sky,
  'space_shooter': _space,
  'color_switch': _switch,
  'fruit_duel': _duel,
  'classic_snake': _snake,
  'snake_duel': _snakeDuel,
  'penalty': _penalty,
  'crush_it': _crush,
};
