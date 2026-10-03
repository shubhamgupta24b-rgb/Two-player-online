import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/authentication_manager.dart';
import '../../../core/network/socket_manager.dart';
import '../../../core/room/room_manager.dart';
import '../../../games/game_catalog.dart';
import '../../../games/game_host_screen.dart';
import '../widgets/mp_ui.dart';

class MpLobbyScreen extends StatelessWidget {
  const MpLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rm = context.watch<RoomManager>();
    final socket = context.read<SocketManager>();
    final room = rm.room;

    if (room == null) {
      // Left the room or the seat expired: close the lobby.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop(); // pop() ignores PopScope, unlike maybePop()
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    // Game started: hand over to the existing game host.
    if (room.status != 'lobby') return GameHostScreen(room: room);

    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final isHost = room.hostId == myId;
    final me = room.players.where((p) => p.userId == myId).firstOrNull;
    final readyCount = room.players.where((p) => p.ready).length;

    Future<void> run(Future<String?> f) async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await f;
      if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
    }

    void copyCode() {
      Clipboard.setData(ClipboardData(text: room.code));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room code copied')));
    }

    return Theme(
      data: buildMpTheme(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) await rm.leave();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(gameName(room.gameType), style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              TextButton.icon(
                onPressed: rm.leave,
                icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFFF6B81)),
                label: const Text('Leave', style: TextStyle(color: Color(0xFFFF6B81))),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              ValueListenableBuilder<bool>(
                valueListenable: socket.connected,
                builder: (_, on, __) => on
                    ? const SizedBox.shrink()
                    : Container(
                        width: double.infinity,
                        color: AppColors.warning.withValues(alpha: 0.2),
                        padding: const EdgeInsets.all(8),
                        child: const Text('Connection lost — reconnecting…',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.warning)),
                      ),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), children: [
                  // Room code card
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: copyCode,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(children: [
                          const Text('ROOM CODE',
                              style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(room.code,
                              style: const TextStyle(fontSize: 40, letterSpacing: 8, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.copy_rounded, size: 14, color: AppColors.accent),
                            SizedBox(width: 4),
                            Text('Tap to copy & share', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: SectionLabel('Players')),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('$readyCount/${room.players.length} ready · ${room.players.length}/${room.maxPlayers}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ),
                  ]),
                  for (final p in room.players) ...[
                    _PlayerRow(
                      name: p.username,
                      color: AppColors.forId(p.userId),
                      isMe: p.userId == myId,
                      isHost: p.userId == room.hostId,
                      ready: p.ready,
                      connected: p.connected,
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (var i = room.players.length; i < room.maxPlayers; i++) ...[
                    const _EmptySeat(),
                    const SizedBox(height: 10),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(children: [
                  if (isHost && !room.allReady)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Waiting for everyone to be ready…', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ),
                  isHost
                      ? FilledButton(
                          onPressed: room.allReady ? () => run(rm.start()) : null,
                          child: const Text('START GAME'),
                        )
                      : FilledButton(
                          style: me?.ready == true
                              ? FilledButton.styleFrom(backgroundColor: AppColors.surfaceHigh)
                              : FilledButton.styleFrom(backgroundColor: AppColors.success),
                          onPressed: () => run(rm.setReady(!(me?.ready ?? false))),
                          child: Text(me?.ready == true ? 'NOT READY' : "I'M READY"),
                        ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String name;
  final Color color;
  final bool isMe, isHost, ready, connected;
  const _PlayerRow({
    required this.name,
    required this.color,
    required this.isMe,
    required this.isHost,
    required this.ready,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? color.withValues(alpha: 0.6) : Colors.transparent, width: 2),
      ),
      child: Row(children: [
        Opacity(opacity: connected ? 1 : 0.4, child: PlayerAvatar(name: name, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name${isMe ? ' (you)' : ''}',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (isHost || !connected) ...[
              const SizedBox(height: 4),
              Row(children: [
                if (isHost) const StatusPill('HOST', color: Color(0xFFFFC048), icon: Icons.star_rounded),
                if (isHost && !connected) const SizedBox(width: 6),
                if (!connected) const StatusPill('OFFLINE', color: AppColors.warning, icon: Icons.wifi_off_rounded),
              ]),
            ],
          ]),
        ),
        ready
            ? const StatusPill('READY', color: AppColors.success, icon: Icons.check_rounded)
            : const StatusPill('WAITING', color: AppColors.muted),
      ]),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceHigh, width: 2),
        ),
        child: const Row(children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.muted),
          ),
          SizedBox(width: 12),
          Text('Waiting for a player…', style: TextStyle(color: AppColors.muted)),
        ]),
      );
}
