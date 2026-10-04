import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../games/game_catalog.dart';
import '../create_room/game_grid.dart';
import '../guess_person/widgets/gp_theme.dart' show GpButton, GpColors;
import '../lobby/lobby_screen.dart';

/// Quick Play: be matched into a random open room with other players, for any game or one
/// you pick. If nobody is waiting, a new open room starts and the next quick players join it.
class QuickPlayScreen extends StatefulWidget {
  const QuickPlayScreen({super.key});
  @override
  State<QuickPlayScreen> createState() => _QuickPlayScreenState();
}

class _QuickPlayScreenState extends State<QuickPlayScreen> {
  String? gameId; // null: any game
  bool busy = false;

  Future<void> _go() async {
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    final err = await rm.quickPlay(gameId);
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
    final game = gameId == null ? null : gameCatalog.firstWhere((g) => g.id == gameId);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 6),
              child: Row(children: [
                IconButton(tooltip: 'Back', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70)),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('⚡ QUICK PLAY', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text('Join a random open room and play with anyone', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: PressableCard(
                semanticLabel: 'Any game',
                colors: gameId == null ? const [Color(0xFFFFC93C), Color(0xFFFF8A3D)] : const [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
                onTap: () => setState(() => gameId = null),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  const Text('🎲', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ANY GAME', style: TextStyle(color: gameId == null ? AppColors.night : Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('Fastest match: the room\'s host picks the games',
                          style: TextStyle(color: gameId == null ? AppColors.night.withValues(alpha: 0.75) : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                  if (gameId == null) const Icon(Icons.check_circle_rounded, color: AppColors.night),
                ]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 4),
              child: Text('OR PICK A GAME', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 12.5)),
            ),
            Expanded(child: GameGrid(selectedId: gameId, onSelect: (g) => setState(() => gameId = g.id))),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.night,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(game == null ? '🎲 Any game · rooms of up to 6' : '${game.emoji} ${game.name} · ${game.playersLabel} players',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 10),
                GpButton(busy ? 'FINDING PLAYERS…' : 'FIND A ROOM', icon: Icons.bolt_rounded, color: GpColors.accent, onPressed: busy ? null : _go),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
