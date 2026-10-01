import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../games/game_catalog.dart';
import '../../games/game_host_screen.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rm = context.watch<RoomManager>();
    final socket = context.read<SocketManager>();
    final room = rm.room;

    if (room == null) {
      // Room is gone (left, or seat expired while offline): go back home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (room.status != 'lobby') return GameHostScreen(room: room);

    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final isHost = room.hostId == myId;
    final me = room.players.where((p) => p.userId == myId).firstOrNull;
    final theme = Theme.of(context);

    Future<void> run(Future<String?> f) async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await f;
      if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await rm.leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(gameName(room.gameType)),
          automaticallyImplyLeading: false,
          actions: [TextButton(onPressed: rm.leave, child: const Text('Leave'))],
        ),
        body: Column(children: [
          ValueListenableBuilder<bool>(
            valueListenable: socket.connected,
            builder: (_, on, __) => on ? const SizedBox.shrink() : Container(
              width: double.infinity, color: Colors.orange.shade800, padding: const EdgeInsets.all(8),
              child: const Text('Connection lost, reconnecting...', textAlign: TextAlign.center)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('ROOM CODE'),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: room.code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                },
                child: Text(room.code, style: theme.textTheme.displayMedium?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w900)),
              ),
              Text('${room.players.length} / ${room.maxPlayers} players'),
            ]),
          ),
          Expanded(
            child: ListView(children: [
              for (final p in room.players)
                ListTile(
                  leading: CircleAvatar(child: Text(p.username.isEmpty ? '?' : p.username[0].toUpperCase())),
                  title: Text('${p.username}${p.userId == myId ? ' (you)' : ''}'),
                  subtitle: Text(!p.connected ? 'DISCONNECTED' : p.userId == room.hostId ? 'HOST' : ''),
                  trailing: Text(p.ready ? 'READY' : 'WAITING',
                      style: TextStyle(color: p.ready ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold)),
                ),
              for (var i = room.players.length; i < room.maxPlayers; i++)
                const ListTile(leading: CircleAvatar(child: Icon(Icons.person_outline)), title: Text('Waiting for player...')),
            ]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: isHost
                    ? FilledButton(
                        onPressed: room.allReady ? () => run(rm.start()) : null,
                        child: const Padding(padding: EdgeInsets.all(14), child: Text('START GAME')))
                    : FilledButton(
                        onPressed: () => run(rm.setReady(!(me?.ready ?? false))),
                        child: Padding(padding: const EdgeInsets.all(14), child: Text(me?.ready == true ? 'UNREADY' : 'READY'))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
