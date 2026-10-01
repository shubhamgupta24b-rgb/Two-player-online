import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/room/room_manager.dart';
import '../../games/game_catalog.dart';
import '../lobby/lobby_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  String gameId = gameCatalog.first.id;
  int players = 2;
  bool busy = false;

  Future<void> _create() async {
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    final err = await rm.create(gameId, players);
    if (!mounted) return;
    if (err != null) {
      setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LobbyScreen()), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('SELECT GAME', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final g in gameCatalog)
          RadioListTile<String>(
            value: g.id,
            groupValue: gameId,
            onChanged: (v) => setState(() => gameId = v!),
            title: Text(g.name),
            subtitle: g.playable ? null : const Text('Not implemented yet (lobby only)'),
          ),
        const SizedBox(height: 12),
        const Text('PLAYERS', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            const ButtonSegment(value: 2, label: Text('2')),
            const ButtonSegment(value: 3, label: Text('3')),
            const ButtonSegment(value: 4, label: Text('4')),
          ],
          selected: {players},
          onSelectionChanged: (s) => setState(() => players = s.first),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: busy ? null : _create, child: const Padding(padding: EdgeInsets.all(14), child: Text('CREATE'))),
      ]),
    );
  }
}
