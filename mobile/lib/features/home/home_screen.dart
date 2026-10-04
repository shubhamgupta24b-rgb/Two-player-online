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
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';
import '../local_games/shell/local_game_shell.dart';
import '../privacy/privacy_screen.dart';
import '../quick_play/quick_play_screen.dart';
import '../raja_mantri/rmcs_screen.dart';
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
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
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
      await _connect(done: '📡 This phone is hosting: create a room!');
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
      emoji: '📡',
      title: 'Hosting on this phone',
      message: '1. Turn on this phone\'s HOTSPOT (or stay on the same Wi-Fi as your friends).\n'
          '2. Friends connect to it, open Party Games and tap 📶 SAME WI-FI → JOIN A FRIEND.\n'
          '3. Create a room here and share the code (or use Quick Play).\n\n'
          'No internet needed. Keep this app open while you play.'
          '${ips.isEmpty ? '' : '\n\nThis phone: ${ips.join(' · ')}'}',
      actions: [Builder(builder: (c) => AppButton('GOT IT', onPressed: () => Navigator.pop(c)))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthenticationManager>().displayName;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
                _header(name),
                const SizedBox(height: 18),
                _hero(),
                SectionTitle('PLAY ONLINE', trailing: _status(compact: true)),
                _modeSwitch(),
                const SizedBox(height: 12),
                _online(),
                SectionTitle('FEATURED GAMES',
                    trailing: TextButton(
                      onPressed: () => _open(const LocalGamesHubScreen()),
                      child: const Text('SEE ALL', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                    )),
                _featured(),
                const SectionTitle('MORE'),
                Row(children: [
                  Expanded(
                    child: _ActionCard(
                      title: '🏆 MY RECORDS',
                      subtitle: 'Best scores & wins',
                      icon: Icons.emoji_events_rounded,
                      colors: const [Color(0xFFFFB300), Color(0xFFFF6F00)],
                      onTap: () => _open(const RecordsScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: '⚡ QUICK PLAY',
                      subtitle: 'Join a random room',
                      icon: Icons.bolt_rounded,
                      colors: const [Color(0xFF00C9A7), Color(0xFF0E8C7B)],
                      onTap: () => _open(const QuickPlayScreen()),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(kTouchTarget, kTouchTarget)),
                    onPressed: () => _open(const PrivacyScreen()),
                    icon: const Icon(Icons.shield_outlined, size: 18, color: AppColors.muted),
                    label: const Text('Privacy', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String name) {
    return Row(children: [
      Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [AppColors.blue, AppColors.purple]),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Text(name.isEmpty ? '🙂' : name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? 'Hi there 👋' : 'Hi, $name 👋', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const Text('Ready to play?', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]),
      ),
      AppIconButton(icon: Icons.tune_rounded, tooltip: 'Settings', onPressed: () => showSettingsSheet(context)),
      const SizedBox(width: 4),
      const AppLogo(size: 52),
    ]);
  }

  Widget _status({bool compact = false}) => ValueListenableBuilder<bool>(
        valueListenable: _socket.connected,
        builder: (context, online, _) => Semantics(
          button: true,
          label: online ? 'Connected' : 'Not connected. Tap to try again',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: online ? null : _connect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (online ? AppColors.green : Colors.white).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: online ? AppColors.green : Colors.white24),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 9, color: online ? AppColors.green : Colors.white38),
                const SizedBox(width: 6),
                Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: online ? AppColors.green : Colors.white60, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
              ]),
            ),
          ),
        ),
      );

  Widget _hero() {
    return PressableCard(
      semanticLabel: 'Play on one device',
      colors: const [Color(0xFFFFC93C), Color(0xFFFF8A3D), Color(0xFFFF3B5C)],
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      onTap: () => _open(const LocalGamesHubScreen()),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PLAY ON\nONE DEVICE', style: TextStyle(color: Colors.white, fontSize: 26, height: 1.05, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2))])),
            const SizedBox(height: 8),
            Text('$totalGameCount games · 2–6 players\nNo internet needed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 12),
            const FittedBox(fit: BoxFit.scaleDown, child: _Pill('PLAY NOW', Icons.play_arrow_rounded)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: MediaQuery.sizeOf(context).width < 360 ? 84 : 110,
          height: 120,
          child: FittedBox(
            child: Column(children: [
              for (final row in const [['👑', '🏀'], ['🏒', '🃏']])
                Row(children: [
                  for (final (i, e) in row.indexed)
                    Transform.rotate(angle: i.isEven ? -0.15 : 0.15, child: Padding(padding: const EdgeInsets.all(4), child: Text(e, style: const TextStyle(fontSize: 40)))),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _online() {
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: _ActionCard(
          title: 'CREATE ROOM',
          subtitle: 'Host a game and share the code',
          icon: Icons.add_circle_rounded,
          colors: const [Color(0xFF2E8BFF), Color(0xFF1B4FD6)],
          onTap: () => _open(const CreateRoomScreen()),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ActionCard(
          title: 'JOIN ROOM',
          subtitle: "Enter a friend's room code",
          icon: Icons.login_rounded,
          colors: const [Color(0xFFFF3B5C), Color(0xFFC81E45)],
          onTap: () => _open(const JoinRoomScreen()),
        ),
      ),
    ]));
  }

  Widget _featured() {
    final picks = [
      for (final id in ['colour_clash', 'ludo'])
        for (final g in localGames.where((g) => g.id == id)) (g.emoji, g.title, g.color, () => _open(LocalGameShell(game: g))),
      ('👑', 'Raja Mantri', const Color(0xFF8A1C3A), () => _open(const RmcsMenuScreen())),
      ('🕵️', 'Guess the Person', const Color(0xFFE0A800), () => _open(const GuessPersonMenuScreen())),
      for (final id in ['truth_dare', 'snakes_ladders', 'basketball_hoops', 'air_hockey'])
        for (final g in localGames.where((g) => g.id == id)) (g.emoji, g.title, g.color, () => _open(LocalGameShell(game: g))),
    ];
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: picks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (emoji, title, color, onTap) = picks[i];
          return SizedBox(
            width: 112,
            child: PressableCard(
              semanticLabel: title,
              colors: [color, Color.lerp(color, Colors.black, 0.35)!],
              padding: const EdgeInsets.all(10),
              onTap: onTap,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Center(child: FittedBox(child: Text(emoji, style: const TextStyle(fontSize: 46))))),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, height: 1.1)),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// Online (internet server) or Same Wi-Fi (a laptop on this Wi-Fi/hotspot).
  Widget _modeSwitch() {
    final wifi = AppConfig.mode == ServerMode.wifi;
    Widget option(String emoji, String label, String hint, bool selected, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            label: label,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text('$emoji $label', style: TextStyle(color: selected ? AppColors.night : Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? AppColors.night.withValues(alpha: 0.75) : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.stroke)),
      child: Row(children: [
        option('🌐', 'ONLINE', 'Friends anywhere', !wifi, _useOnline),
        const SizedBox(width: 4),
        option('📶', 'SAME WI-FI', wifi ? (AppConfig.hosting ? '📡 Hosting on this phone' : 'Joined a host ✓ · change') : 'Hotspot, no internet', wifi, _useWifi),
      ]),
    );
  }
}

/// Same Wi-Fi / hotspot: HOST ON THIS PHONE (pops [host]) or JOIN A FRIEND, which searches
/// this Wi-Fi/hotspot for a phone or laptop hosting games and pops its URL when found.
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

  Widget _choice(String emoji, String title, String text, List<Color> colors, VoidCallback onTap) => PressableCard(
        semanticLabel: title,
        colors: colors,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
        ]),
      );

  Widget _chooser() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Play together with no internet: one phone hosts, the others join it.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        _choice('📡', 'HOST ON THIS PHONE', 'Turn on your hotspot. Friends join it and play here.', const [Color(0xFF7B4DFF), Color(0xFF4D2BD6)],
            () => Navigator.pop(context, _WifiSearchSheet.host)),
        const SizedBox(height: 12),
        _choice('🔍', 'JOIN A FRIEND', 'Connect to the host\'s hotspot (or same Wi-Fi), then search.', const [Color(0xFF00C9A7), Color(0xFF0E8C7B)], () {
          setState(() => choosing = false);
          _search();
        }),
      ]);

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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('📶 SAME WI-FI · NO INTERNET', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: 1)),
          const SizedBox(height: 14),
          if (choosing)
            _chooser()
          else if (searching) ...[
            const Text('Looking for the host on this Wi-Fi or hotspot…', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress == 0 ? null : progress, minHeight: 8, color: AppColors.gold, backgroundColor: AppColors.glass),
            ),
          ] else ...[
            const Text('No host found on this Wi-Fi yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            const Text(
              '1. One friend taps 📶 SAME WI-FI → HOST ON THIS PHONE and turns on their hotspot.\n'
              '2. Connect this phone to that hotspot (Settings → Wi-Fi).\n'
              '3. Tap SEARCH AGAIN.\n\n'
              'Have internet? Just use 🌐 ONLINE instead.',
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.wifi_find_rounded),
              label: const Text('SEARCH AGAIN', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'or type the host\'s address, e.g. 192.168.43.1'),
                  onSubmitted: (_) => _typed(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _typed, child: const Text('USE', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900))),
            ]),
          ],
        ]),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Pill(this.text, this.icon);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      );
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.colors, required this.onTap});
  @override
  Widget build(BuildContext context) => PressableCard(
        semanticLabel: title,
        colors: colors,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17))),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 2, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );
}
