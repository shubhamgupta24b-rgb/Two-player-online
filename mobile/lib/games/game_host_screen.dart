import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/authentication_manager.dart';
import '../core/room/room_manager.dart';
import '../core/session/game_session_manager.dart';
import 'game_module.dart';

/// Shown by the lobby while the room is playing or finished. Hosts the game screen and the shared results screen.
class GameHostScreen extends StatelessWidget {
  final Room room;
  const GameHostScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final rm = context.read<RoomManager>();
    final myId = context.read<AuthenticationManager>().token.split(':')[1];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Leave game?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true) await rm.leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Game'), automaticallyImplyLeading: false),
        body: SafeArea(child: _body(context, session, rm, myId)),
      ),
    );
  }

  Widget _body(BuildContext context, GameSessionManager session, RoomManager rm, String myId) {
    final result = session.result;
    if (room.status == 'finished' && result != null) return _Results(result: result, room: room, myId: myId);
    final screen = gameScreenFor(room.gameType);
    if (screen == null) return const Center(child: Text('This game is not available in this app version.'));
    if (session.state == null) return const Center(child: CircularProgressIndicator());
    return screen;
  }
}

class _Results extends StatelessWidget {
  final Map<String, dynamic> result;
  final Room room;
  final String myId;
  const _Results({required this.result, required this.room, required this.myId});

  @override
  Widget build(BuildContext context) {
    final ranking = (result['ranking'] as List).cast<Map>();
    final winners = (result['winners'] as List).cast<String>();
    final isHost = room.hostId == myId;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(winners.contains(myId) ? 'YOU WIN!' : 'FINAL SCORES',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(children: [
            for (final r in ranking)
              ListTile(
                leading: CircleAvatar(child: Text('${r['rank']}')),
                title: Text('${r['username']}${r['userId'] == myId ? ' (you)' : ''}'),
                trailing: Text('${r['score']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
        if (isHost)
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final err = await context.read<RoomManager>().returnToLobby();
              if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
            },
            child: const Padding(padding: EdgeInsets.all(14), child: Text('BACK TO LOBBY')),
          )
        else
          const Text('Waiting for the host to return to the lobby...', textAlign: TextAlign.center),
        TextButton(onPressed: () => context.read<RoomManager>().leave(), child: const Text('Leave room')),
      ]),
    );
  }
}
