import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../guess_person/widgets/gp_theme.dart' show GpButton, GpColors;
import '../lobby/lobby_screen.dart';
import 'game_grid.dart';

/// Pick the first game and the room size, then create a room friends join with its code.
/// The host can switch games in the room between rounds.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  String gameId = gameCatalog.first.id;
  int players = 4;
  bool busy = false;

  GameInfo get game => gameCatalog.firstWhere((g) => g.id == gameId);

  Future<void> _create() async {
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    final err = await rm.create(gameId, players);
    if (!mounted) return;
    if (err != null) {
      setState(() => busy = false);
      messenger.hideCurrentSnackBar();
      if (mounted) showToast(context, friendlyError(err), tone: Tone.danger, duration: const Duration(seconds: 3));
      return;
    }
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LobbyScreen()), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 10),
              child: Row(children: [
                AppIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.maybePop(context)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('CREATE A ROOM', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    if (MediaQuery.sizeOf(context).height >= 700)
                      const Text('One room, any game: switch between rounds', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ]),
                ),
                Text('${gameCatalog.length} GAMES', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 12)),
              ]),
            ),
            Expanded(child: GameGrid(selectedId: gameId, onSelect: (g) => setState(() => gameId = g.id))),
            _BottomPanel(
              game: game,
              players: players,
              busy: busy,
              onPlayers: (n) => setState(() => players = n),
              onCreate: _create,
            ),
          ]),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final GameInfo game;
  final int players;
  final bool busy;
  final ValueChanged<int> onPlayers;
  final VoidCallback onCreate;
  const _BottomPanel({required this.game, required this.players, required this.busy, required this.onPlayers, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final fits = players >= game.minPlayers && players <= game.maxPlayers;
    final compact = MediaQuery.sizeOf(context).height < 700; // small phones: leave room for the games
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 14, 16, compact ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.night,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: game.color, width: 3)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(game.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
              Text(fits ? game.tagline : 'Needs ${game.playersLabel} players: you can switch games in the room',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fits ? AppColors.muted : AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        SizedBox(height: compact ? 6 : 12),
        Row(children: [
          const Text('ROOM SIZE', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12.5)),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final size = ((c.maxWidth - 4 * 6) / 5).clamp(28.0, 44.0);
              return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var n = 2; n <= 6; n++) _CountButton(n: n, size: size, selected: n == players, onTap: () => onPlayers(n)),
              ]);
            }),
          ),
        ]),
        SizedBox(height: compact ? 8 : 14),
        GpButton(busy ? 'CREATING…' : 'CREATE ROOM', icon: Icons.add_circle_rounded, color: GpColors.accent, onPressed: busy ? null : onCreate),
      ]),
    );
  }
}

class _CountButton extends StatelessWidget {
  final int n;
  final double size;
  final bool selected;
  final VoidCallback onTap;
  const _CountButton({required this.n, required this.size, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Room for $n players',
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.gold : AppColors.glass,
              border: Border.all(color: selected ? Colors.white : AppColors.stroke, width: 2),
            ),
            child: Text('$n', style: TextStyle(color: selected ? AppColors.night : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ),
      );
}
