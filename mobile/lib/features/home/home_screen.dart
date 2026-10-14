import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/lan/lan_host.dart';
import '../../core/network/lan_discovery.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/components.dart';
import '../create_room/create_room_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';
import '../privacy/privacy_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../quick_play/quick_play_screen.dart';
import '../records/records_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SocketManager _socket = context.read<SocketManager>();
  bool _rejoined = false;

  @override
  void initState() {
    super.initState();
    // The server connects in the background, so check both now and once it comes up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rejoinRoom());
    _socket.connected.addListener(_onConnection);
  }

  void _onConnection() {
    if (!_socket.connected.value) return;
    _rejoinRoom();
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
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// (Re)connects to the server for the current mode and says how it went.
  Future<void> _connect({String? done}) async {
    final token = context.read<AuthenticationManager>().token;
    final wifi = AppConfig.mode == ServerMode.wifi;
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
          '2. Friends connect to it, open RivalRooms and tap Same Wi-Fi, then Join a friend.\n'
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

  /// Play online always uses the internet server, then the same create / join / quick-play sheet as before.
  Future<void> _openPlayOnline() async {
    if (AppConfig.mode == ServerMode.wifi) await _useOnline();
    if (mounted) await _rooms();
  }

  Future<void> _sameWifi() async {
    final before = AppConfig.mode;
    await _useWifi();
    if (mounted && AppConfig.mode == ServerMode.wifi && (before != ServerMode.wifi || _socket.connected.value)) await _rooms();
  }

  /// Private rooms: create, join, or move onto the same Wi-Fi as a friend.
  Future<void> _withFriends() async {
    await showAppSheet<void>(
      context,
      title: 'Play with friends',
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
        _SheetOption(icon: GameIcons.wifi, tint: PlayerPalette.colors[3], title: 'Same Wi-Fi', text: 'Host on this phone, or join a friend nearby', onTap: () {
          Navigator.pop(ctx);
          _sameWifi();
        }),
      ]),
    );
  }

  void _openSettings() {
    showSettingsSheet(context, trailing: [
      const SizedBox(height: 8),
      _SettingsLink(label: 'Leaderboard', onTap: () => _open(const LeaderboardScreen())),
      _SettingsLink(label: 'My records', onTap: () => _open(const RecordsScreen())),
      _SettingsLink(label: 'Privacy', onTap: () => _open(const PrivacyScreen())),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthenticationManager>().displayName;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Scaffold(
      backgroundColor: const Color(0xFF100E0C),
      body: Stack(fit: StackFit.expand, children: [
        const Image(image: AssetImage('assets/start/air_hockey.jpg'), fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.28, 0.48, 1],
              colors: [Color(0x99000000), Color(0x33000000), Color(0x00000000), Color(0xF20A0C12)],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final short = constraints.maxHeight < 640;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, short ? 4 : 8, 18, 8),
                    child: Column(children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: _RoundIconButton(tooltip: 'Settings', icon: GameIcons.settings, onPressed: _openSettings),
                      ),
                      GameIcon(GameIcons.crown, size: short ? 22 : 28, color: const Color(0xFFF5C542)),
                      const SizedBox(height: 4),
                      Text.rich(
                        const TextSpan(children: [
                          TextSpan(text: 'Rival', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Rooms', style: TextStyle(color: Color(0xFFF5C542))),
                        ]),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: Fonts.body, fontSize: short ? 32 : 40, fontWeight: FontWeight.w900, height: 1, letterSpacing: -0.6),
                      ),
                      const SizedBox(height: 8),
                      const Text('TWO PLAYER GAMES', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.2, color: Color(0xE6FFFFFF))),
                      const SizedBox(height: 4),
                      const Text('Play mini games with your friends', style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xCCFFFFFF))),
                      const Spacer(),
                      _MenuButton(
                        compact: short,
                        gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        icon: GameIcons.people,
                        iconColor: Colors.white,
                        title: 'Play Online',
                        subtitle: 'With Friends Anywhere',
                        ink: Colors.white,
                        subInk: const Color(0xE6FFFFFF),
                        onTap: _openPlayOnline,
                      ),
                      SizedBox(height: short ? 6 : 10),
                      _MenuButton(
                        compact: short,
                        color: Colors.white,
                        icon: GameIcons.play,
                        iconColor: const Color(0xFF1C1A17),
                        title: 'Play Local',
                        subtitle: 'On Same Device',
                        ink: const Color(0xFF1C1A17),
                        subInk: const Color(0xFF5C564C),
                        onTap: () => _open(const LocalGamesHubScreen()),
                      ),
                      SizedBox(height: short ? 6 : 10),
                      _MenuButton(
                        compact: short,
                        color: const Color(0xFF2A3142),
                        icon: GameIcons.people,
                        iconColor: Colors.white,
                        title: 'Play with Friends',
                        subtitle: 'Create or Join Room',
                        ink: Colors.white,
                        subInk: const Color(0xCCFFFFFF),
                        onTap: _withFriends,
                      ),
                      SizedBox(height: short ? 8 : 16),
                      const Row(children: [
                        _Caption(icon: GameIcons.trophy, color: Color(0xFFF5C542), text: 'Multiple Mini Games'),
                        _Caption(icon: GameIcons.people, color: Color(0xFF60A5FA), text: '2-4 Players'),
                        _Caption(icon: GameIcons.play, color: Color(0xFF4ADE80), text: 'Fun with Friends'),
                      ]),
                      const SizedBox(height: 12),
                      _BottomNav(
                        initial: initial,
                        seat: AppSettings.playerColor.value,
                        onGames: () => _open(const LocalGamesHubScreen()),
                        onRooms: _withFriends,
                        onProfile: _openSettings,
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }

}

class _RoundIconButton extends StatelessWidget {
  final String tooltip;
  final GameIcons icon;
  final VoidCallback onPressed;
  const _RoundIconButton({required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xCC1A1D27),
        shape: const CircleBorder(side: BorderSide(color: Color(0x55FFFFFF))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            haptic(HapticWeight.selection);
            onPressed();
          },
          customBorder: const CircleBorder(),
          child: SizedBox(width: 44, height: 44, child: Center(child: GameIcon(icon, size: 20, color: Colors.white))),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final List<Color>? gradient;
  final Color? color;
  final bool compact;
  final GameIcons icon;
  final Color iconColor, ink, subInk;
  final String title, subtitle;
  final VoidCallback onTap;
  const _MenuButton({
    this.gradient,
    this.color,
    this.compact = false,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.subInk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          child: Ink(
            decoration: BoxDecoration(
              color: color,
              gradient: gradient == null ? null : LinearGradient(colors: gradient!),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 12),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: ink == Colors.white ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFF1F2F4), shape: BoxShape.circle),
                  child: GameIcon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontFamily: Fonts.body, fontSize: 17, fontWeight: FontWeight.w900, color: ink, height: 1.1)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w700, color: subInk)),
                  ]),
                ),
                GameIcon(GameIcons.forward, size: 16, color: subInk),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  final GameIcons icon;
  final Color color;
  final String text;
  const _Caption({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        GameIcon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Fonts.body, fontSize: 11, height: 1.2, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final String initial;
  final int seat;
  final VoidCallback onGames, onRooms, onProfile;
  const _BottomNav({required this.initial, required this.seat, required this.onGames, required this.onRooms, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, {GameIcons? icon, Widget? mark, bool selected = false, VoidCallback? onTap}) {
      final color = selected ? const Color(0xFF3B82F6) : const Color(0xCCFFFFFF);
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              mark ?? GameIcon(icon!, size: 22, color: color),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: const Color(0xF0141824), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0x33FFFFFF))),
      child: Row(children: [
        item('Home', icon: GameIcons.home, selected: true),
        item('Games', icon: GameIcons.play, onTap: onGames),
        item('Rooms', icon: GameIcons.people, onTap: onRooms),
        item('Profile', onTap: onProfile, mark: PlayerBadge(index: seat, size: 22, initial: initial)),
      ]),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SettingsLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        child: Text(label, style: const TextStyle(fontFamily: Fonts.body, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// An option row in a sheet: icon tile, title, a line of help.
class _SheetOption extends StatelessWidget {
  final GameIcons icon;
  final Color tint;
  final String title, text;
  final VoidCallback onTap;
  final bool onLight;
  const _SheetOption({required this.icon, required this.tint, required this.title, required this.text, required this.onTap, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: onLight ? Colors.white : (t.flat ? FlatPalette.option : Colors.white.withValues(alpha: 0.06)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(onLight ? 22 : Radii.lg), side: BorderSide(color: onLight ? leaderboardInk : (t.flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.12)), width: onLight ? 1.5 : 1)),
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
                decoration: BoxDecoration(color: onLight ? tint : tint.withValues(alpha: t.flat ? 0.9 : 0.22), borderRadius: Radii.rCard),
                child: GameIcon(icon, size: 22, color: onLight ? (tint.computeLuminance() > 0.55 ? leaderboardInk : Colors.white) : (t.flat ? onColor(tint) : Color.lerp(tint, Colors.white, 0.5)!)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontFamily: Fonts.display, fontSize: 18, color: onLight ? leaderboardInk : t.text)),
                  Text(text, style: TextStyle(fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w700, color: onLight ? const Color(0xFF5C564C) : t.textMuted)),
                ]),
              ),
              GameIcon(GameIcons.forward, size: 16, color: onLight ? leaderboardInk : t.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

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
        Text('SAME WI-FI · NO INTERNET', textAlign: TextAlign.center, style: t.cardStyles.label),
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
            '1. One friend taps Same Wi-Fi, then Host on this phone, and turns on their hotspot.\n'
            '2. Connect this phone to that hotspot (Settings, Wi-Fi).\n'
            '3. Tap Search again.\n\n'
            'Have internet? Use Play online instead.',
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
