import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/records/records.dart';
import '../../games/game_catalog.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../guess_person/widgets/gp_theme.dart';
import '../raja_mantri/rmcs_screen.dart';
import 'archery/archery_game.dart';
import 'basketball/basketball_game.dart';
import 'bottle_smash/bottle_smash_game.dart';
import 'mini_golf/mini_golf_game.dart';
import 'shooting_gallery/shooting_gallery_game.dart';
import 'slingshot/slingshot_game.dart';
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
import 'battleship/battleship_game.dart';
import 'bingo/bingo_game.dart';
import 'checkers/checkers_game.dart';
import 'dots_boxes/dots_boxes_game.dart';
import 'fruit_merge/fruit_merge_game.dart';
import 'ludo/ludo_game.dart';
import 'smash_karts/smash_karts_game.dart';
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
import 'solo/ball_sort.dart';
import 'solo/block_drop.dart';
import 'solo/bubble_shooter.dart';
import 'solo/color_switch.dart';
import 'solo/sky_jumper.dart';
import 'solo/space_shooter.dart';
import 'solo/brick_breaker.dart';
import 'solo/dino_run.dart';
import 'solo/hangman.dart';
import 'solo/sliding_puzzle.dart';
import 'solo/sudoku.dart';
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
  mostLikelyInfo, wouldRatherInfo, truthDareInfo, rpsInfo, fruitBattleInfo, bingoInfo, battleshipInfo, checkersInfo, smashKartsInfo,
  golfInfo, slingInfo, archeryInfo, galleryInfo, bottleInfo,
  // Solo games (shown in their own section).
  fruitMergeInfo, game2048Info, classicSnakeInfo, flappyInfo, minesweeperInfo, brickBreakerInfo, whackInfo, pianoInfo, wordScrambleInfo, stackInfo, simonInfo,
  ballSortInfo, slidingInfo, sudokuInfo, hangmanInfo, dinoInfo,
  blockDropInfo, bubbleInfo, skyInfo, spaceInfo, colorSwitchInfo];

/// The hub's games plus their team versions (e.g. Ludo 2 vs 2), for online rooms.
List<LocalGameInfo> get allLocalGames => [...localGames, for (final g in localGames) if (g.teamVariant != null) g.teamVariant!];

/// Everything in the hub: the shell games plus Guess the Person and Raja Mantri.
int get totalGameCount => localGames.length + 2;


/// A game in the list: one of the shell games, or Guess the Person / Raja Mantri.
class _Entry {
  final String id, emoji, title, tagline, players;
  final Color color;
  final GameCategory category;
  final bool solo;
  final WidgetBuilder open;
  const _Entry({
    required this.id,
    required this.emoji,
    required this.title,
    required this.tagline,
    required this.players,
    required this.color,
    required this.category,
    required this.open,
    this.solo = false,
  });
}

List<_Entry> _entries() {
  GameCategory categoryOf(String id) => gameCatalog.where((g) => g.id == id).firstOrNull?.category ?? GameCategory.party;
  return [
    _Entry(
      id: 'guess_person',
      emoji: '🕵️',
      title: 'Guess the Person',
      tagline: 'Ask questions, find the secret person',
      players: '2–6',
      color: const Color(0xFFFFC93C),
      category: GameCategory.party,
      open: (_) => const GuessPersonMenuScreen(),
    ),
    _Entry(
      id: 'raja_mantri',
      emoji: '👑',
      title: 'Raja Mantri Chor Sipahi',
      tagline: 'Can the Mantri catch the Chor?',
      players: '4',
      color: const Color(0xFF8A1C3A),
      category: GameCategory.cards,
      open: (_) => const RmcsMenuScreen(),
    ),
    for (final g in localGames)
      _Entry(
        id: g.id,
        emoji: g.emoji,
        title: g.title,
        tagline: g.tagline,
        players: g.solo ? 'SOLO' : (g.maxPlayers > g.minPlayers ? '${g.minPlayers}–${g.maxPlayers}' : '${g.maxPlayers}'),
        color: g.color,
        category: categoryOf(g.id),
        solo: g.solo,
        open: (_) => LocalGameShell(game: g),
      ),
  ];
}

enum _Filter { all, favourites, cards, board, action, party, solo }

const _filterLabels = {
  _Filter.all: '✨ All',
  _Filter.favourites: '⭐ Favourites',
  _Filter.cards: '🃏 Cards',
  _Filter.board: '🎲 Board',
  _Filter.action: '⚡ Action',
  _Filter.party: '🎉 Party',
  _Filter.solo: '🧍 Solo',
};

/// Every game that runs on one device, no server needed: together, or solo.
/// Search, categories, favourites (long-press a game) and recently played.
class LocalGamesHubScreen extends StatefulWidget {
  const LocalGamesHubScreen({super.key});
  @override
  State<LocalGamesHubScreen> createState() => _LocalGamesHubScreenState();
}

class _LocalGamesHubScreenState extends State<LocalGamesHubScreen> {
  final _entriesList = _entries();
  final _search = TextEditingController();
  var filter = _Filter.all;
  Set<String> favourites = {};
  List<String> recent = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final f = await Records.favourites(), r = await Records.recent();
    if (mounted) {
      setState(() {
        favourites = f;
        recent = r;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(_Entry e) async {
    await Navigator.push(context, MaterialPageRoute(builder: e.open));
    _load(); // a game may have just been played
  }

  Future<void> _toggleFavourite(_Entry e) async {
    HapticFeedback.mediumImpact().ignore();
    final f = await Records.toggleFavourite(e.id);
    if (!mounted) return;
    setState(() => favourites = f);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(f.contains(e.id) ? '⭐ ${e.title} added to favourites' : '${e.title} removed from favourites'), duration: const Duration(milliseconds: 1400)));
  }

  bool _matches(_Entry e) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !e.title.toLowerCase().contains(q) && !e.tagline.toLowerCase().contains(q)) return false;
    return switch (filter) {
      _Filter.all => true,
      _Filter.favourites => favourites.contains(e.id),
      _Filter.solo => e.solo,
      _Filter.cards => !e.solo && e.category == GameCategory.cards,
      _Filter.board => !e.solo && e.category == GameCategory.board,
      _Filter.action => !e.solo && e.category == GameCategory.action,
      _Filter.party => !e.solo && e.category == GameCategory.party,
    };
  }

  @override
  Widget build(BuildContext context) {
    final shown = _entriesList.where(_matches).toList();
    final together = shown.where((e) => !e.solo).toList(), solo = shown.where((e) => e.solo).toList();
    final browsing = filter == _Filter.all && _search.text.trim().isEmpty;
    final recentEntries = [for (final id in recent) ..._entriesList.where((e) => e.id == id)];

    Widget header(String text) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Text(text, style: const TextStyle(color: GpColors.accent, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.4)),
          ),
        );
    Widget grid(List<_Entry> items) => SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _Tile(entry: items[i], favourite: favourites.contains(items[i].id), onTap: () => _open(items[i]), onLongPress: () => _toggleFavourite(items[i])),
              childCount: items.length,
            ),
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
                  const Expanded(
                    child: Text('PARTY GAMES', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5, shadows: [Shadow(color: Color(0xFF6C5CE7), offset: Offset(0, 3))])),
                  ),
                  Text('$totalGameCount GAMES', style: const TextStyle(color: GpColors.accent, fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1)),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Search games…',
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(tooltip: 'Clear', onPressed: _search.clear, icon: const Icon(Icons.close_rounded, color: Colors.white54)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_filterLabels[f]!),
                          selected: filter == f,
                          onSelected: (_) => setState(() => filter = f),
                          showCheckmark: false,
                          labelStyle: TextStyle(color: filter == f ? GpColors.ink : Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                          selectedColor: GpColors.accent,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          side: BorderSide(color: filter == f ? GpColors.accent : Colors.white24),
                          shape: const StadiumBorder(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (browsing && recentEntries.isNotEmpty) ...[
              header('▶ RECENTLY PLAYED'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: recentEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _RecentTile(entry: recentEntries[i], onTap: () => _open(recentEntries[i])),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
            ],
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    filter == _Filter.favourites && _search.text.isEmpty ? '⭐ No favourites yet.\nLong-press any game to add it here.' : 'No games match "${_search.text.trim()}".',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700, fontSize: 15, height: 1.4),
                  ),
                ),
              ),
            if (together.isNotEmpty) ...[header('👥 PLAY TOGETHER'), grid(together)],
            if (solo.isNotEmpty) ...[header('🧍 SOLO GAMES'), grid(solo)],
            if (browsing)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text('Tip: long-press a game to ⭐ it', textAlign: TextAlign.center, style: TextStyle(color: GpColors.muted, fontSize: 12.5)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// A compact game tile: emoji, name and player count; ⭐ when it's a favourite.
class _Tile extends StatelessWidget {
  final _Entry entry;
  final bool favourite;
  final VoidCallback onTap, onLongPress;
  const _Tile({required this.entry, required this.favourite, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final color = entry.color;
    return Semantics(
      button: true,
      label: entry.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.08)!, Color.lerp(color, Colors.black, 0.3)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [BoxShadow(color: Color.lerp(color, Colors.black, 0.55)!, offset: const Offset(0, 4))],
            ),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                    child: Text(entry.players == 'SOLO' ? '🧍 SOLO' : '👥 ${entry.players}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.5)),
                  ),
                  Expanded(child: Center(child: FittedBox(child: Text(entry.emoji, style: const TextStyle(fontSize: 46))))),
                  Text(entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5, height: 1.1, shadows: [Shadow(color: Colors.black38, offset: Offset(0, 1))])),
                ]),
              ),
              if (favourite) const Positioned(top: 6, right: 7, child: Text('⭐', style: TextStyle(fontSize: 15))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final _Entry entry;
  final VoidCallback onTap;
  const _RecentTile({required this.entry, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Play ${entry.title} again',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: entry.color, width: 2),
            ),
            child: Row(children: [
              Text(entry.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5, height: 1.1)),
                  const SizedBox(height: 3),
                  Text('▶ PLAY', style: TextStyle(color: Color.lerp(entry.color, Colors.white, 0.4), fontWeight: FontWeight.w900, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
      );
}
