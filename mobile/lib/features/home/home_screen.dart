import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/lan/lan_host.dart';
import '../../core/network/lan_discovery.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../core/ui/components.dart';
import '../create_room/create_room_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';
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
  int _tab = 0;
  int _records = 0; // bumped to reload records when their tab opens

  @override
  void initState() {
    super.initState();
    // The server connects in the background, so check both now and once it comes up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rejoinRoom());
    _socket.connected.addListener(_onConnection);
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
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// (Re)connects to the server for the current mode and says how it went.
  Future<void> _connect({String? done}) async {
    final token = context.read<AuthenticationManager>().token;
    final wifi = AppConfig.mode == ServerMode.wifi;
    try {
      await _socket.connect(AppConfig.serverUrl, token);
      if (mounted) showToast(context, done ?? 'Connected', tone: Tone.success);
    } catch (_) {
      if (!mounted) return;
      showToast(
        context,
        wifi ? 'The host isn\'t answering. Check that their app is open and both phones use the same Wi-Fi.' : 'Connecting to the server. This can take a minute.',
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
    await _connect(done: 'Connected online');
  }

  /// Same Wi-Fi / hotspot, no internet: host the games on this phone, or join a phone
  /// (or laptop) that hosts them.
  Future<void> _useWifi() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tk.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      await _connect(done: 'This phone is hosting. Create a room');
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
          '2. Friends connect to it, open Party Games and tap Same Wi-Fi, then Join a friend.\n'
          '3. Create a room here and share the code (or use Quick Play).\n\n'
          'No internet needed. Keep this app open while you play.'
          '${ips.isEmpty ? '' : '\n\nThis phone: ${ips.join(' · ')}'}',
      actions: [Builder(builder: (c) => GoldButton('Got it', onPressed: () => Navigator.pop(c)))],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        const LocalGamesHubScreen(embedded: true),
        _roomsTab(),
        RecordsScreen(key: ValueKey(_records), embedded: true),
      ]),
      bottomNavigationBar: _TabBar(index: _tab, onSelect: (i) => setState(() {
            _tab = i;
            if (i == 2) _records++;
          })),
    );
  }

  /// Rooms: what you can do, then how this phone connects.
  Widget _roomsTab() {
    final t = context.tk;
    final wifi = AppConfig.mode == ServerMode.wifi;
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              Row(children: [
                Expanded(child: Semantics(header: true, child: Text('Rooms', style: t.styles.h1.copyWith(color: t.onBg)))),
                _status(),
                const SizedBox(width: 4),
                RoundButton(icon: GameIcons.settings, label: 'Settings', onPressed: () => showSettingsSheet(context)),
              ]),
              const SizedBox(height: 4),
              Text('Play with friends on separate phones', style: t.styles.body.copyWith(color: t.onBgMuted)),
              const SizedBox(height: 24),
              GoldButton('Create room', icon: GameIcons.plus, onPressed: () => _open(const CreateRoomScreen())),
              const SizedBox(height: 8),
              _Group(children: [
                _Row(icon: GameIcons.lock, title: 'Join room', text: "Enter a friend's 6-letter code", onTap: () => _open(const JoinRoomScreen())),
                _Row(icon: GameIcons.bolt, title: 'Quick play', text: 'Join an open room', onTap: () => _open(const QuickPlayScreen())),
              ]),
              const SizedBox(height: 32),
              Text('Connect through', style: t.styles.h3.copyWith(color: t.onBg)),
              const SizedBox(height: 8),
              _Group(children: [
                _Row(icon: GameIcons.globe, title: 'Play online', text: 'Friends anywhere', selected: !wifi, onTap: _useOnline),
                _Row(icon: GameIcons.wifi, title: 'Same Wi-Fi', text: AppConfig.hosting ? 'Hosting on this phone' : 'Play over a shared hotspot or Wi-Fi', selected: wifi, onTap: _useWifi),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  /// Online / Hosting on this phone / On a Wi-Fi host / Offline. Tap to retry when offline.
  Widget _status() => ValueListenableBuilder<bool>(
        valueListenable: _socket.connected,
        builder: (context, online, _) {
          final t = context.tk;
          final wifi = AppConfig.mode == ServerMode.wifi;
          final label = !online ? 'Offline' : (wifi ? (AppConfig.hosting ? 'Hosting' : 'Wi-Fi host') : 'Online');
          return Semantics(
            button: !online,
            label: online ? '$label: connected' : 'Offline. Tap to try again',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: Radii.rChip,
              onTap: online ? null : _connect,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kTouchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: online ? t.success : t.onBgMuted, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(label, style: t.styles.bodySmall.copyWith(color: t.onBgMuted)),
                  ]),
                ),
              ),
            ),
          );
        },
      );
}

/// The app's tab bar: Play, Rooms, Records.
class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.index, required this.onSelect});

  static const _tabs = [(GameIcons.play, 'Play'), (GameIcons.people, 'Rooms'), (GameIcons.trophy, 'Records')];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.flat ? FlatPalette.surface : NeonPalette.sheet, border: Border(top: BorderSide(color: t.stroke))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: _tabs[i].$2,
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: () {
                      haptic(HapticWeight.selection);
                      onSelect(i);
                    },
                    child: Opacity(
                      opacity: i == index ? 1 : 0.62,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _tabIcon(context, i, i == index),
                        const SizedBox(height: 2),
                        Text(_tabs[i].$2, style: t.styles.micro.copyWith(color: i == index ? t.onBg : t.onBgMuted, fontWeight: i == index ? FontWeight.w600 : FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _tabIcon(BuildContext context, int i, bool on) {
    final t = context.tk;
    final icon = GameIcon(_tabs[i].$1, size: 22, color: on ? (t.flat ? Brand.goldDeep : Brand.gold) : t.onBgMuted);
    if (_tabs[i].$1 != GameIcons.trophy) return icon;
    // The trophy is multi-tone art: flatten it to the tab colour like its neighbours.
    return ColorFiltered(colorFilter: ColorFilter.mode(on ? (t.flat ? Brand.goldDeep : Brand.gold) : t.onBgMuted, BlendMode.srcIn), child: icon);
  }
}

/// A grouped list of rows on one card.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: t.card, borderRadius: Radii.rLg, border: Border.all(color: t.stroke)),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Padding(padding: const EdgeInsets.only(left: 52), child: Divider(height: 1, thickness: 1, color: t.stroke)),
          children[i],
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final GameIcons icon;
  final String title, text;
  final bool? selected;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, required this.text, required this.onTap, this.selected});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $text',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                SizedBox(width: 36, child: Align(alignment: Alignment.centerLeft, child: GameIcon(icon, size: 22, color: t.textMuted))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: t.cardStyles.bodyStrong),
                    Text(text, style: t.cardStyles.bodySmall),
                  ]),
                ),
                if (selected == true) GameIcon(GameIcons.check, size: 20, color: t.flat ? Brand.goldDeep : Brand.gold) else if (selected == null) GameIcon(GameIcons.forward, size: 16, color: t.textMuted),
              ]),
            ),
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
        Text('Same Wi-Fi, no internet', textAlign: TextAlign.center, style: t.cardStyles.label),
        const SizedBox(height: 2),
        Text(choosing ? 'Play on one hotspot' : (searching ? 'Looking for the host…' : 'No host found yet'), textAlign: TextAlign.center, style: t.cardStyles.h2),
        const SizedBox(height: 14),
        if (choosing) ...[
          Text('One phone hosts, the others join it. No internet needed.', textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 14),
          _Group(children: [
            _Row(icon: GameIcons.wifi, title: 'Host on this phone', text: 'Turn on your hotspot. Friends join it and play here.', onTap: () => Navigator.pop(context, _WifiSearchSheet.host)),
            _Row(icon: GameIcons.search, title: 'Join a friend', text: "Connect to the host's hotspot (or same Wi-Fi), then search.", onTap: () {
              setState(() => choosing = false);
              _search();
            }),
          ]),
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
                style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w600, color: t.text),
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
