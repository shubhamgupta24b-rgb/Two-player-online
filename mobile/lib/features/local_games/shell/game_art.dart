import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';

/// Each game's drawn icon (no emoji in game UI). Used by the intro header, How to play,
/// results and (later) the hub tiles.
const gameIcons = <String, GameIcons>{
  'air_hockey': GameIcons.puck,
  'archery': GameIcons.bow,
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

/// A painted scene for a game's header. Games register theirs in [gameScenes] as they are
/// redesigned; the rest get [GameArt]'s default: the game colour, a glow and its icon.
typedef ScenePainterBuilder = CustomPainter Function(Color color);
final gameScenes = <String, ScenePainterBuilder>{};

/// A game's art: its scene (or the default glow + icon), fading into the night background
/// at the bottom when [fade] is on. Used by the intro header and How to play.
class GameArt extends StatelessWidget {
  final String id;
  final Color color;
  final bool fade;
  const GameArt({super.key, required this.id, required this.color, this.fade = true});

  @override
  Widget build(BuildContext context) {
    final scene = gameScenes[id];
    return ExcludeSemantics(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: scene?.call(color) ?? _DefaultArt(color)),
        if (scene == null)
          LayoutBuilder(
            builder: (_, c) {
              final s = math.min(c.maxHeight * 0.52, 120.0);
              return Align(
                alignment: const Alignment(0, -0.1),
                child: Container(
                  width: s * 1.45,
                  height: s * 1.45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                  ),
                  child: GameIcon(gameIconFor(id), size: s, color: Colors.white),
                ),
              );
            },
          ),
        if (fade)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.45, 1], colors: [Color(0x000B0E2E), NeonPalette.bg]),
            ),
          ),
      ]),
    );
  }
}

/// Default header art: the game colour as a deep gradient, a soft spotlight, diagonal
/// stripes and a few sparkles.
class _DefaultArt extends CustomPainter {
  final Color color;
  _DefaultArt(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Color.lerp(color, Colors.white, 0.1)!,
            Color.lerp(color, NeonPalette.bg, 0.35)!,
            Color.lerp(color, NeonPalette.bg, 0.75)!,
          ]).createShader(r));
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var x = -size.height; x < size.width; x += 34) {
      canvas.drawPath(
          Path()
            ..moveTo(x, size.height)
            ..lineTo(x + 16, size.height)
            ..lineTo(x + 16 + size.height, 0)
            ..lineTo(x + size.height, 0)
            ..close(),
          stripe);
    }
    final spot = Offset(size.width / 2, size.height * 0.42);
    final rad = size.width * 0.5;
    canvas.drawCircle(spot, rad, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.24), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: spot, radius: rad)));
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.4);
    for (final (x, y, s) in const [(0.08, 0.2, 2.0), (0.9, 0.16, 2.4), (0.18, 0.62, 1.6), (0.84, 0.58, 1.8), (0.3, 0.1, 1.4), (0.7, 0.3, 1.5)]) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), s, dot);
    }
  }

  @override
  bool shouldRepaint(_DefaultArt old) => old.color != color;
}
