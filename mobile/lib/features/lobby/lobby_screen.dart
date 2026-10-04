import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../games/game_catalog.dart';
import '../../games/game_host_screen.dart';
import '../create_room/game_grid.dart';
import '../guess_person/models/gp_player.dart' show gpPlayerColors;
import '../guess_person/widgets/gp_theme.dart' show GpButton, GpColors;

/// The room between games: the code to share, who's in, which game is next.
/// The host picks the game (or a party of random games) and starts.
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
    final game = gameCatalog.firstWhere((g) => g.id == room.gameType, orElse: () => GameInfo(room.gameType, gameName(room.gameType)));
    final n = room.players.length;
    final fits = n >= game.minPlayers && n <= game.maxPlayers;

    Future<void> run(Future<String?> f) async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await f;
      if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
    }

    Future<void> pick() async {
      final id = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => GamePickerScreen(selectedId: room.gameType, playable: room.playable, playerCount: n)),
      );
      if (id != null) await run(rm.selectGame(id));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await rm.leave();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(children: [
              ValueListenableBuilder<bool>(
                valueListenable: socket.connected,
                builder: (_, on, __) => on
                    ? const SizedBox.shrink()
                    : Container(
                        width: double.infinity,
                        color: Colors.orange.shade800,
                        padding: const EdgeInsets.all(8),
                        child: const Text('Connection lost, reconnecting...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(children: [
                  const Expanded(child: Text('GAME ROOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5))),
                  TextButton.icon(
                    onPressed: rm.leave,
                    icon: const Icon(Icons.logout_rounded, color: AppColors.red, size: 18),
                    label: const Text('LEAVE', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                  _CodeCard(code: room.code, quickPlay: room.isPublic),
                  const SizedBox(height: 14),
                  _GameCard(game: game, fits: fits, playerCount: n, isHost: isHost, onChange: pick),
                  SectionTitle('PLAYERS · $n / ${room.maxPlayers}'),
                  for (var i = 0; i < room.players.length; i++)
                    _PlayerRow(player: room.players[i], color: gpPlayerColors[i % gpPlayerColors.length], isHost: room.players[i].userId == room.hostId, isMe: room.players[i].userId == myId),
                  for (var i = room.players.length; i < room.maxPlayers; i++) const _EmptySeat(),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: AppColors.night,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
                ),
                child: isHost
                    ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (!room.allReady)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text('Waiting for everyone to join and tap READY…', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                          ),
                        GpButton('START ${game.name.toUpperCase()}', icon: Icons.play_arrow_rounded, color: GpColors.accent, onPressed: room.allReady && fits ? () => run(rm.start()) : null),
                        const SizedBox(height: 10),
                        GpButton('🎲 PARTY MODE · 5 RANDOM GAMES', color: AppColors.purple, textColor: Colors.white, onPressed: room.allReady ? () => run(rm.startParty(5)) : null),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('The host picks the games. Get ready!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                        ),
                        GpButton(
                          me?.ready == true ? "I'M READY ✓ (TAP TO UNDO)" : "I'M READY",
                          icon: me?.ready == true ? null : Icons.check_circle_rounded,
                          color: me?.ready == true ? GpColors.yes : GpColors.accent,
                          textColor: me?.ready == true ? Colors.white : GpColors.ink,
                          onPressed: () => run(rm.setReady(!(me?.ready ?? false))),
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

class _CodeCard extends StatelessWidget {
  final String code;
  final bool quickPlay; // an open room: players are matched in, no code needed
  const _CodeCard({required this.code, this.quickPlay = false});
  @override
  Widget build(BuildContext context) => PressableCard(
        semanticLabel: 'Room code $code. Tap to copy',
        colors: const [AppColors.blue, AppColors.purple],
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
        },
        child: Column(children: [
          if (quickPlay) ...[
            const Text('⚡ QUICK PLAY ROOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 15)),
            const SizedBox(height: 2),
            const Text('Open to everyone: new players are matched in automatically', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
          ],
          const Text('ROOM CODE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
          FittedBox(child: Text(code, style: TextStyle(color: Colors.white, fontSize: quickPlay ? 30 : 44, fontWeight: FontWeight.w900, letterSpacing: 8))),
          const Text('Friends tap JOIN ROOM and enter this code · tap to copy', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );
}

class _GameCard extends StatelessWidget {
  final GameInfo game;
  final bool fits;
  final int playerCount;
  final bool isHost;
  final VoidCallback onChange;
  const _GameCard({required this.game, required this.fits, required this.playerCount, required this.isHost, required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [game.color, Color.lerp(game.color, Colors.black, 0.45)!]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(children: [
          Text(game.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NEXT GAME', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
              Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.1)),
              Text(fits ? '👥 ${game.playersLabel} players' : '⚠ Needs ${game.playersLabel} players · you have $playerCount',
                  style: TextStyle(color: fits ? Colors.white70 : const Color(0xFFFFE066), fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
          if (isHost)
            FilledButton.tonal(
              onPressed: onChange,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.night),
              child: const Text('CHANGE', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ]),
      );
}

class _PlayerRow extends StatelessWidget {
  final RoomPlayer player;
  final Color color;
  final bool isHost, isMe;
  const _PlayerRow({required this.player, required this.color, required this.isHost, required this.isMe});
  @override
  Widget build(BuildContext context) {
    final status = !player.connected ? 'OFFLINE' : (player.ready ? 'READY' : 'NOT READY');
    final statusColor = !player.connected ? Colors.orange : (player.ready ? AppColors.green : Colors.white38);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(18), border: Border.all(color: isMe ? color : AppColors.stroke, width: isMe ? 2 : 1)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: color,
          child: Text(player.username.isEmpty ? '?' : player.username.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('${player.username}${isMe ? ' (you)' : ''}${isHost ? ' 👑' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12)),
      ]),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.stroke)),
        child: const Row(children: [
          CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person_outline_rounded, color: Colors.white38)),
          SizedBox(width: 12),
          Text('Waiting for a player…', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w700)),
        ]),
      );
}
