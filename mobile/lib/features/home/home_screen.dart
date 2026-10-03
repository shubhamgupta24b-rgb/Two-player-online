import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../create_room/create_room_screen.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';
import '../local_games/shell/local_game_shell.dart';
import '../raja_mantri/rmcs_screen.dart';

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

  /// Lets players point the app at their PC on the same Wi-Fi, or at a hosted server.
  Future<void> _editServer() async {
    final url = await showDialog<String>(context: context, builder: (_) => const _ServerDialog());
    if (url == null || !mounted) return;
    final normalised = AppConfig.normalise(url);
    final messenger = ScaffoldMessenger.of(context);
    if (normalised == null) {
      messenger.showSnackBar(const SnackBar(content: Text('That is not a valid server address.')));
      return;
    }
    await AppConfig.save(normalised);
    if (!mounted) return;
    setState(() {});
    final token = context.read<AuthenticationManager>().token;
    messenger.showSnackBar(SnackBar(content: Text('Connecting to $normalised…')));
    try {
      await _socket.connect(normalised, token);
      messenger.showSnackBar(const SnackBar(content: Text('Connected!')));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('No answer from $normalised yet. Still trying: a sleeping server can take a minute to wake up.')));
    }
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
                _online(),
                SectionTitle('FEATURED GAMES',
                    trailing: TextButton(
                      onPressed: () => _open(const LocalGamesHubScreen()),
                      child: const Text('SEE ALL', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                    )),
                _featured(),
                const SectionTitle('COMING SOON'),
                const Row(children: [
                  Expanded(child: _SoonTile(icon: Icons.bolt_rounded, title: 'QUICK PLAY', subtitle: 'Match with anyone')),
                  SizedBox(width: 12),
                  Expanded(child: _SoonTile(icon: Icons.emoji_events_rounded, title: 'PROFILE', subtitle: 'Stats & trophies')),
                ]),
                const SizedBox(height: 22),
                _serverRow(),
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
      const AppLogo(size: 52),
    ]);
  }

  Widget _status({bool compact = false}) => ValueListenableBuilder<bool>(
        valueListenable: _socket.connected,
        builder: (context, online, _) => Semantics(
          button: true,
          label: online ? 'Online. Change server' : 'Offline. Change server',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _editServer,
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

  Widget _serverRow() => Center(
        child: TextButton.icon(
          onPressed: _editServer,
          icon: const Icon(Icons.dns_rounded, size: 18, color: AppColors.muted),
          label: Text('Server: ${AppConfig.serverUrl}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
        ),
      );
}

/// Owns its text controller so it lives until the dialog has finished closing.
class _ServerDialog extends StatefulWidget {
  const _ServerDialog();
  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  final _ctrl = TextEditingController(text: AppConfig.serverUrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Game server'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Same Wi-Fi: your PC\'s address, e.g. 192.168.1.20:3000\nOnline: your hosted URL, e.g. https://my-game.onrender.com'),
            const SizedBox(height: 12),
            TextField(controller: _ctrl, autofocus: true, keyboardType: TextInputType.url, decoration: const InputDecoration(border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, AppConfig.defaultServerUrl), child: const Text('RESET')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('SAVE')),
        ],
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

class _SoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SoonTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$title, coming later',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.stroke)),
          child: Row(children: [
            Icon(icon, color: Colors.white38),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w900, fontSize: 12.5)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ),
          ]),
        ),
      );
}
