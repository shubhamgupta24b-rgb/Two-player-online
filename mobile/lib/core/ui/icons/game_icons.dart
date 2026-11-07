import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'svg_path.dart';

export 'svg_path.dart' show svgPath;

/// The app's icon set, all on one 24 grid. Interface icons draw in [GameIcon.color] with one
/// line weight. "Things" (fruit, pieces, characters) are flat two-tone cut-outs from one warm
/// palette, with no highlights or gradients.
enum GameIcons {
  // App and HUD
  back, forward, close, pause, play, help, restart, sound, vibration, clock, globe, wifi, trophy, copy, share, search, settings,
  plus, minus, people, check, cross, undo, skip, eye, lock, lightbulb, flag, star, heart, heartEmpty, shield, crown, crownKing, coin,
  target, wind, arrow, bow, home, chevronDown,
  // Weapons and power-ups (Smash Karts, shooters)
  rocket, tripleRocket, mine, bolt, gun, mysteryBox, bomb,
  // Dice
  dice1, dice2, dice3, dice4, dice5, dice6,
  // Characters and game things
  duck, rabbit, mole, goldenMole, alien, ufo, tank, cactus, bird, pig, ladder, snake, rock, paper, scissors, bat, ball, cricketBall,
  puck, mallet, football, glove, bottle, woodBlock, stoneBlock, paintBrush, pencil, magnifier, mask, scroll, moon, sun, medical,
  clapper, speech, hammer, arrowLeft, arrowRight, arrowUp, arrowDown, rotate, drop,
  // Fruit
  apple, banana, grapes, watermelon, strawberry, kiwi, cherry, mango, peach, pineapple, coconut, lemon, orange, pear, melon,
}

/// The fruit drawings, in the order games use them.
const fruitIcons = [
  GameIcons.apple, GameIcons.banana, GameIcons.grapes, GameIcons.watermelon, GameIcons.strawberry, GameIcons.kiwi, GameIcons.cherry, GameIcons.mango,
  GameIcons.peach, GameIcons.pineapple, GameIcons.coconut, GameIcons.lemon, GameIcons.orange, GameIcons.pear, GameIcons.melon,
];

/// A drawn icon. [color] is used by stroke-style icons and "current colour" parts.
class GameIcon extends StatelessWidget {
  final GameIcons icon;
  final double size;
  final Color color;
  final String? semanticLabel;
  const GameIcon(this.icon, {super.key, this.size = 24, this.color = const Color(0xFFF5EFE4), this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final art = CustomPaint(size: Size.square(size), painter: GameIconPainter(icon, color));
    if (semanticLabel == null) return ExcludeSemantics(child: art);
    return Semantics(label: semanticLabel, image: true, child: art);
  }
}

/// Paints one [GameIcons] icon scaled to the canvas size. Usable directly in game painters
/// through [paintIcon].
class GameIconPainter extends CustomPainter {
  final GameIcons icon;
  final Color color;
  const GameIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) => paintIcon(canvas, icon, Offset.zero & size, color: color);

  @override
  bool shouldRepaint(GameIconPainter old) => old.icon != icon || old.color != color;
}

/// Draws [icon] into [rect] on [canvas] (for game scenes that draw icons themselves).
void paintIcon(Canvas canvas, GameIcons icon, Rect rect, {Color color = Colors.white}) {
  final art = _Art.of(icon);
  final s = (rect.width < rect.height ? rect.width : rect.height) / art.box;
  canvas.save();
  canvas.translate(rect.center.dx - art.box * s / 2, rect.center.dy - art.box * s / 2);
  canvas.scale(s);
  for (final ink in art.inks) {
    ink.paint(canvas, color);
  }
  canvas.restore();
}

class _Art {
  final double box; // viewBox size
  final List<IconInk> inks;
  const _Art(this.box, this.inks);

  static final _cache = <GameIcons, _Art>{};
  static _Art of(GameIcons i) => _cache.putIfAbsent(i, () => _build(i));
}

// Small builders. `cs` = stroke in the icon colour, `cf` = fill in the icon colour.
IconInk _f(String d, Color c, {double o = 1}) => IconInk(svgPath(d), fill: c, opacity: o);
IconInk _fp(Path p, Color c, {double o = 1}) => IconInk(p, fill: c, opacity: o);
IconInk _s(String d, Color c, double w, {double o = 1}) => IconInk(svgPath(d), stroke: c, style: InkStroke(w), opacity: o);
IconInk _cs(String d, [double w = 2]) => IconInk(svgPath(d), strokeCurrent: true, style: InkStroke(w));
IconInk _csp(Path p, [double w = 2]) => IconInk(p, strokeCurrent: true, style: InkStroke(w));
IconInk _cf(String d) => IconInk(svgPath(d), fillCurrent: true);
IconInk _cfp(Path p) => IconInk(p, fillCurrent: true);

// The palette of "things": warm, flat, two tones each, no highlights.
const _ink = Color(0xFF2A1C05);
const _bone = Color(0xFFFBF3E2);
const _boneDark = Color(0xFFDCCFB6);
const _gold = Color(0xFFF6A91B);
const _goldDeep = Color(0xFFB87708);
const _red = Color(0xFFD9423D);
const _redDeep = Color(0xFF9E2A2B);
const _leaf = Color(0xFF3F9A5B);
const _leafDeep = Color(0xFF2B6F41);
const _stem = Color(0xFF6B4A2F);
const _wood = Color(0xFFC98F4F);
const _woodDeep = Color(0xFF8C5D2C);
const _steel = Color(0xFF8E98A3);
const _steelDeep = Color(0xFF59626C);
const _blue = Color(0xFF3B86D9);
const _blueDeep = Color(0xFF1F5A9E);
const _plum = Color(0xFF7A4FB5);
const _plumDeep = Color(0xFF55337F);
const _pink = Color(0xFFF08FA6);
const _skin = Color(0xFFE5B28A);

List<IconInk> _dice(List<(double, double)> pips) => [
      _fp(svgRect(2.5, 3.5, 19, 19, 5), _boneDark),
      _fp(svgRect(2.5, 2, 19, 19, 5), _bone),
      for (final (x, y) in pips) _fp(svgCircle(x, y, 1.9), _ink),
    ];

List<IconInk> _rocket() => [
      _f('M12 1.5c3.6 2.6 5 7 4.2 13H7.800c-.8-6 .6-10.400 4.200-13z', _bone),
      _f('M12 1.500c1.700 1.200 2.900 2.800 3.600 4.800H8.400c.7-2 1.900-3.600 3.600-4.800z', _red),
      _f('M7.800 12 4 18h4zM16.200 12 20 18h-4z', _redDeep),
      _fp(svgCircle(12, 10, 1.9), _blue),
      _f('M9.800 15.500h4.400L12 22z', _gold),
    ];

List<IconInk> _mole(Color fur, Color dark) => [
      _f('M4 23c0-10 3.400-16 8-16s8 6 8 16z', fur),
      _fp(svgEllipse(12, 16.500, 4, 3), dark),
      _fp(svgCircle(9, 11.500, 1.200), _ink),
      _fp(svgCircle(15, 11.500, 1.200), _ink),
      _fp(svgEllipse(12, 14.500, 1.500, 1.100), _pink),
      _f('M10.900 18h2.200v2.200h-2.200z', _bone),
    ];

/// A round fruit in the flat two-tone style: body, darker lower crescent, leaf.
List<IconInk> _round(Color body, Color deep, {double cy = 13.500, double r = 8.500}) => [
      _fp(svgCircle(12, cy, r), body),
      IconInk(svgCircle(9.500, cy - 2.500, r), fill: const Color(0x00000000)),
      IconInk(svgCircle(12, cy + r * 0.45, r * 0.8), fill: deep, opacity: 0.55, clip: svgCircle(12, cy, r)),
      _s('M12 ${cy - r + 0.5} Q12.300 3.800 13.300 2.800', _stem, 1.500),
      _f('M13 4.800 Q17 1.500 20 4 Q16.500 7 13 4.800Z', _leaf),
    ];

_Art _build(GameIcons i) {
  switch (i) {
    // App and HUD: one solid-ended 2 px line weight on a 24 grid, in the current colour.
    case GameIcons.back:
      return _Art(24, [_cs('M15 5l-7 7 7 7', 2.400)]);
    case GameIcons.forward:
      return _Art(24, [_cs('M9 5l7 7-7 7', 2.400)]);
    case GameIcons.close:
      return _Art(24, [_cs('M6 6l12 12M18 6 6 18', 2.400)]);
    case GameIcons.cross:
      return _Art(24, [_cs('M5.500 5.500l13 13M18.500 5.500l-13 13', 3.400)]);
    case GameIcons.pause:
      return _Art(24, [_cfp(svgRect(6, 4.500, 4.200, 15, 1.500)), _cfp(svgRect(13.800, 4.500, 4.200, 15, 1.500))]);
    case GameIcons.play:
      return _Art(24, [_cf('M7.500 4.700c0-1 1.100-1.600 1.900-1.100l11 7.300c.8.500.8 1.700 0 2.200l-11 7.300c-.8.500-1.900-.1-1.900-1.100z')]);
    case GameIcons.help:
      return _Art(24, [_csp(svgCircle(12, 12, 9.500)), _cs('M9.300 9.300a2.800 2.800 0 1 1 4.200 2.400c-.9.600-1.500 1.200-1.500 2.300', 2.200), _cfp(svgCircle(12, 17.200, 1.300))]);
    case GameIcons.restart:
      return _Art(24, [_cs('M19.500 12a7.500 7.500 0 1 1-2.300-5.400', 2.300), _cf('M20.500 2.800v6h-6z')]);
    case GameIcons.undo:
      return _Art(24, [_cs('M9 14 4.500 9.500 9 5', 2.300), _cs('M5 9.500h9.500a5 5 0 0 1 0 10H9', 2.300)]);
    case GameIcons.sound:
      return _Art(24, [_cf('M3.500 9.300c0-.7.600-1.300 1.300-1.300H8l4.300-3.600c.6-.5 1.700-.1 1.700.8v13.600c0 .9-1.100 1.300-1.700.8L8 16H4.800c-.7 0-1.300-.6-1.300-1.300z'), _cs('M17.300 8.500a5 5 0 0 1 0 7M19.800 6a8.500 8.500 0 0 1 0 12', 2)]);
    case GameIcons.vibration:
      return _Art(24, [_csp(svgRect(8, 3.500, 8, 17, 2.200)), _cs('M4.800 8v8M19.200 8v8M2 10.500v3M22 10.500v3', 2)]);
    case GameIcons.clock:
      return _Art(24, [_csp(svgCircle(12, 12, 9.500)), _cs('M12 6.800V12l3.600 2.200', 2.300)]);
    case GameIcons.globe:
      return _Art(24, [_csp(svgCircle(12, 12, 9.500)), _cs('M2.800 12h18.400M12 2.500c3 2.800 4.300 6 4.300 9.500s-1.300 6.700-4.300 9.500c-3-2.800-4.300-6-4.300-9.500S9 5.300 12 2.500z', 1.900)]);
    case GameIcons.wifi:
      return _Art(24, [_cs('M2.500 9.300a14 14 0 0 1 19 0M6 13a9 9 0 0 1 12 0M9.300 16.500a4 4 0 0 1 5.400 0', 2.300), _cfp(svgCircle(12, 19.600, 1.600))]);
    case GameIcons.trophy:
      return _Art(24, [
        _f('M7 3h10v7a5 5 0 0 1-10 0z', _gold),
        _s('M7 5H3.800c0 3.400 1.200 5.400 3.700 6M17 5h3.200c0 3.400-1.200 5.400-3.700 6', _goldDeep, 1.800),
        _f('M10.800 14.500h2.400v3.500h-2.400z', _goldDeep),
        _fp(svgRect(7.500, 18, 9, 3, 1), _goldDeep),
      ]);
    case GameIcons.copy:
      return _Art(24, [_csp(svgRect(9, 9, 11.500, 11.500, 2.500)), _cs('M15 5.500c0-1.100-.9-2-2-2H5.500c-1.100 0-2 .9-2 2V13c0 1.100.9 2 2 2', 2)]);
    case GameIcons.share:
      return _Art(24, [_cs('M12 15V3.800M7.500 7.800 12 3.300l4.500 4.500', 2.200), _cs('M5 12.500v6c0 1.100.9 2 2 2h10c1.100 0 2-.9 2-2v-6', 2.200)]);
    case GameIcons.search:
      return _Art(24, [_csp(svgCircle(10.500, 10.500, 6.800), 2.300), _cs('M15.600 15.600 21 21', 2.600)]);
    case GameIcons.settings:
      return _Art(24, [_cs('M3.500 7.500h9M18.500 7.500h2M3.500 16.500h2M11.500 16.500h9', 2.200), _csp(svgCircle(15.500, 7.500, 2.800), 2.200), _csp(svgCircle(8.500, 16.500, 2.800), 2.200)]);
    case GameIcons.plus:
      return _Art(24, [_cs('M12 4.500v15M4.500 12h15', 2.800)]);
    case GameIcons.minus:
      return _Art(24, [_cs('M4.500 12h15', 2.800)]);
    case GameIcons.people:
      return _Art(24, [_cfp(svgCircle(9, 8, 3.800)), _cf('M2 20c0-4 3-6.500 7-6.500s7 2.500 7 6.500c0 .6-.4 1-1 1H3c-.6 0-1-.4-1-1z'), _cfp(svgCircle(17.300, 9, 2.800)), _cf('M17.800 20.800c0-2.700-.9-5-2.600-6.400 3.700-.9 7 1.300 7 5.400 0 .6-.4 1-1 1z')]);
    case GameIcons.check:
      return _Art(24, [_cs('M4.500 12.500 10 18 19.500 6.500', 3.200)]);
    case GameIcons.skip:
      return _Art(24, [_cf('M4.500 5.800c0-1 1.100-1.600 1.900-1l9.100 6.200c.7.500.7 1.500 0 2l-9.100 6.200c-.8.600-1.900 0-1.900-1z'), _cfp(svgRect(16.800, 4.500, 3, 15, 1.200))]);
    case GameIcons.eye:
      return _Art(24, [_cs('M2 12c2.800-4.700 6.100-7 10-7s7.200 2.300 10 7c-2.800 4.700-6.100 7-10 7s-7.200-2.300-10-7z', 2.100), _cfp(svgCircle(12, 12, 3.300))]);
    case GameIcons.lock:
      return _Art(24, [_cfp(svgRect(4.500, 10.500, 15, 11, 3)), _cs('M8 10.500V7.500a4 4 0 0 1 8 0v3', 2.300)]);
    case GameIcons.lightbulb:
      return _Art(24, [_f('M12 2.500a7 7 0 0 0-4 12.700c.7.500 1 1.200 1 2V18h6v-.8c0-.8.300-1.500 1-2a7 7 0 0 0-4-12.700z', _gold), _fp(svgRect(9.300, 19, 5.400, 2.800, 1.200), _steelDeep)]);
    case GameIcons.flag:
      return _Art(24, [_s('M6 2.500v19', _steelDeep, 2.200), _f('M7 3.500 19.500 8 7 13z', _red)]);
    case GameIcons.star:
      return _Art(24, [_cf('M12 2.300l2.900 6.100 6.700.900-4.900 4.600 1.200 6.600L12 17.300l-5.900 3.200 1.200-6.600-4.900-4.600 6.700-.900z')]);
    case GameIcons.heart:
      return _Art(24, [_f('M12 21C5.500 16.300 2.500 12.700 2.500 8.700 2.500 5.700 4.800 3.500 7.600 3.500c1.800 0 3.400.9 4.400 2.500 1-1.600 2.600-2.500 4.400-2.500 2.800 0 5.100 2.200 5.100 5.200 0 4-3 7.600-9.500 12.300z', _red)]);
    case GameIcons.heartEmpty:
      return _Art(24, [_s('M12 20C6 15.700 3.500 12.400 3.500 8.800c0-2.400 1.800-4.300 4.100-4.300 1.900 0 3.400 1.200 4.400 3 1-1.800 2.500-3 4.400-3 2.300 0 4.100 1.900 4.100 4.300 0 3.600-2.500 6.900-8.500 11.200z', _steel, 2)]);
    case GameIcons.shield:
      return _Art(24, [_f('M12 2 20.500 5v7c0 4.800-3.300 8.200-8.500 10-5.200-1.800-8.500-5.200-8.500-10V5z', _blue), _f('M12 2v20c-5.200-1.800-8.500-5.200-8.500-10V5z', _blueDeep)]);
    case GameIcons.crown:
      return _Art(24, [_f('M3 8l4.800 4.300L12 4.500l4.200 7.800L21 8l-1.800 10.500H4.800z', _gold), _fp(svgRect(4.800, 18.500, 14.400, 2.500, 1), _goldDeep)]);
    case GameIcons.crownKing:
      return _Art(24, [_f('M3.500 9l4.300 3.500L12 6l4.200 6.500L20.500 9l-1.600 9H5.100z', _gold), _fp(svgRect(5.100, 18, 13.800, 2.600, 1), _goldDeep), _fp(svgCircle(12, 14.500, 1.500), _red)]);
    case GameIcons.coin:
      return _Art(24, [_fp(svgCircle(12, 12.800, 9.300), _goldDeep), _fp(svgCircle(12, 11.500, 9.300), _gold), _s('M12 7v9', _goldDeep, 2.200), _s('M8.500 11.500h7', _goldDeep, 2.200)]);
    case GameIcons.target:
      return _Art(24, [_fp(svgCircle(12, 12, 10), _red), _fp(svgCircle(12, 12, 7), _bone), _fp(svgCircle(12, 12, 4), _red), _fp(svgCircle(12, 12, 1.600), _gold)]);
    case GameIcons.wind:
      return _Art(24, [_cs('M3 9h12a3 3 0 1 0-3-3M3 13.500h15.500a2.800 2.800 0 1 1-2.800 2.800M3 18h7a2.500 2.500 0 1 1-2.500 2.500', 2.100)]);
    case GameIcons.arrow:
      return _Art(24, [_s('M4 20 18.500 5.500', _wood, 2.200), _f('M21.500 2.500 20 9.500l-5.500-5.500z', _steelDeep), _s('M3 17.500l3.500 3.500M3 21l3.500-3.500', _red, 1.800)]);
    case GameIcons.bow:
      return _Art(24, [_s('M6 2.500C16 5 20 12 20 12s-4 7-14 9.500', _wood, 2.800), _s('M6 2.500v19', _bone, 1.400), _s('M2 12h17', _steelDeep, 1.800)]);
    case GameIcons.home:
      return _Art(24, [_cf('M12 3 2.500 11.300c-.5.400-.2 1.200.5 1.200H5V20c0 .6.400 1 1 1h4v-6h4v6h4c.6 0 1-.4 1-1v-7.500h2c.7 0 1-.8.500-1.200z')]);
    case GameIcons.chevronDown:
      return _Art(24, [_cs('M5 9l7 7 7-7', 2.400)]);
    case GameIcons.arrowLeft:
      return _Art(24, [_cs('M20 12H4.500M11 5l-7 7 7 7', 2.600)]);
    case GameIcons.arrowRight:
      return _Art(24, [_cs('M4 12h15.500M13 5l7 7-7 7', 2.600)]);
    case GameIcons.arrowUp:
      return _Art(24, [_cs('M12 20V4.500M5 11l7-7 7 7', 2.600)]);
    case GameIcons.arrowDown:
      return _Art(24, [_cs('M12 4v15.500M5 13l7 7 7-7', 2.600)]);
    case GameIcons.rotate:
      return _Art(24, [_cs('M4.500 12a7.500 7.500 0 0 1 12.900-5.200', 2.300), _cs('M19.500 12a7.500 7.500 0 0 1-12.900 5.200', 2.300), _cf('M20 2.500v6h-6zM4 21.500v-6h6z')]);

    // Weapons and power-ups
    case GameIcons.rocket:
      return _Art(24, _rocket());
    case GameIcons.tripleRocket:
      List<IconInk> small(double dx, double dy, double k) {
        final m = Float64List.fromList([k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);
        return [for (final ink in _rocket()) IconInk(ink.path.transform(m), fill: ink.fill)];
      }
      return _Art(24, [...small(-1, 7, 0.55), ...small(11.500, 7, 0.55), ...small(5.500, 0, 0.6)]);
    case GameIcons.mine:
      return _Art(24, [
        for (final d in const ['M12 1.500v21', 'M1.500 12h21', 'M4.500 4.500l15 15', 'M19.500 4.500l-15 15']) _s(d, _steelDeep, 2.400),
        _fp(svgCircle(12, 12, 7.500), _steelDeep),
        _fp(svgCircle(12, 12, 3), _red),
      ]);
    case GameIcons.bolt:
      return _Art(24, [_f('M13.800 1.500 4.500 13.500h6L9.300 22.500 19.500 9.800h-6.300z', _gold)]);
    case GameIcons.gun:
      return _Art(24, [_fp(svgRect(2, 7.500, 18, 6, 1.500), _steelDeep), _fp(svgRect(17, 8.800, 5.500, 3, .8), _steel), _f('M5 13.500h6l-1.500 7.500H4.500z', _woodDeep), _fp(svgRect(5, 6, 3, 1.800, .5), _steel)]);
    case GameIcons.mysteryBox:
      return _Art(24, [_fp(svgRect(2.500, 4, 19, 19, 4), _goldDeep), _fp(svgRect(2.500, 2, 19, 19, 4), _gold), _s('M9 8.300a3 3 0 1 1 4.600 2.500c-1 .7-1.600 1.300-1.600 2.500', _ink, 2.300), _fp(svgCircle(12, 16.800, 1.300), _ink)]);
    case GameIcons.bomb:
      return _Art(24, [_fp(svgCircle(11, 14, 8), _steelDeep), _s('M15.500 7.500c1-3 3-4.500 5.500-4', _wood, 2), _fp(svgCircle(21, 3.500, 1.700), _gold)]);

    // Dice
    case GameIcons.dice1:
      return _Art(24, _dice(const [(12, 11.500)]));
    case GameIcons.dice2:
      return _Art(24, _dice(const [(8, 7.500), (16, 15.500)]));
    case GameIcons.dice3:
      return _Art(24, _dice(const [(7.500, 7), (12, 11.500), (16.500, 16)]));
    case GameIcons.dice4:
      return _Art(24, _dice(const [(8, 7.500), (16, 7.500), (8, 15.500), (16, 15.500)]));
    case GameIcons.dice5:
      return _Art(24, _dice(const [(7.500, 7), (16.500, 7), (12, 11.500), (7.500, 16), (16.500, 16)]));
    case GameIcons.dice6:
      return _Art(24, _dice(const [(8, 6.500), (16, 6.500), (8, 11.500), (16, 11.500), (8, 16.500), (16, 16.500)]));

    // Characters and game things
    case GameIcons.duck:
      return _Art(24, [_f('M3 13.500c0 5 4 8 9.500 8 5.500 0 8.500-3.500 8.500-8-2 1.500-5 1.500-7.500.5-3 1-7 1-10.500-.5z', _gold), _fp(svgCircle(15, 8, 5), _gold), _f('M19.500 6.800 23.500 8l-4 1.500z', _red), _fp(svgCircle(16.200, 7, 1), _ink)]);
    case GameIcons.rabbit:
      return _Art(24, [_fp(svgEllipse(8.800, 6, 2.200, 5.500), _bone), _fp(svgEllipse(15.200, 6, 2.200, 5.500), _bone), _fp(svgEllipse(8.800, 6, 1, 3.800), _pink), _fp(svgEllipse(15.200, 6, 1, 3.800), _pink), _fp(svgCircle(12, 15.500, 7), _bone), _fp(svgCircle(9.500, 14.500, 1.100), _ink), _fp(svgCircle(14.500, 14.500, 1.100), _ink), _fp(svgEllipse(12, 17.500, 1.400, 1), _pink)]);
    case GameIcons.mole:
      return _Art(24, _mole(const Color(0xFF8A6647), const Color(0xFFC29A76)));
    case GameIcons.goldenMole:
      return _Art(24, _mole(_gold, const Color(0xFFFBD98A)));
    case GameIcons.alien:
      return _Art(24, [_f('M12 2C6.500 2 3.500 6 3.500 10.500c0 5.500 5 11.500 8.500 11.500s8.500-6 8.500-11.500C20.500 6 17.500 2 12 2z', _leaf), _f('M6.500 10.500c2.500 0 4.200 1.700 4.200 4-2.500 0-4.200-1.700-4.200-4zM17.500 10.500c-2.500 0-4.200 1.700-4.200 4 2.500 0 4.200-1.700 4.200-4z', _ink)]);
    case GameIcons.ufo:
      return _Art(24, [_fp(svgEllipse(12, 9.500, 5, 5), const Color(0xFF9FD3E8)), _fp(svgEllipse(12, 14, 10.500, 4.500), _steelDeep), for (final x in const [6.0, 12.0, 18.0]) _fp(svgCircle(x, 14.500, 1.300), _gold)]);
    case GameIcons.tank:
      return _Art(24, [_fp(svgRect(2, 15, 20, 6.500, 3.200), _steelDeep), _fp(svgRect(4, 9.500, 15, 6, 1.500), _leaf), _fp(svgRect(7, 5.500, 8, 5, 1.500), _leafDeep), _fp(svgRect(14, 6.800, 8.500, 2.200, .8), _leafDeep)]);
    case GameIcons.cactus:
      return _Art(24, [_s('M12 22V3.500M12 15H7c-1.500 0-2.500-1-2.500-2.500V9.500M12 12h5c1.500 0 2.500-1 2.500-2.500V7', _leaf, 4.200)]);
    case GameIcons.bird:
      return _Art(24, [_fp(svgCircle(11, 13, 8.500), _red), _f('M18.500 11 23.500 13l-5 2.500z', _gold), _fp(svgCircle(14, 10.500, 2.200), _bone), _fp(svgCircle(14.700, 10.500, 1), _ink), _f('M6 13.500c2 0 4 1 4.500 3.500-2.500.5-5-1-4.500-3.500z', _redDeep)]);
    case GameIcons.pig:
      return _Art(24, [_f('M5.500 7 3.500 3 8.500 5zM18.500 7l2-4-5 2z', _pink), _fp(svgCircle(12, 13, 9), _pink), _fp(svgEllipse(12, 15.500, 3.800, 2.800), const Color(0xFFD97089)), _fp(svgCircle(10.500, 15.500, .8), _ink), _fp(svgCircle(13.500, 15.500, .8), _ink), _fp(svgCircle(8.500, 10.500, 1.100), _ink), _fp(svgCircle(15.500, 10.500, 1.100), _ink)]);
    case GameIcons.ladder:
      return _Art(24, [_s('M7.500 2v20M16.500 2v20', _wood, 2.600), _s('M7.500 6h9M7.500 11h9M7.500 16h9', _woodDeep, 2.200)]);
    case GameIcons.snake:
      return _Art(24, [_s('M5 21h9c3.300 0 5-1.700 5-3.800 0-2.200-1.700-3.700-5-3.700H9.500C6.700 13.500 5 12 5 9.800 5 7.600 6.700 6 9.500 6H15', _leaf, 3.800), _fp(svgEllipse(17.500, 6, 3.800, 3), _leafDeep), _fp(svgCircle(18.500, 5, .9), _bone), _s('M21 6.500h2', _red, 1.200)]);
    case GameIcons.rock:
      return _Art(24, [_f('M6 8.500c0-1 .8-1.800 1.800-1.800.4 0 .8.100 1.100.400.200-1 1-1.600 2-1.600.8 0 1.500.5 1.800 1.200.3-.5.900-.8 1.500-.8 1 0 1.800.8 1.800 1.800v.5c.3-.2.700-.3 1-.3 1 0 1.800.8 1.800 1.800V15c0 4-2.800 7-7 7-3.700 0-6.800-2.600-6.800-6.500z', _skin)]);
    case GameIcons.paper:
      return _Art(24, [_f('M6 11V5.500c0-.9.700-1.500 1.500-1.500S9 4.600 9 5.500V10h.5V3.500C9.500 2.600 10.200 2 11 2s1.500.6 1.500 1.500V10h.5V4.500c0-.9.700-1.500 1.500-1.500s1.500.6 1.500 1.500V11h.5V7c0-.9.700-1.500 1.500-1.500S19.500 6.100 19.500 7v8c0 4-2.800 7-7 7-3 0-5-1.300-6.500-3.800L3 13.200c-.4-.8-.1-1.700.6-2.100.7-.4 1.600-.2 2.100.5z', _skin)]);
    case GameIcons.scissors:
      return _Art(24, [_f('M6.500 12.500V3.700c0-.9.700-1.700 1.700-1.700S10 2.800 10 3.700v6.800h.8V3c0-.9.700-1.600 1.600-1.600S14 2.100 14 3v8.500c.4-.3.800-.4 1.200-.4 1 0 1.800.8 1.800 1.800.3-.2.700-.3 1-.3 1 0 1.800.8 1.800 1.800 0 4.300-2.800 8.600-7.300 8.600-3.800 0-6-2.600-6-6.500z', _skin)]);
    case GameIcons.bat:
      return _Art(24, [_s('M4 20 7 17', _stem, 3), _f('M6 14.500 16.500 4c.8-.8 2-.8 2.800 0l.7.700c.8.800.8 2 0 2.800L9.500 18z', _wood), _f('M6 14.500 18.500 3.300l.8.700L8 16.500z', _woodDeep)]);
    case GameIcons.ball:
      return _Art(24, [_fp(svgCircle(12, 12, 10), const Color(0xFFE2762B)), _s('M2 12h20M12 2v20M5 5c3 3.500 3 10.500 0 14M19 5c-3 3.500-3 10.500 0 14', const Color(0xFF7A3B12), 1.400)]);
    case GameIcons.cricketBall:
      return _Art(24, [_fp(svgCircle(12, 12, 10), _redDeep), _s('M5.500 4.500c5 3.500 8 9 8 17M9.500 2.800c5 3.700 8 9.500 8 17', _bone, 1.200)]);
    case GameIcons.puck:
      return _Art(24, [_fp(svgEllipse(12, 15, 10, 5.500), _ink), _fp(svgEllipse(12, 11, 10, 5.500), const Color(0xFF4B4136))]);
    case GameIcons.mallet:
      return _Art(24, [_fp(svgCircle(12, 14.500, 9), _redDeep), _fp(svgCircle(12, 13, 9), _red), _fp(svgCircle(12, 11, 3.800), _redDeep)]);
    case GameIcons.football:
      return _Art(24, [_fp(svgCircle(12, 12, 10), _bone), _f('M12 7.500l4.300 3.100-1.600 5h-5.400l-1.600-5z', _ink), _s('M12 7.500V2.500M16.300 10.600l4.800-1.500M14.700 15.600l3 4M9.300 15.600l-3 4M7.700 10.600 2.900 9.100', _ink, 1.500)]);
    case GameIcons.glove:
      return _Art(24, [_f('M6 12V5.500c0-.9.700-1.500 1.500-1.500S9 4.600 9 5.500V3.500C9 2.600 9.700 2 10.500 2s1.500.6 1.500 1.500V4c0-.9.700-1.500 1.500-1.500S15 3.100 15 4v1.500c0-.8.700-1.500 1.500-1.500s1.500.7 1.500 1.500V14c0 4-2.700 6-6 6s-5-1.500-6.500-4L3 11.700c-.5-.8-.2-1.700.5-2.100.8-.4 1.700-.1 2.100.6z', _blue), _fp(svgRect(7.500, 19, 9, 3.500, 1), _blueDeep)]);
    case GameIcons.bottle:
      return _Art(24, [_fp(svgRect(10, 1.500, 4, 3, 1), _woodDeep), _f('M10 4.500h4v3c0 1.300 3 2.500 3 5.500v7c0 1.400-1.100 2.500-2.500 2.500h-5C8.100 22.500 7 21.400 7 20v-7c0-3 3-4.200 3-5.500z', _leaf), _fp(svgRect(7, 13, 10, 5, 0), _bone)]);
    case GameIcons.woodBlock:
      return _Art(24, [_fp(svgRect(2.500, 5, 19, 16, 2.500), _woodDeep), _fp(svgRect(2.500, 3, 19, 16, 2.500), _wood), _s('M6 8h12M6 13h8', _woodDeep, 1.300)]);
    case GameIcons.stoneBlock:
      return _Art(24, [_fp(svgRect(2.500, 5, 19, 16, 2.500), _steelDeep), _fp(svgRect(2.500, 3, 19, 16, 2.500), _steel), _s('M2.500 11h19M9 3v8M15 11v8', _steelDeep, 1.300)]);
    case GameIcons.paintBrush:
      return _Art(24, [_s('M21 3 11.500 12.500', _wood, 3), _f('M11.800 11 13.500 12.800c.5 3-1.500 8.200-9 8.700-1.700.1-2.300-.7-1.500-1.500 2-2 1-4.500 3-6.800 1.200-1.500 3.800-2.700 5.800-2.200z', _red)]);
    case GameIcons.pencil:
      return _Art(24, [_f('M4 16 16 4l4 4L8 20l-5 1z', _gold), _f('M15 5l2-2c.6-.6 1.400-.6 2 0l2 2c.6.6.6 1.400 0 2l-2 2z', _red), _f('M4 16l4 4-5 1z', _ink)]);
    case GameIcons.magnifier:
      return _Art(24, [_fp(svgCircle(10, 10, 7.500), const Color(0xFFBBDCE8)), _s('M10 2.500a7.500 7.500 0 1 1 0 15 7.500 7.500 0 0 1 0-15', _steelDeep, 2.400), _s('M15.800 15.800l5.700 5.700', _woodDeep, 3.400)]);
    case GameIcons.mask:
      return _Art(24, [_f('M3 6c6-2.500 12-2.500 18 0 .5 7-2.500 14-9 15C5.500 20 2.500 13 3 6z', _plum), _f('M6 10.300c1.500-1 3.300-1 4.800 0-.5 1.800-4.300 1.800-4.800 0zM13.200 10.300c1.500-1 3.300-1 4.800 0-.5 1.800-4.300 1.800-4.800 0z', _ink), _s('M9 15.500c2 1.200 4 1.200 6 0', _plumDeep, 1.800)]);
    case GameIcons.scroll:
      return _Art(24, [_fp(svgRect(5, 3.500, 14, 17, 1), _bone), _fp(svgRect(3, 2, 18, 3.500, 1.700), _boneDark), _fp(svgRect(3, 18.500, 18, 3.500, 1.700), _boneDark), _s('M8 9h8M8 12.500h8M8 16h5', _woodDeep, 1.400)]);
    case GameIcons.moon:
      return _Art(24, [_f('M20 15A9 9 0 1 1 9.500 3.500 7.500 7.500 0 0 0 20 15z', const Color(0xFFF5E2A6))]);
    case GameIcons.sun:
      return _Art(24, [_fp(svgCircle(12, 12, 5.500), _gold), _s('M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2', _gold, 2.200)]);
    case GameIcons.medical:
      return _Art(24, [_fp(svgRect(2.500, 2.500, 19, 19, 5), _bone), _s('M12 7v10M7 12h10', _red, 3.600)]);
    case GameIcons.clapper:
      return _Art(24, [_fp(svgRect(2.500, 9.500, 19, 12, 2), _ink), _f('M2.500 5.800 19.800 2l1.200 4.700L3.500 10.500z', _bone), _f('M6.500 5 9 9l-2.500.5-2.200-4zM12 3.800l2.500 4-2.600.5-2.200-4zM17.500 2.500l2.500 4-2.600.6-2.200-4z', _ink), _s('M6 14h12M6 17.500h8', _boneDark, 1.300)]);
    case GameIcons.speech:
      return _Art(24, [_cf('M4 3h16c1.100 0 2 .9 2 2v11c0 1.100-.9 2-2 2h-8l-5.300 3.800c-.5.400-1.200 0-1.200-.6V18H4c-1.100 0-2-.9-2-2V5c0-1.100.9-2 2-2z')]);
    case GameIcons.hammer:
      return _Art(24, [_s('M11 11 20 20.500', _wood, 3), _f('M9.500 2.500 15.500 8.500l-2 2L11 9l-3.500 3.500L4 9l3.500-3.500-1-1z', _steelDeep)]);
    case GameIcons.drop:
      return _Art(24, [_f('M12 2c3.800 4.600 6.800 8.500 6.800 12.300A6.800 6.800 0 0 1 12 21a6.800 6.800 0 0 1-6.800-6.700C5.200 10.500 8.200 6.600 12 2z', _blue)]);

    // Fruit: flat, two tones
    case GameIcons.apple:
      return _Art(24, _round(_red, _redDeep));
    case GameIcons.peach:
      return _Art(24, _round(const Color(0xFFF7A77E), const Color(0xFFE2703F)));
    case GameIcons.orange:
      return _Art(24, _round(const Color(0xFFF2922C), const Color(0xFFD06A10)));
    case GameIcons.coconut:
      return _Art(24, [_fp(svgCircle(12, 12, 10), _stem), _fp(svgCircle(12, 12, 7.500), _bone), _fp(svgCircle(12, 12, 4.500), _boneDark)]);
    case GameIcons.kiwi:
      return _Art(24, [_fp(svgCircle(12, 12, 10), const Color(0xFF7D5B3D)), _fp(svgCircle(12, 12, 8.500), const Color(0xFF8DBE45)), _fp(svgCircle(12, 12, 3), _bone), for (final (x, y) in const [(12.0, 6.5), (16.0, 8.0), (17.5, 12.0), (16.0, 16.0), (12.0, 17.5), (8.0, 16.0), (6.5, 12.0), (8.0, 8.0)]) _fp(svgCircle(x, y, .8), _ink)]);
    case GameIcons.banana:
      return _Art(24, [_f('M4 4c-.5 9 5 15.500 16.500 15.500.8 0 1.200-1 .5-1.500C14 15 9.500 10.500 7.500 3.800 7.200 2.800 4 2.800 4 4z', const Color(0xFFF4CE3D)), _f('M4 4c-.5 9 5 15.500 16.500 15.500.8 0 1.200-1 .5-1.500-8 .8-14-6-14.500-14.700C5.700 2.700 4 3 4 4z', const Color(0xFFD9A81C))]);
    case GameIcons.grapes:
      return _Art(24, [_s('M12 6 13 2.500', _stem, 1.600), _f('M13 4.500Q17 1.500 20 4 16.500 7 13 4.500Z', _leaf), for (final (x, y) in const [(7.5, 9.0), (12.0, 9.0), (16.5, 9.0), (9.7, 13.2), (14.3, 13.2), (12.0, 17.5)]) _fp(svgCircle(x, y, 3), _plum), for (final (x, y) in const [(12.0, 9.0), (9.7, 13.2)]) _fp(svgCircle(x, y, 3), _plumDeep)]);
    case GameIcons.watermelon:
      return _Art(24, [_f('M2 8a10 10 0 0 0 20 0z', _leafDeep), _f('M3.800 8a8.200 8.200 0 0 0 16.400 0z', _bone), _f('M5 8a7 7 0 0 0 14 0z', _red), for (final (x, y) in const [(9.0, 11.0), (12.0, 13.0), (15.0, 11.0)]) _fp(svgEllipse(x, y, .7, 1.200), _ink)]);
    case GameIcons.strawberry:
      return _Art(24, [_f('M12 22C6 18 3.500 12.500 5.500 9c2-2.500 11-2.500 13 0 2 3.500-.5 9-6.500 13z', _red), for (final (x, y) in const [(9.0, 11.5), (12.0, 11.0), (15.0, 11.5), (10.5, 15.0), (13.5, 15.0), (12.0, 18.0)]) _fp(svgEllipse(x, y, .5, .8), const Color(0xFFF7DE8E)), _f('M6.500 8 9 4l2 2.500L12 3l1 3.500L15 4l2.500 4c-3.500 1.500-7.500 1.500-11 0z', _leaf)]);
    case GameIcons.cherry:
      return _Art(24, [_s('M7.500 15C9 9 12 5.500 16 3M16.500 15C16.500 9 16.500 6 16 3', _stem, 1.600), _f('M16 3 Q19.500 .5 22 3 18.500 5.500 16 3Z', _leaf), _fp(svgCircle(7.500, 17.500, 4.500), _red), _fp(svgCircle(16.500, 17.500, 4.500), _redDeep)]);
    case GameIcons.mango:
      return _Art(24, [_f('M6.500 19C2.500 13.500 5 5.500 12 4.500 19 4 21.500 10 19 16 17 21 10 22.500 6.500 19z', const Color(0xFFF7B32B)), _f('M12 4.500C19 4 21.500 10 19 16c-.8 2-2.300 3.300-4 4.300 2.500-5.500 2-11.500-3-15.800z', const Color(0xFFE5613F)), _f('M12 5 Q14.500 1.500 18 3 15.500 6 12 5Z', _leaf)]);
    case GameIcons.pineapple:
      return _Art(24, [_f('M12 9 8 2.500l2.500 3L12 1.500l1.500 4 2.500-3z', _leaf), _fp(svgEllipse(12, 15.500, 6, 7), const Color(0xFFF4BE2F)), IconInk(svgPath('M5 12 17 24M5 17l10 10M9 8l12 12M19 12 7 24M19 17 9 27M15 8 3 20'), stroke: _goldDeep, style: const InkStroke(.9), clip: svgEllipse(12, 15.500, 6, 7))]);
    case GameIcons.lemon:
      return _Art(24, [_f('M3 13c1-5 4.500-7.500 9-7.500s8 2.500 9 7.500c-1 5-4.500 7.500-9 7.500S4 18 3 13z', const Color(0xFFF7E04B)), _f('M3 13c6 2.500 12 2.500 18 0-1 5-4.500 7.500-9 7.500S4 18 3 13z', const Color(0xFFE3C321)), _f('M12 5.500 Q15 2 19 3.500 16 7 12 5.500Z', _leaf)]);
    case GameIcons.pear:
      return _Art(24, [_f('M12 4.500c-2.500 0-3.300 2.300-3.300 4.200 0 2-4.200 3.800-4.200 7.800 0 3.800 3.300 6 7.500 6s7.500-2.200 7.500-6c0-4-4.200-5.800-4.200-7.800 0-1.900-.8-4.200-3.300-4.200z', const Color(0xFFB9C744)), _s('M12 4.500 13.300 1.800', _stem, 1.600), _f('M13 3 Q16.500 .5 19 3 16 5.500 13 3Z', _leaf)]);
    case GameIcons.melon:
      return _Art(24, [_fp(svgEllipse(12, 13, 10, 8.500), const Color(0xFF8FBF5A)), _s('M12 4.500v17M6.500 6c-2 4-2 10 0 14M17.500 6c2 4 2 10 0 14', const Color(0xFFE4EFC8), 1.300)]);
  }
}

/// Paints [icon] to an image-free picture once and reuses it (for icons drawn every frame).
ui.Picture iconPicture(GameIcons icon, double size, {Color color = Colors.white}) {
  final rec = ui.PictureRecorder();
  paintIcon(Canvas(rec), icon, Rect.fromLTWH(0, 0, size, size), color: color);
  return rec.endRecording();
}
