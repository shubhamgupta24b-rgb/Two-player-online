import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/lan/lan_host.dart';
import '../../core/network/lan_discovery.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/records/records.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../create_room/create_room_screen.dart';
import '../join_room/join_room_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';
import '../privacy/privacy_screen.dart';
import '../quick_play/quick_play_screen.dart';
import '../settings/settings_screen.dart';
import 'game_card.dart';
import 'home_chrome.dart';
import 'home_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeTab { trending, all }

enum _HomeFilter { all, party, board, cards, action, solo, favourites }

const _filterLabels = {
  _HomeFilter.all: 'All',
  _HomeFilter.party: 'Party',
  _HomeFilter.board: 'Board',
  _HomeFilter.cards: 'Cards',
  _HomeFilter.action: 'Action',
  _HomeFilter.solo: 'Solo',
  _HomeFilter.favourites: 'Favourites',
};

class _HomeScreenState extends State<HomeScreen> {
  late final SocketManager _socket = context.read<SocketManager>();
  bool _rejoined = false;
  bool _linking = false;
  var _tab = _HomeTab.trending;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  var _filter = _HomeFilter.all;
  int? _players;
  Set<String> _favourites = {};
  List<String> _trendingIds = trendingFallbackIds;
  List<BoardRow>? _board;
  bool _boardFromPhone = false;
  bool _boardOffline = false;
  bool _boardError = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _rejoinRoom());
    _socket.connected.addListener(_onConnection);
    _loadFavourites();
    _loadTrending();
    _loadBoard();
  }

  void _onConnection() {
    if (_socket.connected.value) _rejoinRoom();
  }

  /// If the server still has us in a room (e.g. app restarted), jump back in.
  Future<void> _rejoinRoom() async {
    if (_rejoined || !_socket.connected.value || !mounted) return;
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    await rm.resync();
    if (rm.room != null && mounted && !_rejoined) {
      _rejoined = true;
      nav.push(MaterialPageRoute(builder: (_) => const LobbyScreen()));
    }
  }

  @override
  void dispose() {
    _socket.connected.removeListener(_onConnection);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// (Re)connects to the server for the current mode and says how it went.
  Future<void> _connect({String? done}) async {
    final token = context.read<AuthenticationManager>().token;
    final wifi = AppConfig.mode == ServerMode.wifi;
    if (mounted) setState(() => _linking = true);
    try {
      await _socket.connect(AppConfig.serverUrl, token);
      if (mounted) showToast(context, done ?? 'Connected!', tone: Tone.success);
    } catch (_) {
      if (!mounted) return;
      showToast(
        context,
        wifi ? 'The host isn\'t answering. Is their app still open, on the same hotspot or Wi-Fi?' : 'Not connected yet. The server may be waking up (up to a minute): it keeps trying by itself.',
        tone: Tone.warn,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _useOnline() async {
    if (AppConfig.mode == ServerMode.online && _socket.connected.value) return;
    if (AppConfig.hosting) await LanHost.stop();
    await AppConfig.useOnline();
    if (!mounted) return;
    setState(() {});
    await _connect(done: 'Online: play with friends anywhere');
  }

  /// Same Wi-Fi / hotspot, no internet: host the games on this phone, or join a phone
  /// (or laptop) that hosts them.
  Future<void> _useWifi() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tk.flat ? Colors.white : NeonPalette.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _WifiSearchSheet(),
    );
    if (choice == null || !mounted) return;
    if (choice == _WifiSearchSheet.host) {
      try {
        await LanHost.start();
      } catch (_) {
        if (mounted) showToast(context, 'Could not start hosting on this phone. Close other game apps and try again.', tone: Tone.danger, duration: const Duration(seconds: 4));
        return;
      }
      await AppConfig.useWifi(LanHost.selfUrl, hosting: true);
      if (!mounted) return;
      setState(() {});
      await _connect(done: 'This phone is hosting: create a room!');
      if (mounted) await _showHostHelp();
      return;
    }
    if (AppConfig.hosting) await LanHost.stop();
    await AppConfig.useWifi(choice);
    if (!mounted) return;
    setState(() {});
    await _connect(done: 'Connected to the host on this Wi-Fi');
  }

  /// What the host tells their friends.
  Future<void> _showHostHelp() async {
    final ips = await LanHost.addresses();
    if (!mounted) return;
    await showAppDialog<void>(
      context,
      emoji: null,
      title: 'Hosting on this phone',
      message: '1. Turn on this phone\'s hotspot (or stay on the same Wi-Fi as your friends).\n'
          '2. Friends connect to it, open RivalRooms and tap Online / Wi-Fi, then Same host.\n'
          '3. Create a room here and share the code (or use Quick Play).\n\n'
          'No internet needed. Keep this app open while you play.'
          '${ips.isEmpty ? '' : '\n\nThis phone: ${ips.join(' · ')}'}',
      actions: [Builder(builder: (c) => GoldButton('Got it', onPressed: () => Navigator.pop(c)))],
    );
  }

  /// Create, join or quick play, on the server picked by the mode (online or the Wi-Fi host).
  Future<void> _rooms() async {
    final wifi = AppConfig.mode == ServerMode.wifi;
    await showAppSheet<void>(
      context,
      title: wifi ? 'Rooms on this Wi-Fi' : 'Play online',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SheetOption(icon: GameIcons.plus, tint: PlayerPalette.colors[0], title: 'Create room', text: 'Host a game and share the code', onTap: () {
          Navigator.pop(ctx);
          _open(const CreateRoomScreen());
        }),
        const SizedBox(height: 10),
        _SheetOption(icon: GameIcons.forward, tint: PlayerPalette.colors[1], title: 'Join room', text: "Enter a friend's 6-letter code", onTap: () {
          Navigator.pop(ctx);
          _open(const JoinRoomScreen());
        }),
        const SizedBox(height: 10),
        _SheetOption(icon: GameIcons.bolt, tint: PlayerPalette.colors[2], title: 'Quick play', text: 'Jump into an open room', onTap: () {
          Navigator.pop(ctx);
          _open(const QuickPlayScreen());
        }),
      ]),
    );
  }

  /// Online / Wi-Fi: same-network host, or the internet server. Each path is the existing one.
  Future<void> _chooseLink() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeColors.lavender.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _MenuSheet(
        title: 'Online / Wi-Fi',
        children: [
          _MenuRow(icon: GameIcons.wifi, label: 'Same host', onTap: () => Navigator.pop(ctx, 'host')),
          _MenuRow(icon: GameIcons.globe, label: 'Online', onTap: () => Navigator.pop(ctx, 'online')),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'host') {
      await _sameWifi();
    } else if (choice == 'online') {
      await _onOnline();
    }
  }

  /// Games that open on this phone. The hub list is that set; online-only catalog ids are not included.
  Future<void> _offlineGames() async {
    final games = listedGames();
    final picked = await showModalBottomSheet<ListedGame>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeColors.lavender.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _MenuSheet(
        title: 'On this phone',
        height: MediaQuery.sizeOf(ctx).height * 0.72,
        children: [
          for (final game in games) _MenuRow(icon: GameIcons.play, label: game.title, onTap: () => Navigator.pop(ctx, game)),
        ],
      ),
    );
    if (picked != null && mounted) await _openListed(picked);
  }

  Future<void> _profileMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeColors.lavender.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _MenuSheet(
        title: 'Account',
        children: [
          _MenuRow(icon: GameIcons.people, label: 'Profile', onTap: () => Navigator.pop(ctx, 'profile')),
          _MenuRow(icon: GameIcons.settings, label: 'Settings', onTap: () => Navigator.pop(ctx, 'settings')),
          _MenuRow(icon: GameIcons.shield, label: 'Privacy Policy', onTap: () => Navigator.pop(ctx, 'privacy')),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'profile':
        _open(const ProfileScreen());
      case 'settings':
        _open(const SettingsScreen());
      case 'privacy':
        _open(const PrivacyScreen());
    }
  }

  /// Play-online actions always use the internet server, even if this phone was hosting on Wi-Fi.
  Future<void> _onOnline() async {
    await _useOnline();
    if (mounted) await _rooms();
  }

  Future<void> _loadFavourites() async {
    try {
      final f = await Records.favourites();
      if (mounted) setState(() => _favourites = f);
    } catch (_) {}
  }

  Future<void> _loadTrending() async {
    final counts = await _socket.request('online_counts');
    if (!mounted) return;
    final known = listedGames().map((g) => g.id).toSet();
    final live = trendingIdsFromCounts(counts, known);
    if (live.isNotEmpty) setState(() => _trendingIds = live);
  }

  Future<void> _loadBoard() async {
    final board = await _socket.request('leaderboard');
    if (!mounted) return;
    final remote = board['ok'] == true ? rowsFromLeaderboardJson(board) : const <BoardRow>[];
    if (remote.isNotEmpty) {
      setState(() {
        _board = remote.take(3).toList();
        _boardFromPhone = false;
        _boardOffline = false;
        _boardError = false;
      });
      return;
    }
    final local = await _phoneRow();
    if (!mounted) return;
    final offline = board['error'] == 'OFFLINE';
    setState(() {
      _board = local == null ? const [] : [local];
      _boardFromPhone = local != null;
      _boardOffline = offline;
      _boardError = local == null && !offline && board['ok'] != true;
    });
  }

  Future<BoardRow?> _phoneRow() async {
    final records = await Records.all();
    var played = 0, wins = 0;
    for (final r in records.values) {
      played += r.played;
      wins += r.wins;
    }
    if (played == 0 && wins == 0) return null;
    if (!mounted) return null;
    final name = context.read<AuthenticationManager>().displayName.trim();
    return BoardRow(name: name.isEmpty ? 'You' : name, wins: wins, played: played);
  }

  bool _matches(ListedGame game) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !game.title.toLowerCase().contains(q) && !game.tagline.toLowerCase().contains(q)) return false;
    if (_players case final n?) {
      if (game.solo) return false;
      if (n >= 5 ? game.maxPlayers < 5 : (n < game.minPlayers || n > game.maxPlayers)) return false;
    }
    return switch (_filter) {
      _HomeFilter.all => true,
      _HomeFilter.favourites => _favourites.contains(game.id),
      _HomeFilter.solo => game.solo,
      _HomeFilter.cards => !game.solo && game.category == GameCategory.cards,
      _HomeFilter.board => !game.solo && game.category == GameCategory.board,
      _HomeFilter.action => !game.solo && game.category == GameCategory.action,
      _HomeFilter.party => !game.solo && game.category == GameCategory.party,
    };
  }

  List<ListedGame> _visibleGames() {
    final all = listedGames();
    if (_tab == _HomeTab.trending) {
      final byId = {for (final g in all) g.id: g};
      return [for (final id in _trendingIds) if (byId[id] case final g?) g];
    }
    return all.where(_matches).toList();
  }

  Future<void> _sameWifi() async {
    final before = AppConfig.mode;
    await _useWifi();
    if (mounted && AppConfig.mode == ServerMode.wifi && (before != ServerMode.wifi || _socket.connected.value)) await _rooms();
  }

  Future<void> _openListed(ListedGame game) async {
    await Navigator.push(context, MaterialPageRoute(builder: game.open));
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthenticationManager>().displayName;
    final colors = HomeColors.of(context);
    final games = _visibleGames();
    final onlineMode = AppConfig.mode == ServerMode.online;
    final trending = _tab == _HomeTab.trending;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(children: [
              _header(name, colors),
              _tabs(colors),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 18),
                  children: [
                    if (!trending) ...[
                      _searchField(colors),
                      _filters(colors),
                    ],
                    if (games.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                        child: Text(
                          _filter == _HomeFilter.favourites && _search.text.trim().isEmpty
                              ? 'No favourites yet. Star a game in the games list.'
                              : 'No games match.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: colors.muted),
                        ),
                      )
                    else
                      _grid(games),
                    if (trending) ...[
                      _modes(onlineMode, colors),
                      _leaderboard(colors),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header(String name, HomeColors colors) {
    final seat = AppSettings.playerColor.value;
    final shown = name.trim().isEmpty ? 'Player' : name.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(children: [
        ValueListenableBuilder<bool>(
          valueListenable: _socket.connected,
          builder: (context, online, _) {
            final connecting = _linking && !online;
            final dot = online ? colors.online : (connecting ? HomeColors.connecting : HomeColors.offlineDot);
            final status = online ? 'Connected' : (connecting ? 'Connecting' : 'Offline');
            return Semantics(
              button: true,
              label: 'Profile, $status',
              child: InkWell(
                key: const Key('home-profile'),
                customBorder: const CircleBorder(),
                onTap: _profileMenu,
                child: SizedBox(
                  width: HomeMetrics.headerAvatar,
                  height: HomeMetrics.headerAvatar,
                  child: Stack(children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.avatar),
                      child: PlayerBadge(index: seat, size: 44, initial: shown == 'Player' ? '?' : shown[0].toUpperCase()),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: colors.bg, width: 2)),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w600, color: colors.muted)),
            Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, fontSize: 19, height: 1.15, fontWeight: FontWeight.w800, color: colors.text)),
          ]),
        ),
        IconButton(
          key: const Key('home-search'),
          tooltip: 'Search games',
          onPressed: () {
            setState(() => _tab = _HomeTab.all);
            _searchFocus.requestFocus();
          },
          icon: GameIcon(GameIcons.search, size: 20, color: colors.text),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFE9E1FF), minimumSize: const Size(kTouchTarget, kTouchTarget)),
        ),
      ]),
    );
  }

  Widget _tabs(HomeColors colors) {
    Widget tab(String label, _HomeTab value) {
      final selected = _tab == value;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: Key(value == _HomeTab.trending ? 'home-tab-trending' : 'home-tab-all'),
          onTap: () => setState(() => _tab = value),
          child: Container(
            constraints: const BoxConstraints(minHeight: kTouchTarget),
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? colors.blue : Colors.transparent, width: 2))),
            child: Text(label, style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w700, color: selected ? colors.blue : colors.tabIdle)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(children: [
        tab('Trending', _HomeTab.trending),
        const SizedBox(width: 16),
        tab('All Games', _HomeTab.all),
      ]),
    );
  }

  Widget _searchField(HomeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w700, color: colors.text),
        decoration: InputDecoration(
          hintText: 'Search games',
          hintStyle: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w700, color: colors.muted),
          isDense: true,
          filled: true,
          fillColor: colors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: colors.blue, width: 1.5)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
        ),
      ),
    );
  }

  Widget _filters(HomeColors colors) {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? colors.blue : colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? colors.blue : colors.border),
              ),
              child: Text(label, style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : colors.text)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final f in _HomeFilter.values) chip(_filterLabels[f]!, _filter == f, () => setState(() => _filter = f)),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final n in const [null, 2, 3, 4, 5])
              chip(n == null ? 'Any' : (n >= 5 ? '5–6' : '$n'), _players == n, () => setState(() => _players = n)),
          ]),
        ),
      ]),
    );
  }

  Widget _grid(List<ListedGame> games) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cols = allGamesColumns(width);
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
      final cardW = (width - HomeMetrics.gridPad * 2 - HomeMetrics.gridGap * (cols - 1)) / cols;
      final titleBlock = (8 + 10 + HomeMetrics.titleSize * 1.2 * 2) * scale;
      final extent = cardW / HomeMetrics.imageAspect + titleBlock;
      return GridView.count(
        key: Key(_tab == _HomeTab.all ? 'all-games-grid' : 'trending-grid'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(HomeMetrics.gridPad, 12, HomeMetrics.gridPad, 8),
        crossAxisCount: cols,
        mainAxisSpacing: HomeMetrics.gridGap,
        crossAxisSpacing: HomeMetrics.gridGap,
        childAspectRatio: cardW / extent,
        children: [
          for (final game in games) HomeGameCard(id: game.id, title: game.title, onTap: () => _openListed(game)),
        ],
      );
    });
  }

  Widget _modes(bool onlineMode, HomeColors colors) {
    Widget button(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: active ? colors.blue : colors.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: active ? colors.blue : colors.buttonBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: active ? Colors.white : colors.text)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(children: [
        button('Online / Wi-Fi', onlineMode, _chooseLink),
        const SizedBox(width: 9),
        button('Offline', false, _offlineGames),
      ]),
    );
  }

  Widget _leaderboard(HomeColors colors) {
    final rows = _board;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: colors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(const LeaderboardScreen()),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Leaderboard', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: colors.text))),
                Text('View all', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w700, color: colors.muted)),
              ]),
              const SizedBox(height: 8),
              if (rows == null)
                Text('Loading scores', style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: colors.muted))
              else if (_boardError)
                Text('Could not load the leaderboard.', style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: colors.muted))
              else if (rows.isEmpty)
                Text(
                  _boardOffline ? 'Not connected. Rankings show up once you are online.' : 'No wins yet. Finish a game and the ranking starts here.',
                  style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: colors.muted),
                )
              else ...[
                if (_boardFromPhone)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Showing wins saved on this phone.', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w700, color: colors.muted)),
                  ),
                for (var i = 0; i < rows.length; i++) _rank(i + 1, rows[i], colors),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _rank(int place, BoardRow row, HomeColors colors) {
    final (Color bg, Color ink) = switch (place) {
      1 => (colors.gold, const Color(0xFF49320A)),
      2 => (const Color(0xFFD9DCE5), const Color(0xFF454957)),
      3 => (const Color(0xFFE7A06B), const Color(0xFF5D2F0D)),
      _ => (colors.blue, Colors.white),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 23,
          height: 23,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text('$place', style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w800, color: ink)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: colors.text))),
        Text('${row.wins}', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w700, color: colors.text)),
      ]),
    );
  }
}

class _MenuSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double? height;
  const _MenuSheet({required this.title, required this.children, this.height});

  @override
  Widget build(BuildContext context) {
    final colors = HomeColors.lavender;
    final titleStyle = TextStyle(fontFamily: Fonts.body, fontSize: 18, fontWeight: FontWeight.w800, color: colors.text);
    final list = height == null
        ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
        : Expanded(child: ListView(children: children));
    return CallbackShortcuts(
      bindings: {SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context)},
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              height: height,
              child: Column(mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, textAlign: TextAlign.center, style: titleStyle),
                const SizedBox(height: 8),
                list,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final GameIcons icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = HomeColors.lavender;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kTouchTarget),
        child: Row(children: [
          GameIcon(icon, size: 20, color: colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontFamily: Fonts.body, fontSize: 16, fontWeight: FontWeight.w800, color: colors.text))),
        ]),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final GameIcons icon;
  final Color tint;
  final String title, text;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.tint, required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: t.flat ? FlatPalette.option : Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: t.flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.12))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint.withValues(alpha: t.flat ? 0.9 : 0.22), borderRadius: Radii.rCard),
                child: GameIcon(icon, size: 22, color: t.flat ? onColor(tint) : Color.lerp(tint, Colors.white, 0.5)!),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontFamily: Fonts.display, fontSize: 18, color: t.text)),
                  Text(text, style: TextStyle(fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w700, color: t.textMuted)),
                ]),
              ),
              GameIcon(GameIcons.forward, size: 16, color: t.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The hero card picture: a die and two cards (Main mockup).
/// Same Wi-Fi / hotspot: Host on this phone (pops [host]) or Join a friend, which searches
/// this Wi-Fi/hotspot for a phone or laptop hosting games and pops its URL when found;
/// or type the host's address.
class _WifiSearchSheet extends StatefulWidget {
  static const host = 'host';
  const _WifiSearchSheet();
  @override
  State<_WifiSearchSheet> createState() => _WifiSearchSheetState();
}

class _WifiSearchSheetState extends State<_WifiSearchSheet> {
  double progress = 0;
  bool choosing = true; // host or join?
  bool searching = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      searching = true;
      progress = 0;
    });
    final url = await LanDiscovery.find(onProgress: (p) {
      if (mounted) setState(() => progress = p);
    });
    if (!mounted) return;
    if (url != null) {
      Navigator.pop(context, url);
    } else {
      setState(() => searching = false);
    }
  }

  void _typed() {
    final url = AppConfig.normalise(_ctrl.text.contains(':') || _ctrl.text.startsWith('http') ? _ctrl.text : '${_ctrl.text}:${LanDiscovery.port}');
    if (url != null) Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final muted = TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, height: 1.4, color: t.textMuted);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: t.text.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 12),
        Text('Same Wi-Fi', textAlign: TextAlign.center, style: t.cardStyles.label),
        const SizedBox(height: 2),
        Text(choosing ? 'Play on one hotspot' : (searching ? 'Looking for the host…' : 'No host found yet'), textAlign: TextAlign.center, style: t.cardStyles.h2),
        const SizedBox(height: 14),
        if (choosing) ...[
          Text('One phone hosts, the others join it. No internet needed.', textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 14),
          _SheetOption(
              icon: GameIcons.wifi,
              tint: PlayerPalette.colors[3],
              title: 'Host on this phone',
              text: 'Turn on your hotspot. Friends join it and play here.',
              onTap: () => Navigator.pop(context, _WifiSearchSheet.host)),
          const SizedBox(height: 10),
          _SheetOption(
              icon: GameIcons.search,
              tint: PlayerPalette.colors[2],
              title: 'Join a friend',
              text: "Connect to the host's hotspot (or same Wi-Fi), then search.",
              onTap: () {
                setState(() => choosing = false);
                _search();
              }),
        ] else if (searching) ...[
          Text('Searching this Wi-Fi or hotspot…', textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress == 0 ? null : progress, minHeight: 8, color: Brand.gold, backgroundColor: t.text.withValues(alpha: 0.12)),
          ),
        ] else ...[
          Text(
            '1. One friend taps Online / Wi-Fi, then Same host, and turns on their hotspot.\n'
            '2. Connect this phone to that hotspot (Settings, Wi-Fi).\n'
            '3. Tap Search again.\n\n'
            'Have internet? Choose Online instead.',
            style: muted,
          ),
          const SizedBox(height: 14),
          GoldButton('Search again', icon: GameIcons.search, onPressed: _search),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w800, color: t.text),
                decoration: InputDecoration(
                  hintText: "Host's address, e.g. 192.168.43.1",
                  hintStyle: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w700, color: t.textMuted),
                  fillColor: t.flat ? FlatPalette.option : Colors.white.withValues(alpha: 0.08),
                ),
                onSubmitted: (_) => _typed(),
              ),
            ),
            const SizedBox(width: 8),
            KitButton('Use', style: KitButtonStyle.outline, onPressed: _typed),
          ]),
        ],
      ]),
    );
  }
}
