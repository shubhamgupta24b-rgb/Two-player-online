import 'package:flutter/material.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../guess_person/widgets/gp_theme.dart';
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
import 'shell/local_game_info.dart';
import 'shell/local_game_shell.dart';

final localGames = <LocalGameInfo>[crushItInfo, basketballInfo, fruitDuelInfo, memoryInfo, paintFightInfo, ticTacToeInfo,
  airHockeyInfo, pingPongInfo, snakeDuelInfo, reactionTapInfo, penaltyInfo, mathDuelInfo, connectFourInfo];

/// All 2-player games that run on one device, no server needed.
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
      for (final g in localGames)
        _Tile(
          emoji: g.emoji,
          title: g.title,
          tagline: g.tagline,
          players: g.maxPlayers > 2 ? '2–${g.maxPlayers}' : '2',
          color: g.color,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LocalGameShell(game: g))),
        ),
    ];
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(children: [
                  Text('PARTY GAMES', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xFF6C5CE7), offset: Offset(0, 4))])),
                  Text('15 GAMES · ONE DEVICE · NO INTERNET', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.82),
                delegate: SliverChildListDelegate(tiles),
              ),
            ),
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
                    child: Text('👥 $players', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
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
