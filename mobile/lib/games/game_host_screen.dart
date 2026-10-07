import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/authentication_manager.dart';
import '../core/records/records.dart';
import '../core/room/room_manager.dart';
import '../core/session/game_session_manager.dart';
import '../core/ui/app_ui.dart';
import '../features/guess_person/widgets/gp_theme.dart' show GpButton, GpColors;
import 'game_catalog.dart';
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
        appBar: _RoomBar(room: room),
        body: SafeArea(child: _body(context, session, rm, myId)),
      ),
    );
  }

  Widget _body(BuildContext context, GameSessionManager session, RoomManager rm, String myId) {
    final result = session.result;
    if (room.status == 'finished' && result != null) {
      return _RecordOnce(result: result, gameType: room.gameType, myId: myId, child: _Results(result: result, room: room, myId: myId));
    }
    final screen = gameScreenFor(room.gameType);
    if (screen == null) return const Center(child: Text('This game is not available in this app version.'));
    if (session.state == null) return const Center(child: CircularProgressIndicator());
    return screen;
  }
}

/// The game's emoji and name in its colour, plus the party progress.
class _RoomBar extends StatelessWidget implements PreferredSizeWidget {
  final Room room;
  const _RoomBar({required this.room});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 3);

  @override
  Widget build(BuildContext context) {
    final game = gameCatalog.firstWhere((g) => g.id == room.gameType, orElse: () => GameInfo(room.gameType, room.gameType));
    final party = room.party;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.night,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(children: [
        Text(game.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Expanded(child: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19))),
        if (party != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
            child: Text('🎉 GAME ${party.index + 1}/${party.games.length}', style: const TextStyle(color: AppColors.night, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
      ]),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(3), child: Container(height: 3, color: game.color)),
    );
  }
}

/// Adds this phone's player's result to My Records once, when the results first show.
class _RecordOnce extends StatefulWidget {
  final Map<String, dynamic> result;
  final String gameType;
  final String myId;
  final Widget child;
  const _RecordOnce({required this.result, required this.gameType, required this.myId, required this.child});
  @override
  State<_RecordOnce> createState() => _RecordOnceState();
}

class _RecordOnceState extends State<_RecordOnce> {
  @override
  void initState() {
    super.initState();
    final mine = (widget.result['ranking'] as List?)?.cast<Map>().where((r) => r['userId'] == widget.myId).firstOrNull;
    if (mine == null) return;
    final winners = (widget.result['winners'] as List?)?.cast<String>() ?? const [];
    final ranking = (widget.result['ranking'] as List).cast<Map>();
    // A win is a game you won outright, or together with your team (not an everyone-tied draw).
    final won = winners.contains(widget.myId) && winners.length < ranking.length;
    Records.add(widget.gameType, score: (mine['score'] as num?)?.toInt() ?? 0, won: won).ignore();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final party = room.party;
    final rm = context.read<RoomManager>();
    String name(String id) => room.players.where((p) => p.userId == id).firstOrNull?.username ?? '?';

    Future<void> run(Future<String?> f) async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await f;
      if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
    }

    final List<Widget> actions;
    if (!isHost) {
      actions = [
        Text(party != null && !party.done ? 'Next up: ${gameName(party.nextGame ?? '')}. Waiting for the host…' : 'Waiting for the host to pick the next game…',
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
      ];
    } else if (party != null && !party.done) {
      actions = [
        GpButton('NEXT GAME (${party.index + 2}/${party.games.length}): ${gameName(party.nextGame!).toUpperCase()}',
            icon: Icons.skip_next_rounded, color: GpColors.accent, onPressed: () => run(rm.nextGame())),
        const SizedBox(height: 8),
        GpButton('END PARTY', outlined: true, onPressed: () => run(rm.returnToLobby())),
      ];
    } else {
      actions = [
        if (party == null) ...[
          GpButton('PLAY AGAIN', icon: Icons.replay_rounded, color: GpColors.accent, onPressed: () => run(rm.nextGame())),
          const SizedBox(height: 8),
        ],
        GpButton(party == null ? 'CHOOSE ANOTHER GAME' : 'BACK TO THE ROOM', icon: Icons.grid_view_rounded, color: AppColors.purple, textColor: Colors.white, onPressed: () => run(rm.returnToLobby())),
      ];
    }

    final partyOrder = party == null ? <String>[] : (party.totals.keys.toList()..sort((a, b) => party.totals[b]!.compareTo(party.totals[a]!)));
    return AppBackground(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            party?.done == true
                ? '🏆 ${name(partyOrder.first).toUpperCase()} WINS THE PARTY!'
                : winners.length > 1 && winners.length == ranking.length
                    ? "🤝 IT'S A DRAW!"
                    : (winners.contains(myId) ? '🎉 YOU WIN!' : 'RESULTS'),
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gold, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (final r in ranking)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: r['rank'] == 1 ? AppColors.gold.withValues(alpha: 0.18) : AppColors.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: r['rank'] == 1 ? AppColors.gold : AppColors.stroke),
            ),
            child: Row(children: [
              Text(switch (r['rank']) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '#${r['rank']}' }, style: const TextStyle(fontSize: 22, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Text('${r['username']}${r['userId'] == myId ? ' (you)' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              Text('${r['score']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              if (party?.lastPoints != null) ...[
                const SizedBox(width: 10),
                Text('+${party!.lastPoints![r['userId']] ?? 0} pts', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w900)),
              ],
            ]),
          ),
        if (party != null) ...[
          SectionTitle('PARTY STANDINGS · GAME ${party.index + 1} OF ${party.games.length}'),
          for (final id in partyOrder)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${name(id)}${id == myId ? ' (you)' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                Text('${party.totals[id]} pts', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
              ]),
            ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < party.games.length; i++)
              Chip(
                label: Text(gameName(party.games[i]), style: TextStyle(color: i <= party.index ? Colors.white : Colors.white54, fontWeight: FontWeight.w700, fontSize: 12)),
                backgroundColor: i == party.index ? AppColors.purple : AppColors.glass,
                side: BorderSide.none,
              ),
          ]),
        ],
        const SizedBox(height: 18),
        ...actions,
        const SizedBox(height: 4),
        TextButton(onPressed: rm.leave, child: const Text('Leave room', style: TextStyle(color: AppColors.muted))),
      ]),
    );
  }
}
