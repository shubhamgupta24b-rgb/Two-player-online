import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../create_room/create_room_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';

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

  /// Lets players point the app at their PC on the same Wi-Fi, or at a hosted server.
  Future<void> _editServer() async {
    final ctrl = TextEditingController(text: AppConfig.serverUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Game server'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Same Wi-Fi: your PC\'s address, e.g. 192.168.1.20:3000\nOnline: your hosted URL, e.g. https://my-game.onrender.com'),
          const SizedBox(height: 12),
          TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.url, decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, AppConfig.defaultServerUrl), child: const Text('RESET')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('SAVE')),
        ],
      ),
    );
    ctrl.dispose();
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
      messenger.showSnackBar(SnackBar(content: Text('Could not reach $normalised. Is the server running?')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget big(String t, VoidCallback? f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FilledButton(onPressed: f, child: Padding(padding: const EdgeInsets.all(16), child: Text(t))));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('PARTY GAMES', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 32),
              big('PLAY ON ONE DEVICE · 2–6 PLAYERS', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalGamesHubScreen()))),
              big('CREATE ROOM', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen()))),
              big('JOIN ROOM', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinRoomScreen()))),
              big('QUICK PLAY (coming later)', null),
              big('PROFILE (coming later)', null),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _socket.connected,
                builder: (context, online, _) => Text(
                  online ? '● Online' : '○ Offline: rooms need the game server. 1-device games work anywhere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: online ? Colors.greenAccent : Colors.white54, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: _editServer,
                icon: const Icon(Icons.dns_rounded, size: 18),
                label: Text('Server: ${AppConfig.serverUrl}', overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
