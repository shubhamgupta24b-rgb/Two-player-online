import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/authentication_manager.dart';
import '../../core/records/records.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
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
import 'shell/game_art.dart';
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
  final String id, title, tagline;
  final int minPlayers, maxPlayers;
  final Color color;
  final GameCategory category;
  final WidgetBuilder open;
  const _Entry({
    required this.id,
    required this.title,
    required this.tagline,
    required this.minPlayers,
    required this.maxPlayers,
    required this.color,
    required this.category,
    required this.open,
  });
  bool get solo => maxPlayers <= 1;
}

List<_Entry> _entries() {
  GameCategory categoryOf(String id) => gameCatalog.where((g) => g.id == id).firstOrNull?.category ?? GameCategory.party;
  return [
    _Entry(
      id: 'guess_person',
      title: 'Guess the Person',
      tagline: 'Ask questions, find the secret person',
      minPlayers: 2,
      maxPlayers: 6,
      color: const Color(0xFFFFC93C),
      category: GameCategory.party,
      open: (_) => const GuessPersonMenuScreen(),
    ),
    _Entry(
      id: 'raja_mantri',
      title: 'Raja Mantri Chor Sipahi',
      tagline: 'Can the Mantri catch the Chor?',
      minPlayers: 4,
      maxPlayers: 4,
      color: const Color(0xFF8A1C3A),
      category: GameCategory.cards,
      open: (_) => const RmcsMenuScreen(),
    ),
    for (final g in localGames)
      _Entry(
        id: g.id,
        title: g.title,
        tagline: g.tagline,
        minPlayers: g.solo ? 1 : g.minPlayers,
        maxPlayers: g.maxPlayers,
        color: g.color,
        category: categoryOf(g.id),
        open: (_) => LocalGameShell(game: g),
      ),
  ];
}

enum _Filter { all, party, board, cards, action, solo, favourites }

const _filterLabels = {
  _Filter.all: 'All',
  _Filter.party: 'Party',
  _Filter.board: 'Board',
  _Filter.cards: 'Cards',
  _Filter.action: 'Action',
  _Filter.solo: 'Solo',
  _Filter.favourites: 'Favourites',
};

/// Player-count filter: null = any; 5 means 5-6.
const _counts = <int?>[null, 2, 3, 4, 5];

/// Every game that runs on one device (spec 4.4, mockup app/Hub.dc.html): search, category
/// tabs, a player-count filter, recently played and favourites (the star, or long-press).
class LocalGamesHubScreen extends StatefulWidget {
  const LocalGamesHubScreen({super.key});
  @override
  State<LocalGamesHubScreen> createState() => _LocalGamesHubScreenState();
}

class _LocalGamesHubScreenState extends State<LocalGamesHubScreen> {
  final _entriesList = _entries();
  final _search = TextEditingController();
  var filter = _Filter.all;
  int? players; // null: any
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
    haptic(HapticWeight.medium);
    final f = await Records.toggleFavourite(e.id);
    if (!mounted) return;
    setState(() => favourites = f);
    showToast(context, f.contains(e.id) ? '${e.title} added to favourites' : '${e.title} removed from favourites', tone: Tone.info, duration: const Duration(milliseconds: 1400));
  }

  bool _matches(_Entry e) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !e.title.toLowerCase().contains(q) && !e.tagline.toLowerCase().contains(q)) return false;
    if (players case final n?) {
      if (e.solo) return false;
      if (n >= 5 ? e.maxPlayers < 5 : (n < e.minPlayers || n > e.maxPlayers)) return false;
    }
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
    final query = _search.text.trim();
    final browsing = filter == _Filter.all && query.isEmpty && players == null;
    final recentEntries = [for (final id in recent) ..._entriesList.where((e) => e.id == id)];
    const gutter = EdgeInsets.symmetric(horizontal: 16);
    const ink = Color(0xFF1C1A17);
    const muted = Color(0xFF5C564C);
    final cols = MediaQuery.sizeOf(context).width >= 900 ? 6 : 4;

    Widget section(String text) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(text.toUpperCase(), style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: ink)),
          ),
        );
    Widget grid(List<_Entry> items) => SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 14, crossAxisSpacing: 8, childAspectRatio: 0.72),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final e = items[i];
                return _HubIcon(entry: e, favourite: favourites.contains(e.id), onTap: () => _open(e), onStar: () => _toggleFavourite(e));
              },
              childCount: items.length,
            ),
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconButton(tooltip: 'Back', onPressed: () => Navigator.maybePop(context), icon: const GameIcon(GameIcons.back, size: 20, color: ink)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Games', style: TextStyle(fontFamily: Fonts.body, fontSize: 32, height: 1, fontWeight: FontWeight.w900, color: ink)),
                        const SizedBox(height: 4),
                        const Text('Choose a game and start playing', style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
                        Text('$totalGameCount games', style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: muted)),
                      ]),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.only(top: 8), child: _HubProfile(onTap: () => showSettingsSheet(context))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: gutter,
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: ink),
                  decoration: InputDecoration(
                    hintText: 'Search games',
                    hintStyle: const TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w700, color: muted),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: const Padding(padding: EdgeInsets.only(left: 12, right: 8), child: GameIcon(GameIcons.search, size: 18, color: muted)),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Clear', onPressed: _search.clear, icon: const GameIcon(GameIcons.close, size: 16, color: muted)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE4E0D8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ink, width: 1.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE4E0D8))),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  for (final f in _Filter.values)
                    Padding(padding: const EdgeInsets.only(right: 6), child: _LightChip(_filterLabels[f]!, selected: filter == f, onTap: () => setState(() => filter = f))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: gutter,
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const Padding(padding: EdgeInsets.only(right: 8), child: Text('PLAYERS', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w900, color: ink))),
                  for (final n in _counts)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _LightChip(n == null ? 'Any' : (n >= 5 ? '5–6' : '$n'), selected: players == n, onTap: () => setState(() => players = n)),
                    ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (browsing && recentEntries.isNotEmpty) ...[
              section('Recently played'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _RecentTile(entry: recentEntries[i], onTap: () => _open(recentEntries[i])),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    GameIcon(filter == _Filter.favourites ? GameIcons.star : GameIcons.search, size: 44, color: const Color(0xFF5C564C)),
                    const SizedBox(height: 10),
                    Text(
                      filter == _Filter.favourites && query.isEmpty ? 'No favourites yet. Tap the star on any game to add it here.' : 'No games match "$query".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF5C564C)),
                    ),
                    if (query.isNotEmpty || players != null) ...[
                      const SizedBox(height: 12),
                      KitButton('Clear search', style: KitButtonStyle.outline, onPressed: () {
                        _search.clear();
                        setState(() => players = null);
                      }),
                    ],
                  ]),
                ),
              ),
            if (browsing) ...[
              if (together.isNotEmpty) ...[section('Play together'), grid(together)],
              if (solo.isNotEmpty) ...[section('Solo games'), grid(solo)],
            ] else
              grid(shown),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
    );
  }
}

/// A recently played game: its icon, name and "Play again".
class _RecentTile extends StatelessWidget {
  final _Entry entry;
  final VoidCallback onTap;
  const _RecentTile({required this.entry, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play ${entry.title} again',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 84,
          child: Column(children: [
            GameBadge(id: entry.id, color: entry.color, size: 64),
            const SizedBox(height: 6),
            Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1C1A17))),
            const Text('Play again', style: TextStyle(fontFamily: Fonts.body, fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1F8A4C))),
          ]),
        ),
      ),
    );
  }
}

class _HubIcon extends StatelessWidget {
  final _Entry entry;
  final bool favourite;
  final VoidCallback onTap, onStar;
  const _HubIcon({required this.entry, required this.favourite, required this.onTap, required this.onStar});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final count = e.maxPlayers <= 1 ? 'solo' : playersLabel(e.minPlayers, e.maxPlayers);
    return Stack(children: [
      Semantics(
        button: true,
        label: '${e.title}, $count${favourite ? ', favourite' : ''}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          onLongPress: onStar,
          child: Column(children: [
            Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: GameBadge(id: e.id, color: e.color)))),
            const SizedBox(height: 6),
            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Fonts.body, fontSize: 12, height: 1.15, fontWeight: FontWeight.w800, color: Color(0xFF1C1A17))),
          ]),
        ),
      ),
      if (favourite)
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: 'Unstar ${e.title}',
            child: GestureDetector(
              onTap: onStar,
              child: const SizedBox(width: 28, height: 28, child: Center(child: GameIcon(GameIcons.star, size: 16, color: Color(0xFFF5C542)))),
            ),
          ),
        ),
    ]);
  }
}

class _LightChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LightChip(this.label, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          haptic(HapticWeight.selection);
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1C1A17) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? const Color(0xFF1C1A17) : const Color(0xFFE4E0D8)),
          ),
          child: Text(label, style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : const Color(0xFF1C1A17))),
        ),
      ),
    );
  }
}

class _HubProfile extends StatelessWidget {
  final VoidCallback onTap;
  const _HubProfile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    var authName = '';
    try {
      authName = context.watch<AuthenticationManager>().displayName;
    } on ProviderNotFoundException {
      authName = '';
    }
    return ValueListenableBuilder<String>(
      valueListenable: AppSettings.playerName,
      builder: (context, saved, _) {
        return ValueListenableBuilder<int>(
          valueListenable: AppSettings.playerColor,
          builder: (context, seat, _) {
            final name = saved.isNotEmpty ? saved : authName;
            return Semantics(
              button: true,
              label: 'Profile and settings',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: PlayerBadge(index: seat, size: 40, initial: name.isEmpty ? '?' : name[0].toUpperCase()),
              ),
            );
          },
        );
      },
    );
  }
}
