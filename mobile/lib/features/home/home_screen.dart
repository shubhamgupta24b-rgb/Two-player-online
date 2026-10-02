import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/room/room_manager.dart';
import '../create_room/create_room_screen.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // If the server still has us in a room (e.g. app restarted), jump back in.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rm = context.read<RoomManager>();
      final nav = Navigator.of(context);
      await rm.resync();
      if (rm.room != null && mounted) nav.push(MaterialPageRoute(builder: (_) => const LobbyScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget big(String t, VoidCallback? f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FilledButton(onPressed: f, child: Padding(padding: const EdgeInsets.all(16), child: Text(t))));
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('PARTY GAMES', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 32),
            big('GUESS THE PERSON · 2P ON ONE DEVICE', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuessPersonMenuScreen()))),
            big('CREATE ROOM', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen()))),
            big('JOIN ROOM', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinRoomScreen()))),
            big('QUICK PLAY (coming later)', null),
            big('PROFILE (coming later)', null),
          ]),
        ),
      ),
    );
  }
}
