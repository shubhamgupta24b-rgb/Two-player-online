import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';

/// Each game's drawn icon (no emoji in game UI). Used by the intro header, How to play,
/// results, the hub tiles, rooms and records.
const gameIcons = <String, GameIcons>{
  'air_hockey': GameIcons.puck,
  'archery': GameIcons.target,
  'ball_sort': GameIcons.bottle,
  'basketball_hoops': GameIcons.ball,
  'battleship': GameIcons.target,
  'bingo': GameIcons.star,
  'block_drop': GameIcons.stoneBlock,
  'bottle_smash': GameIcons.bottle,
  'brick_breaker': GameIcons.woodBlock,
  'bubble_shooter': GameIcons.drop,
  'charades': GameIcons.clapper,
  'checkers': GameIcons.crownKing,
  'classic_snake': GameIcons.snake,
  'chicken_jump': GameIcons.bird,
  'fruit_cut': GameIcons.watermelon,
  'knife_hit': GameIcons.target,
  'sweet_swap': GameIcons.cherry,
  'bike_race': GameIcons.rocket,
  'hungry_hippos': GameIcons.ball,
  'tug_of_war': GameIcons.people,
  'carrom': GameIcons.coin,
  'eight_ball': GameIcons.ball,
  'minesweeper_race': GameIcons.mine,
  'color_switch': GameIcons.paintBrush,
  'colour_clash': GameIcons.mysteryBox,
  'connect_four': GameIcons.coin,
  'crush_it': GameIcons.hammer,
  'dino_run': GameIcons.cactus,
  'dots_boxes': GameIcons.pencil,
  'draw_guess': GameIcons.paintBrush,
  'find_spy': GameIcons.magnifier,
  'flappy_jump': GameIcons.bird,
  'fruit_duel': GameIcons.watermelon,
  'fruit_merge': GameIcons.watermelon,
  'fruit_merge_battle': GameIcons.strawberry,
  'game_2048': GameIcons.stoneBlock,
  'guess_person': GameIcons.magnifier,
  'guess_who': GameIcons.magnifier,
  'hand_cricket': GameIcons.bat,
  'hangman': GameIcons.pencil,
  'heads_up': GameIcons.speech,
  'ludo': GameIcons.dice5,
  'mafia': GameIcons.moon,
  'math_duel': GameIcons.plus,
  'memory': GameIcons.cherry,
  'minesweeper': GameIcons.mine,
  'mini_golf': GameIcons.flag,
  'most_likely': GameIcons.people,
  'paint_fight': GameIcons.paintBrush,
  'penalty': GameIcons.football,
  'piano_tiles': GameIcons.sound,
  'ping_pong': GameIcons.mallet,
  'quiz_battle': GameIcons.lightbulb,
  'raja_mantri': GameIcons.crown,
  'reaction_tap': GameIcons.bolt,
  'rock_paper_scissors': GameIcons.rock,
  'shooting_gallery': GameIcons.duck,
  'simon_says': GameIcons.sound,
  'sky_jumper': GameIcons.arrowUp,
  'sliding_puzzle': GameIcons.woodBlock,
  'slingshot': GameIcons.bird,
  'smash_karts': GameIcons.rocket,
  'snake_duel': GameIcons.snake,
  'snakes_ladders': GameIcons.ladder,
  'space_shooter': GameIcons.ufo,
  'stack_tower': GameIcons.woodBlock,
  'sudoku': GameIcons.pencil,
  'tic_tac_toe': GameIcons.cross,
  'truth_dare': GameIcons.bottle,
  'undercover': GameIcons.mask,
  'whack_mole': GameIcons.mole,
  'word_scramble': GameIcons.scroll,
  'would_rather': GameIcons.help,
};

/// The icon for a game id (team versions use their base game's icon).
GameIcons gameIconFor(String id) {
  if (gameIcons[id] case final i?) return i;
  for (final e in gameIcons.entries) {
    if (id.startsWith(e.key)) return e.value;
  }
  return GameIcons.star;
}

/// The surface a game is played on, used as its art background.
enum ArtGround {
  felt,
  wood,
  paper,
  day,
  sunset,
  night,
  grass,
  court,
  ice,
  water,
  track
}

const _grounds = <String, ArtGround>{
  'colour_clash': ArtGround.felt,
  'memory': ArtGround.felt,
  'bingo': ArtGround.felt,
  'raja_mantri': ArtGround.felt,
  'guess_person': ArtGround.felt,
  'guess_who': ArtGround.felt,
  'fruit_duel': ArtGround.felt,
  'fruit_merge': ArtGround.wood,
  'fruit_merge_battle': ArtGround.wood,
  'ludo': ArtGround.wood,
  'snakes_ladders': ArtGround.wood,
  'checkers': ArtGround.wood,
  'connect_four': ArtGround.wood,
  'dots_boxes': ArtGround.paper,
  'tic_tac_toe': ArtGround.paper,
  'sudoku': ArtGround.paper,
  'sliding_puzzle': ArtGround.wood,
  'game_2048': ArtGround.wood,
  'hangman': ArtGround.paper,
  'word_scramble': ArtGround.paper,
  'ball_sort': ArtGround.wood,
  'charades': ArtGround.paper,
  'draw_guess': ArtGround.paper,
  'heads_up': ArtGround.paper,
  'quiz_battle': ArtGround.paper,
  'most_likely': ArtGround.paper,
  'would_rather': ArtGround.paper,
  'truth_dare': ArtGround.felt,
  'math_duel': ArtGround.paper,
  'rock_paper_scissors': ArtGround.paper,
  'find_spy': ArtGround.night,
  'undercover': ArtGround.night,
  'mafia': ArtGround.night,
  'archery': ArtGround.day,
  'slingshot': ArtGround.day,
  'flappy_jump': ArtGround.day,
  'sky_jumper': ArtGround.day,
  'bottle_smash': ArtGround.sunset,
  'shooting_gallery': ArtGround.sunset,
  'dino_run': ArtGround.day,
  'stack_tower': ArtGround.day,
  'smash_karts': ArtGround.track,
  'space_shooter': ArtGround.night,
  'simon_says': ArtGround.night,
  'piano_tiles': ArtGround.night,
  'reaction_tap': ArtGround.night,
  'color_switch': ArtGround.night,
  'bubble_shooter': ArtGround.night,
  'brick_breaker': ArtGround.night,
  'block_drop': ArtGround.night,
  'classic_snake': ArtGround.grass,
  'snake_duel': ArtGround.grass,
  'penalty': ArtGround.grass,
  'mini_golf': ArtGround.grass,
  'hand_cricket': ArtGround.grass,
  'whack_mole': ArtGround.grass,
  'minesweeper': ArtGround.grass,
  'crush_it': ArtGround.court,
  'ping_pong': ArtGround.court,
  'basketball_hoops': ArtGround.court,
  'paint_fight': ArtGround.court,
  'air_hockey': ArtGround.ice,
  'battleship': ArtGround.water,
};

ArtGround groundFor(String id) {
  if (_grounds[id] case final g?) return g;
  for (final e in _grounds.entries) {
    if (id.startsWith(e.key)) return e.value;
  }
  return ArtGround.night;
}

/// A painted scene for a game's header. Games register theirs in [gameScenes] as they are
/// redesigned; the rest get [GameArtPainter]: their ground, a glow in the game colour and
/// their icon.
typedef ScenePainterBuilder = CustomPainter Function(Color color);
final gameScenes = <String, ScenePainterBuilder>{};

/// A game's small picture (hub tiles, rooms, records, intro): the surface it's played on,
/// a soft glow in the game colour and its drawn icon, simple but different per game.
class GameArtPainter extends CustomPainter {
  final String id;
  final Color color;
  final double iconScale;
  const GameArtPainter(this.id, this.color, {this.iconScale = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.save();
    canvas.clipRect(r);
    final ground = groundFor(id);
    switch (ground) {
      case ArtGround.felt:
        const FeltPainter(rim: false, radius: 0).paint(canvas, size);
      case ArtGround.wood:
        const WoodPainter(radius: 0).paint(canvas, size);
      case ArtGround.paper:
        const FeltPainter(rim: false, radius: 0).paint(canvas, size);
      case ArtGround.day:
        SkyPainter(hills: true, horizon: 0.74, sun: id != 'stack_tower')
            .paint(canvas, size);
      case ArtGround.sunset:
        const SkyPainter(time: SkyTime.sunset, hills: true, horizon: 0.74)
            .paint(canvas, size);
      case ArtGround.night:
        _night(canvas, size);
      case ArtGround.grass:
        const GrassPainter(stripes: 6).paint(canvas, size);
      case ArtGround.court:
        const CourtPainter(planks: 7).paint(canvas, size);
      case ArtGround.ice:
        _ice(canvas, size);
      case ArtGround.water:
        const WaterPainter(radius: 0).paint(canvas, size);
      case ArtGround.track:
        const SkyPainter(time: SkyTime.sunset, horizon: 0.55, clouds: false)
            .paint(canvas, size);
        canvas.save();
        canvas.clipPath(Path()
          ..moveTo(size.width * 0.2, size.height * 0.6)
          ..lineTo(size.width * 0.8, size.height * 0.6)
          ..lineTo(size.width * 1.15, size.height)
          ..lineTo(-size.width * 0.15, size.height)
          ..close());
        const AsphaltPainter().paint(canvas, size);
        canvas.restore();
    }
    // A glow in the game colour behind the icon.
    final c = Offset(size.width / 2, size.height * 0.5);
    final glow = size.shortestSide * 0.62;
    canvas.drawCircle(
        c,
        glow,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0)
          ]).createShader(Rect.fromCircle(center: c, radius: glow)));

    final s = size.shortestSide * iconScale;
    if (ground == ArtGround.paper) {
      // A paper card, slightly turned, with the icon on it.
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.12);
      final card = Rect.fromCenter(
          center: Offset.zero, width: s * 1.25, height: s * 1.6);
      canvas.translate(
          card.left, card.top); // the paper painter draws at the origin
      PaperCardPainter(radius: s * 0.14, tint: color).paint(canvas, card.size);
      canvas.restore();
      paintIcon(canvas, gameIconFor(id),
          Rect.fromCenter(center: c, width: s * 0.85, height: s * 0.85),
          color: fillFor(color));
    } else {
      // Soft shadow, then the icon.
      canvas.drawOval(
          Rect.fromCenter(
              center: c + Offset(0, s * 0.52),
              width: s * 0.9,
              height: s * 0.16),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      paintIcon(canvas, gameIconFor(id),
          Rect.fromCenter(center: c, width: s, height: s),
          color: Colors.white);
    }
    canvas.restore();
  }

  void _night(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, NeonPalette.bgBottom, 0.55)!,
                NeonPalette.bgBottom
              ]).createShader(r));
    SkyPainter.drawStars(canvas, size);
  }

  void _ice(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE9F4FB), Color(0xFFBFDDEE)]).createShader(r));
    final line = Paint()
      ..color = const Color(0x66E5383B)
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.shortestSide * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x552E8BFF));
  }

  @override
  bool shouldRepaint(GameArtPainter old) =>
      old.id != id || old.color != color || old.iconScale != iconScale;
}

/// A game's art: its registered scene, or [GameArtPainter], fading into the night
/// background at the bottom when [fade] is on. Used by the intro header and How to play.
class GameArt extends StatelessWidget {
  final String id;
  final Color color;
  final bool fade;
  const GameArt(
      {super.key, required this.id, required this.color, this.fade = true});

  @override
  Widget build(BuildContext context) {
    final scene = gameScenes[id];
    return ExcludeSemantics(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(
            painter: scene?.call(color) ??
                GameArtPainter(id, color, iconScale: 0.46)),
        if (fade)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.5, 1],
                  colors: [Color(0x000B0E2E), NeonPalette.bg]),
            ),
          ),
      ]),
    );
  }
}

/// "2–4 players", "2 players" or SOLO.
String playersLabel(int min, int max) =>
    max <= 1 ? 'SOLO' : (max > min ? '$min–$max players' : '$max players');

/// A game in a grid (spec 4.4, Hub mockup): drawn art, name in Lilita, a player-count chip
/// and an optional star. Pressing sinks it; long-press also stars it.
class GameTile extends StatefulWidget {
  final String id, title;
  final Color color;
  final int minPlayers, maxPlayers;
  final bool? favourite; // null: no star button
  final VoidCallback onTap;
  final VoidCallback? onStar;
  final bool selected;
  const GameTile(
      {super.key,
      required this.id,
      required this.title,
      required this.color,
      required this.minPlayers,
      required this.maxPlayers,
      required this.onTap,
      this.favourite,
      this.onStar,
      this.selected = false});

  @override
  State<GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<GameTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final solo = w.maxPlayers <= 1;
    final flat = context.tk.flat;
    final tile = Semantics(
      button: true,
      selected: w.selected,
      label:
          '${w.title}, ${solo ? 'solo' : playersLabel(w.minPlayers, w.maxPlayers)}${w.favourite == true ? ', favourite' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          haptic(HapticWeight.selection);
          w.onTap();
        },
        onLongPress: w.onStar,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
          decoration: BoxDecoration(
            color: flat ? Colors.white : const Color(0xFF151A45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: w.selected
                    ? (flat ? FlatPalette.ink : Brand.gold)
                    : (flat
                        ? FlatPalette.stroke
                        : Colors.white.withValues(alpha: 0.12)),
                width: w.selected ? 2.5 : 1),
            boxShadow: _down
                ? null
                : [
                    flat
                        ? const BoxShadow(
                            color: Color(0x38000000), offset: Offset(0, 4))
                        : const BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 10,
                            offset: Offset(0, 4))
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ColoredBox(
                color: Color.lerp(
                    w.color,
                    flat ? Colors.white : const Color(0xFF10142E),
                    flat ? 0.72 : 0.55)!,
                child: Center(
                    child: GameBadge(id: w.id, color: w.color, size: 84)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(w.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: 17,
                            height: 1.15,
                            color: flat ? FlatPalette.ink : Colors.white)),
                    const SizedBox(height: 4),
                    PlayersChip(min: w.minPlayers, max: w.maxPlayers),
                  ]),
            ),
          ]),
        ),
      ),
    );
    if (w.favourite == null) return tile;
    return Stack(children: [
      Positioned.fill(child: tile),
      Positioned(
        top: 0,
        right: 0,
        child: Semantics(
          button: true,
          label: w.favourite! ? 'Unstar ${w.title}' : 'Star ${w.title}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: w.onStar,
            child: SizedBox(
              width: kTouchTarget,
              height: kTouchTarget,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0x990A0E28), shape: BoxShape.circle),
                  child: w.favourite!
                      ? const GameIcon(GameIcons.star,
                          size: 16, color: Brand.gold)
                      // Not a favourite: the same star, greyed out.
                      : ColorFiltered(
                          colorFilter: ColorFilter.mode(
                              Colors.white.withValues(alpha: 0.45),
                              BlendMode.srcIn),
                          child: const GameIcon(GameIcons.star, size: 16)),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// The small "2–4 players" / SOLO chip on tiles.
class PlayersChip extends StatelessWidget {
  final int min, max;
  const PlayersChip({super.key, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final solo = max <= 1;
    final flat = context.tk.flat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: solo
              ? Brand.gold.withValues(alpha: flat ? 0.45 : 0.22)
              : (flat
                  ? FlatPalette.option
                  : Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(8)),
      child: Text(playersLabel(min, max),
          style: TextStyle(
              fontFamily: Fonts.body,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: flat
                  ? FlatPalette.ink
                  : (solo ? const Color(0xFFFFE08A) : Colors.white))),
    );
  }
}

/// A square of a game's icon, e.g. for list rows and the lobby's next-game card.
class GameThumb extends StatelessWidget {
  final String id;
  final Color color;
  final double size;
  final double radius;
  const GameThumb(
      {super.key,
      required this.id,
      required this.color,
      this.size = 52,
      this.radius = 14});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: GameBadge(id: id, color: color, size: size, radius: radius));
}

/// The rounded game picture used on the games grid and anywhere a game is listed.
/// Every game id gets its own colour, gloss and drawn symbol.
class GameBadge extends StatelessWidget {
  final String id;
  final Color color;
  final double size;
  final double radius;
  const GameBadge(
      {super.key,
      required this.id,
      required this.color,
      this.size = 76,
      this.radius = 0});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child:
            CustomPaint(painter: GameBadgePainter(id, color, radius: radius)),
      );
}

class GameBadgePainter extends CustomPainter {
  final String id;
  final Color color;
  final double radius;
  const GameBadgePainter(this.id, this.color, {this.radius = 0});

  static int _mix(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 33 + c) & 0x7fffffff;
    }
    return h;
  }

  static Color _hsl(Color c, double hue, double light) {
    final h = HSLColor.fromColor(c);
    return h
        .withHue((h.hue + hue) % 360)
        .withLightness((h.lightness + light).clamp(0.28, 0.78))
        .withSaturation((h.saturation + 0.08).clamp(0.45, 1))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size(s, s);
    final r = RRect.fromRectAndRadius(
        rect, Radius.circular(radius > 0 ? radius : s * 0.24));
    canvas.save();
    canvas.clipRRect(r);
    final mix = _mix(id);
    final top = _hsl(color, (mix % 28) - 10, 0.16);
    final bottom = _hsl(color, ((mix >> 3) % 24) - 8, -0.16);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, color, bottom]).createShader(rect));
    // Gloss, like a physical app icon.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.08), width: s * 1.15, height: s * 0.55),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    final spot = Offset(
        s * (0.32 + (mix % 5) * 0.08), s * (0.28 + ((mix >> 2) % 4) * 0.06));
    canvas.drawCircle(
        spot, s * 0.34, Paint()..color = Colors.white.withValues(alpha: 0.10));
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.78), width: s * 0.46, height: s * 0.08),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final ink = bottom.computeLuminance() > 0.62
        ? const Color(0xFF1C1A17)
        : Colors.white;
    if (!_paintBoard(canvas, id, s, ink)) {
      paintIcon(
          canvas,
          gameIconFor(id),
          Rect.fromCenter(
              center: Offset(s * 0.5, s * 0.48),
              width: s * 0.56,
              height: s * 0.56),
          color: ink);
    }
    canvas.restore();
    canvas.drawRRect(
      r.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  /// A still picture of the real board, drawn instead of a generic icon.
  bool _paintBoard(Canvas canvas, String id, double s, Color ink) {
    final board = Rect.fromLTWH(s * 0.12, s * 0.16, s * 0.76, s * 0.62);
    final fill = Paint()..color = const Color(0xCC101410);
    final mark = Paint()..color = ink;
    switch (id) {
      case 'connect_four':
        canvas.drawRRect(
            RRect.fromRectAndRadius(board, const Radius.circular(6)), fill);
        for (var c = 0; c < 7; c++) {
          for (var r = 0; r < 5; r++) {
            final on = r > 2 && (c + r).isEven;
            canvas.drawCircle(
                Offset(board.left + (c + 0.5) * board.width / 7,
                    board.top + (r + 0.5) * board.height / 5),
                s * 0.035,
                Paint()
                  ..color = on
                      ? (c.isEven
                          ? const Color(0xFFE53935)
                          : const Color(0xFFFDD835))
                      : const Color(0xFF263238));
          }
        }
        return true;
      case 'battleship':
      case 'minesweeper':
      case 'minesweeper_race':
        canvas.drawRRect(
            RRect.fromRectAndRadius(board, const Radius.circular(4)), fill);
        for (var i = 1; i < 5; i++) {
          canvas.drawLine(
              Offset(board.left + board.width * i / 5, board.top),
              Offset(board.left + board.width * i / 5, board.bottom),
              mark..strokeWidth = 1);
          canvas.drawLine(Offset(board.left, board.top + board.height * i / 5),
              Offset(board.right, board.top + board.height * i / 5), mark);
        }
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(board.left + 4, board.top + board.height * 0.4,
                    board.width * 0.45, board.height * 0.16),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFFB0BEC5));
        return true;
      case 'ball_sort':
        for (var t = 0; t < 4; t++) {
          final x = board.left + (t + 0.5) * board.width / 4;
          final path = Path();
          for (var k = 0; k < 6; k++) {
            final a = (k / 6) * 6.283 + 0.5;
            final p = Offset(
                x + cos(a) * s * 0.07, board.center.dy + sin(a) * s * 0.11);
            if (k == 0) {
              path.moveTo(p.dx, p.dy);
            } else {
              path.lineTo(p.dx, p.dy);
            }
          }
          path.close();
          canvas.drawPath(
              path,
              Paint()
                ..color = Colors.white54
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
          for (var b = 0; b < 3; b++) {
            canvas.drawCircle(
                Offset(x, board.bottom - 10 - b * 12),
                5,
                Paint()
                  ..color = [
                    const Color(0xFFE53935),
                    const Color(0xFF1E88E5),
                    const Color(0xFF43A047),
                    const Color(0xFFFDD835)
                  ][t]);
          }
        }
        return true;
      case 'fruit_cut':
        canvas.drawCircle(Offset(board.left + 24, board.bottom - 20), 12,
            Paint()..color = const Color(0xFFE53935));
        canvas.drawCircle(Offset(board.center.dx, board.center.dy), 11,
            Paint()..color = const Color(0xFFFDD835));
        canvas.drawCircle(Offset(board.right - 22, board.top + 18), 10,
            Paint()..color = const Color(0xFF263238));
        return true;
      case 'carrom':
      case 'eight_ball':
        canvas.drawRRect(
            RRect.fromRectAndRadius(board, const Radius.circular(8)),
            Paint()
              ..color = id == 'carrom'
                  ? const Color(0xFFE6D3A3)
                  : const Color(0xFF1B5E20));
        for (final o in [
          const Offset(8, 8),
          const Offset(-8, 8),
          const Offset(8, -8),
          const Offset(-8, -8)
        ]) {
          final corner = o.dx > 0
              ? (o.dy > 0 ? board.topLeft : board.bottomLeft)
              : (o.dy > 0 ? board.topRight : board.bottomRight);
          canvas.drawCircle(corner + o, 4, Paint()..color = Colors.black);
        }
        canvas.drawCircle(
            board.center,
            6,
            Paint()
              ..color =
                  id == 'carrom' ? const Color(0xFFE53935) : Colors.white);
        canvas.drawCircle(board.center + const Offset(14, 4), 5,
            Paint()..color = const Color(0xFFFDD835));
        return true;
      case 'sweet_swap':
        const shades = [
          Color(0xFFE53935),
          Color(0xFF1E88E5),
          Color(0xFF43A047),
          Color(0xFFFDD835),
          Color(0xFF8E24AA)
        ];
        for (var r = 0; r < 4; r++) {
          for (var c = 0; c < 4; c++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                      board.left + c * board.width / 4 + 2,
                      board.top + r * board.height / 4 + 2,
                      board.width / 4 - 4,
                      board.height / 4 - 4),
                  const Radius.circular(4)),
              Paint()..color = shades[(r + c) % shades.length],
            );
          }
        }
        return true;
      case 'bike_race':
        canvas.drawRRect(
            RRect.fromRectAndRadius(board, const Radius.circular(6)),
            Paint()..color = const Color(0xFF1B5E20));
        canvas.drawLine(
            Offset(board.center.dx, board.top),
            Offset(board.center.dx, board.bottom),
            Paint()..color = Colors.white24);
        canvas.drawCircle(Offset(board.center.dx * 0.7, board.bottom - 16), 8,
            Paint()..color = const Color(0xFFFFB300));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(board.right - board.width / 2 + 6, board.top + 20,
                    board.width / 2 - 16, 10),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFFFFC107));
        return true;
      case 'chicken_jump':
        canvas.drawRect(
            Rect.fromLTWH(board.right - 28, board.top, 12, board.height * 0.3),
            Paint()..color = const Color(0xFF2E7D32));
        canvas.drawRect(
            Rect.fromLTWH(board.right - 28, board.bottom - board.height * 0.3,
                12, board.height * 0.3),
            Paint()..color = const Color(0xFF2E7D32));
        canvas.drawCircle(Offset(board.left + 28, board.center.dy), 10,
            Paint()..color = const Color(0xFFFFB300));
        return true;
      case 'hangman':
        canvas.drawLine(Offset(board.left + 16, board.bottom - 8),
            Offset(board.left + 70, board.bottom - 8), mark..strokeWidth = 2);
        canvas.drawLine(Offset(board.left + 28, board.bottom - 8),
            Offset(board.left + 28, board.top + 8), mark);
        canvas.drawLine(Offset(board.left + 28, board.top + 8),
            Offset(board.left + 52, board.top + 8), mark);
        canvas.drawCircle(Offset(board.left + 52, board.top + 20), 6,
            mark..style = PaintingStyle.stroke);
        return true;
      case 'color_switch':
        canvas.drawCircle(Offset(board.center.dx, board.bottom - 16), 8,
            Paint()..color = const Color(0xFFE53935));
        canvas.drawArc(Rect.fromCircle(center: board.center, radius: s * 0.16),
            0, 1.6, true, Paint()..color = const Color(0xFF1E88E5));
        canvas.drawArc(Rect.fromCircle(center: board.center, radius: s * 0.16),
            1.6, 1.6, true, Paint()..color = const Color(0xFFFDD835));
        return true;
      case 'knife_hit':
        canvas.drawCircle(
            board.center, s * 0.14, Paint()..color = const Color(0xFF8D6E63));
        canvas.drawLine(
            board.center + const Offset(0, 8),
            board.center + Offset(0, s * 0.28),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 3);
        return true;
      case 'hungry_hippos':
        canvas.drawCircle(Offset(board.center.dx, board.bottom - 8), 12,
            Paint()..color = const Color(0xFF7CB342));
        canvas.drawCircle(Offset(board.center.dx, board.top + 8), 12,
            Paint()..color = const Color(0xFF1E88E5));
        canvas.drawCircle(board.center, 5, Paint()..color = Colors.white);
        return true;
      case 'tug_of_war':
        canvas.drawLine(
            Offset(board.left + 8, board.center.dy),
            Offset(board.right - 8, board.center.dy),
            Paint()
              ..color = const Color(0xFFFFE0B2)
              ..strokeWidth = 4);
        canvas.drawCircle(Offset(board.left + 16, board.center.dy), 10,
            Paint()..color = const Color(0xFFE53935));
        canvas.drawCircle(Offset(board.right - 16, board.center.dy), 10,
            Paint()..color = const Color(0xFF1E88E5));
        canvas.drawCircle(board.center, 6, Paint()..color = Colors.white);
        return true;
      default:
        return false;
    }
  }

  @override
  bool shouldRepaint(GameBadgePainter old) =>
      old.id != id || old.color != color || old.radius != radius;
}
