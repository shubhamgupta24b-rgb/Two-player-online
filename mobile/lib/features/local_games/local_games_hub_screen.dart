import 'package:flutter/material.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../guess_person/widgets/gp_theme.dart';
import '../raja_mantri/rmcs_screen.dart';
import 'basketball/basketball_game.dart';
import 'crush_it/crush_it_game.dart';
import 'fruit_duel/fruit_duel_game.dart';
import 'memory/memory_game.dart';
import 'paint_fight/paint_fight_game.dart';
import 'air_hockey/air_hockey_game.dart';
import 'connect_four/connect_four_game.dart';
import 'math_duel/math_duel_game.dart';
import 'penalty/penalty_game.dart';
import 'ping_pong/ping_pong_game.dart';
import 'reaction_tap/reaction_tap_game.dart';
import 'snake_duel/snake_duel_game.dart';
import 'tic_tac_toe/tic_tac_toe_game.dart';
import 'colour_clash/colour_clash_game.dart';
import 'dots_boxes/dots_boxes_game.dart';
import 'fruit_merge/fruit_merge_game.dart';
import 'ludo/ludo_game.dart';
import 'snakes_ladders/snakes_ladders_game.dart';
import 'truth_dare/truth_dare_game.dart';
import 'charades/charades_game.dart';
import 'draw_guess/draw_guess_game.dart';
import 'find_spy/find_spy_game.dart';
import 'hand_cricket/hand_cricket_game.dart';
import 'heads_up/heads_up_game.dart';
import 'mafia/mafia_game.dart';
import 'most_likely/most_likely_game.dart';
import 'quiz_battle/quiz_battle_game.dart';
import 'undercover/undercover_game.dart';
import 'would_rather/would_rather_game.dart';
import 'rps/rps_game.dart';
import 'solo/brick_breaker.dart';
import 'solo/classic_snake.dart';
import 'solo/flappy_jump.dart';
import 'solo/game_2048.dart';
import 'solo/minesweeper.dart';
import 'solo/piano_tiles.dart';
import 'solo/simon_says.dart';
import 'solo/stack_tower.dart';
import 'solo/whack_mole.dart';
import 'solo/word_scramble.dart';
import 'shell/local_game_info.dart';
import 'shell/local_game_shell.dart';

final localGames = <LocalGameInfo>[colourClashInfo, findSpyInfo, ludoInfo, mafiaInfo, undercoverInfo, charadesInfo, snakesLaddersInfo,
  drawGuessInfo, headsUpInfo, quizBattleInfo, handCricketInfo, crushItInfo, basketballInfo, fruitDuelInfo, memoryInfo, paintFightInfo,
  ticTacToeInfo, airHockeyInfo, pingPongInfo, snakeDuelInfo, reactionTapInfo, penaltyInfo, mathDuelInfo, connectFourInfo, dotsBoxesInfo,
  mostLikelyInfo, wouldRatherInfo, truthDareInfo, rpsInfo, fruitBattleInfo,
  // Solo games (shown in their own section).
  fruitMergeInfo, game2048Info, classicSnakeInfo, flappyInfo, minesweeperInfo, brickBreakerInfo, whackInfo, pianoInfo, wordScrambleInfo, stackInfo, simonInfo];

/// Everything in the hub: the shell games plus Guess the Person and Raja Mantri.
int get totalGameCount => localGames.length + 2;

/// Every game that runs on one device, no server needed: together, or solo.
class LocalGamesHubScreen extends StatelessWidget {
  const LocalGamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _Tile(
        emoji: '🕵️',
        title: 'Guess the Person',
        tagline: 'Ask questions, find the secret person',
        players: '2–6',
        color: const Color(0xFFFFC93C),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuessPersonMenuScreen())),
      ),
      _Tile(
        emoji: '👑',
        title: 'Raja Mantri Chor Sipahi',
        tagline: 'Can the Mantri catch the Chor?',
        players: '4',
        color: const Color(0xFF8A1C3A),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RmcsMenuScreen())),
      ),
      for (final g in localGames.where((g) => !g.solo))
        _Tile(
          emoji: g.emoji,
          title: g.title,
          tagline: g.tagline,
          players: g.maxPlayers > g.minPlayers ? '${g.minPlayers}–${g.maxPlayers}' : '${g.maxPlayers}',
          color: g.color,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LocalGameShell(game: g))),
        ),
    ];
    final solo = [
      for (final g in localGames.where((g) => g.solo))
        _Tile(
          emoji: g.emoji,
          title: g.title,
          tagline: g.tagline,
          players: 'SOLO',
          color: g.color,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LocalGameShell(game: g))),
        ),
    ];
    Widget header(String text) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(text, style: const TextStyle(color: GpColors.accent, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
          ),
        );
    Widget grid(List<Widget> items) => SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.82),
            delegate: SliverChildListDelegate(items),
          ),
        );
    return Scaffold(
      body: GpBackground(
        child: SafeArea(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(children: [
                  const Text('PARTY GAMES', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xFF6C5CE7), offset: Offset(0, 4))])),
                  Text('$totalGameCount GAMES · ONE DEVICE · NO INTERNET',
                      textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
              ),
            ),
            header('👥 PLAY TOGETHER'),
            grid(tiles),
            header('🧍 SOLO GAMES'),
            grid(solo),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String emoji;
  final String title;
  final String tagline;
  final String players;
  final Color color;
  final VoidCallback onTap;
  const _Tile({required this.emoji, required this.title, required this.tagline, required this.players, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Color.lerp(color, Colors.black, 0.5)!, offset: const Offset(0, 5))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                    child: Text(players == 'SOLO' ? '🧍 SOLO' : '👥 $players', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ]),
                Expanded(child: Center(child: FittedBox(child: Text(emoji, style: const TextStyle(fontSize: 64))))),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.1, shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1))])),
                const SizedBox(height: 4),
                Text(tagline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
