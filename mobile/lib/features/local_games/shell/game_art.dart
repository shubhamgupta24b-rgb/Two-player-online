import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'game_previews.dart';

/// Each game's drawn icon, for places too small for a preview.
const gameIcons = <String, GameIcons>{
  'j_fishing': GameIcons.duck,
  'j_fireworks': GameIcons.star,
  'j_knifeHit': GameIcons.target,
  'j_flappyDunk': GameIcons.ball,
  'j_hungryHippos': GameIcons.mole,
  'j_hotPotato': GameIcons.bottle,
  'j_findIt': GameIcons.magnifier,
  'j_soccerStars': GameIcons.football,
  'j_ringToss': GameIcons.target,
  'air_hockey': GameIcons.puck,
  'archery': GameIcons.target,
  'ball_sort': GameIcons.bottle,
  'basketball_hoops': GameIcons.ball,
  'backgammon': GameIcons.dice6,
  'battleship': GameIcons.target,
  'carrom': GameIcons.coin,
  'eight_ball_pool': GameIcons.ball,
  'darts': GameIcons.target,
  'hot_potato': GameIcons.bottle,
  'hungry_hippos': GameIcons.mole,
  'bingo': GameIcons.star,
  'block_drop': GameIcons.stoneBlock,
  'bottle_smash': GameIcons.bottle,
  'brick_breaker': GameIcons.woodBlock,
  'bubble_shooter': GameIcons.drop,
  'charades': GameIcons.clapper,
  'checkers': GameIcons.crownKing,
  'chess': GameIcons.crown,
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
  'fruit_cut': GameIcons.apple,
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
  'nitro_knockout': GameIcons.rocket,
  'slot_cars': GameIcons.rocket,
  'snake_duel': GameIcons.snake,
  'snakes_ladders': GameIcons.ladder,
  'space_shooter': GameIcons.ufo,
  'stack_tower': GameIcons.woodBlock,
  'sudoku': GameIcons.pencil,
  'tic_tac_toe': GameIcons.cross,
  'truth_dare': GameIcons.bottle,
  'undercover': GameIcons.mask,
  'uno': GameIcons.mysteryBox,
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

/// Custom scene painters a game may register (no longer shown; previews replaced them).
typedef ScenePainterBuilder = CustomPainter Function(Color color);
final gameScenes = <String, ScenePainterBuilder>{};

/// A game's picture (library tiles, rooms, records, start screen): its painted preview.
class GameArtPainter extends CustomPainter {
  final String id;
  final Color color;
  final double iconScale; // kept for callers; the previews fill their canvas
  const GameArtPainter(this.id, this.color, {this.iconScale = 0.5});

  @override
  void paint(Canvas canvas, Size size) => paintGamePreview(canvas, size, id);

  @override
  bool shouldRepaint(GameArtPainter old) => old.id != id;
}

/// A game's art as a widget: its painted preview, with no fade (text sits below it).
class GameArt extends StatelessWidget {
  final String id;
  final Color color;
  final bool fade;
  const GameArt({super.key, required this.id, required this.color, this.fade = true});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: CustomPaint(painter: GameArtPainter(id, color), size: Size.infinite));
}

/// "2–4 players", "2 players" or Solo.
String playersLabel(int min, int max) => max <= 1 ? 'Solo' : (max > min ? '$min–$max players' : '$max players');

/// A game in a grid: its preview fills the tile, with the name and player count underneath.
/// Pressing sinks it a little; long-press stars it.
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
    final t = context.tk;
    final tile = Semantics(
      button: true,
      selected: w.selected,
      label: '${w.title}, ${solo ? 'solo' : playersLabel(w.minPlayers, w.maxPlayers)}${w.favourite == true ? ', favourite' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          haptic(HapticWeight.selection);
          w.onTap();
        },
        onLongPress: w.onStar,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: Motion.of(context, Motion.fast),
          curve: Motion.standard,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: Radii.rLg,
                  border: w.selected ? Border.all(color: Brand.gold, width: 3) : null,
                ),
                child: CustomPaint(painter: GameArtPainter(w.id, w.color), size: Size.infinite),
              ),
            ),
            const SizedBox(height: 8),
            Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.styles.h3.copyWith(fontSize: 17, height: 1.2, color: t.onBg)),
            const SizedBox(height: 2),
            PlayersChip(min: w.minPlayers, max: w.maxPlayers),
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
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0x8C161513), shape: BoxShape.circle),
                  child: GameIcon(GameIcons.star, size: 16, color: w.favourite! ? Brand.gold : const Color(0xCCF5EFE4)),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// The quiet "2–4 players" / Solo line on tiles.
class PlayersChip extends StatelessWidget {
  final int min, max;
  const PlayersChip({super.key, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Text(playersLabel(min, max), maxLines: 1, style: t.styles.bodySmall.copyWith(fontSize: 13, color: t.onBgMuted));
  }
}

/// A square of a game's art, e.g. for list rows and the lobby's next-game card.
class GameThumb extends StatelessWidget {
  final String id;
  final Color color;
  final double size;
  final double radius;
  const GameThumb({super.key, required this.id, required this.color, this.size = 52, this.radius = 14});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(width: size, height: size, child: CustomPaint(painter: GameArtPainter(id, color, iconScale: 0.62))),
        ),
      );
}
