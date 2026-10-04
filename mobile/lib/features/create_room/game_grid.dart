import 'package:flutter/material.dart';
import '../../core/ui/app_ui.dart';
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';

/// Category chips plus a grid of game tiles. Games outside [playable] (when given) are
/// shown dimmed with the player count they need, and can't be picked.
class GameGrid extends StatefulWidget {
  final String? selectedId;
  final ValueChanged<GameInfo> onSelect;
  final Set<String>? playable;
  const GameGrid({super.key, required this.selectedId, required this.onSelect, this.playable});
  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid> {
  GameCategory? filter; // null = all

  @override
  Widget build(BuildContext context) {
    final shown = gameCatalog.where((g) => filter == null || g.category == filter).toList();
    return Column(children: [
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          _FilterChip(label: 'ALL', selected: filter == null, onTap: () => setState(() => filter = null)),
          for (final c in GameCategory.values) _FilterChip(label: c.label, selected: filter == c, onTap: () => setState(() => filter = c)),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.86),
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final g = shown[i];
            final fits = widget.playable == null || widget.playable!.contains(g.id);
            return GameTile(game: g, selected: g.id == widget.selectedId, enabled: fits, onTap: fits ? () => widget.onSelect(g) : null);
          },
        ),
      ),
    ]);
  }
}

/// Full-screen picker used by the room host between games. Pops with the chosen game id.
class GamePickerScreen extends StatelessWidget {
  final String? selectedId;
  final Set<String> playable;
  final int playerCount;
  const GamePickerScreen({super.key, required this.selectedId, required this.playable, required this.playerCount});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 10),
                child: Row(children: [
                  AppIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.maybePop(context)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('PICK THE NEXT GAME', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      Text('${playable.length} games fit your $playerCount players', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ),
              Expanded(child: GameGrid(selectedId: selectedId, playable: playable, onSelect: (g) => Navigator.pop(context, g.id))),
            ]),
          ),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : AppColors.glass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.gold : AppColors.stroke),
              ),
              child: Text(label, style: TextStyle(color: selected ? AppColors.night : Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1)),
            ),
          ),
        ),
      );
}

class GameTile extends StatelessWidget {
  final GameInfo game;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  const GameTile({super.key, required this.game, required this.selected, this.enabled = true, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = game.color;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: game.name,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.4)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
              boxShadow: [
                BoxShadow(color: Color.lerp(c, Colors.black, 0.6)!, offset: const Offset(0, 4)),
                if (selected) BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 16, spreadRadius: 1),
              ],
            ),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: Text('👥 ${game.playersLabel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
                Expanded(child: Center(child: FittedBox(child: Text(game.emoji, style: const TextStyle(fontSize: 44))))),
                Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, height: 1.1)),
              ]),
              if (selected)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.check_rounded, size: 18, color: AppColors.night)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
