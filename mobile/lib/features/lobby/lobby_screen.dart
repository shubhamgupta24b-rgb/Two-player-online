import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../../games/game_host_screen.dart';
import '../create_room/game_grid.dart';
import '../guess_person/models/gp_player.dart' show gpPlayerColors;
import '../guess_person/widgets/gp_theme.dart' show GpButton;

/// The room between games: the code to share, who's in, which game is next.
/// The host picks the game (or a party of random games) and starts.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rm = context.watch<RoomManager>();
    final socket = context.read<SocketManager>();
    final room = rm.room;
    final t = context.tk;

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
    final host = room.players.where((p) => p.userId == room.hostId).firstOrNull;
    final game = gameCatalog.firstWhere((g) => g.id == room.gameType, orElse: () => GameInfo(room.gameType, gameName(room.gameType)));
    final n = room.players.length;
    final fits = n >= game.minPlayers && n <= game.maxPlayers;
    final away = room.players.where((p) => !p.connected).toList();

    Future<void> run(Future<String?> f) async {
      final err = await f;
      if (err != null && context.mounted) showToast(context, friendlyError(err), tone: Tone.danger, duration: const Duration(seconds: 3));
    }

    Future<void> pick() async {
      final id = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => GamePickerScreen(selectedId: room.gameType, playable: room.playable, playerCount: n)),
      );
      if (id != null) await run(rm.selectGame(id));
    }

    Future<void> leave() async {
      if (await confirmAction(context, title: 'Leave the room?', message: 'Your friends can carry on without you.', confirm: 'LEAVE', cancel: 'STAY', emoji: '🚪')) {
        await rm.leave();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await leave();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.xs, 0),
                child: Row(children: [
                  Expanded(child: Semantics(header: true, child: Text('GAME ROOM', style: t.styles.title.copyWith(letterSpacing: 1.5)))),
                  AppIconButton(icon: Icons.tune_rounded, tooltip: 'Settings', onPressed: () => showSettingsSheet(context)),
                  TextButton.icon(
                    onPressed: leave,
                    style: TextButton.styleFrom(minimumSize: const Size(kTouchTarget, kTouchTarget)),
                    icon: Icon(Icons.logout_rounded, color: t.danger, size: 18),
                    label: Text('LEAVE', style: TextStyle(color: t.danger, fontWeight: FontWeight.w900)),
                  ),
                ]),
              ),
              // Non-blocking states: our connection, and anyone who dropped out.
              ValueListenableBuilder<bool>(
                valueListenable: socket.connected,
                builder: (_, on, __) => AnimatedSize(
                  duration: Motion.of(context, Motion.normal),
                  child: on
                      ? const SizedBox(width: double.infinity)
                      : const Padding(
                          padding: EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 0),
                          child: AppBanner(text: 'Connection lost · reconnecting…', tone: Tone.warn),
                        ),
                ),
              ),
              if (away.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 0),
                  child: AppBanner(
                    tone: Tone.info,
                    text: host != null && !host.connected && !isHost
                        ? 'The host ${host.username} is offline. Waiting for them to come back…'
                        : '${away.map((p) => p.username).join(', ')} ${away.length == 1 ? 'is' : 'are'} offline. Waiting for them…',
                  ),
                ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.l), children: [
                  _CodeCard(code: room.code, quickPlay: room.isPublic),
                  const SizedBox(height: Space.m),
                  _GameCard(game: game, fits: fits, playerCount: n, isHost: isHost, onChange: pick),
                  SectionTitle('PLAYERS · $n / ${room.maxPlayers}'),
                  for (var i = 0; i < room.players.length; i++)
                    _PlayerRow(player: room.players[i], seat: i, color: gpPlayerColors[i % gpPlayerColors.length], isHost: room.players[i].userId == room.hostId, isMe: room.players[i].userId == myId),
                  for (var i = room.players.length; i < room.maxPlayers; i++) const _EmptySeat(),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.l),
                decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26)), boxShadow: t.shadowLg, border: Border(top: BorderSide(color: t.stroke))),
                child: isHost
                    ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (!room.allReady)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.s),
                            child: Text('Waiting for everyone to join and tap READY…', textAlign: TextAlign.center, style: t.styles.bodyStrong.copyWith(color: t.onBgMuted)),
                          ),
                        GpButton('START ${game.name.toUpperCase()}', icon: Icons.play_arrow_rounded, onPressed: room.allReady && fits ? () => run(rm.start()) : null),
                        const SizedBox(height: Space.s),
                        GpButton('🎲 PARTY MODE · 5 RANDOM GAMES', color: AppColors.purple, textColor: Colors.white, onPressed: room.allReady ? () => run(rm.startParty(5)) : null),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s),
                          child: Text('The host picks the games. Get ready!', textAlign: TextAlign.center, style: t.styles.bodyStrong.copyWith(color: t.onBgMuted)),
                        ),
                        GpButton(
                          me?.ready == true ? "I'M READY ✓ (TAP TO UNDO)" : "I'M READY",
                          icon: me?.ready == true ? null : Icons.check_circle_rounded,
                          color: me?.ready == true ? t.success : AppColors.gold,
                          textColor: me?.ready == true ? Colors.white : Brand.ink,
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.blue, AppColors.purple], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: Radii.rXl,
          border: Border.all(color: Colors.white24),
          boxShadow: context.tk.shadowMd,
        ),
        child: Column(children: [
          if (quickPlay) ...[
            const Text('⚡ QUICK PLAY ROOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 15)),
            const SizedBox(height: 2),
            const Text('Open to everyone: new players are matched in automatically', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
            const SizedBox(height: Space.s),
          ],
          const Text('ROOM CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12.5)),
          const SizedBox(height: Space.s),
          RoomCodeDisplay(code, size: quickPlay ? 30 : 40),
          const SizedBox(height: Space.s),
          const Text('Friends tap JOIN ROOM and enter this code', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
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
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [fillFor(game.color), Color.lerp(game.color, Colors.black, 0.55)!]),
          borderRadius: Radii.rXl,
          border: Border.all(color: Colors.white24),
        ),
        child: Row(children: [
          ExcludeSemantics(child: Text(game.emoji, style: const TextStyle(fontSize: 40))),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NEXT GAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 1.5)),
              Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.1)),
              Text(fits ? '👥 ${game.playersLabel} players' : '⚠ Needs ${game.playersLabel} players · you have $playerCount',
                  style: TextStyle(color: fits ? Colors.white : const Color(0xFFFFE066), fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
          if (isHost) AppButton('CHANGE', compact: true, variant: ButtonVariant.secondary, onPressed: onChange),
        ]),
      );
}

class _PlayerRow extends StatelessWidget {
  final RoomPlayer player;
  final int seat;
  final Color color;
  final bool isHost, isMe;
  const _PlayerRow({required this.player, required this.seat, required this.color, required this.isHost, required this.isMe});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final (String status, IconData icon, Color statusColor) = !player.connected
        ? ('OFFLINE', Icons.wifi_off_rounded, t.warn)
        : (player.ready ? ('READY', Icons.check_circle_rounded, t.success) : ('NOT READY', Icons.hourglass_top_rounded, t.onBgMuted));
    return Semantics(
      label: '${player.username}${isMe ? ', you' : ''}${isHost ? ', host' : ''}, ${status.toLowerCase()}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.s),
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
        decoration: BoxDecoration(color: t.glass, borderRadius: Radii.rLg, border: Border.all(color: isMe ? color : t.stroke, width: isMe ? 2 : 1)),
        child: Row(children: [
          Opacity(opacity: player.connected ? 1 : 0.5, child: PlayerAvatar(name: player.username.isEmpty ? '?' : player.username, color: color, seat: seat, size: 40)),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text('${player.username}${isMe ? ' (you)' : ''}${isHost ? ' 👑' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.styles.bodyStrong),
          ),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.normal),
            child: Container(
              key: ValueKey(status),
              padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: statusColor)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: statusColor, size: 15),
                const SizedBox(width: 4),
                Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(borderRadius: Radii.rLg, border: Border.all(color: t.stroke)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.glass, border: Border.all(color: t.stroke)),
          child: Icon(Icons.person_add_alt_1_rounded, color: t.onBgMuted, size: 20),
        ),
        const SizedBox(width: Space.m),
        Expanded(child: Text('Waiting for a player…', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.styles.bodyStrong.copyWith(color: t.onBgMuted))),
      ]),
    );
  }
}
