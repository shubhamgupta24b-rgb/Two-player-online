import 'package:flutter/material.dart';
import '../features/local_games/shell/game_art.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'clay_card.dart';

class ClayGameCard extends StatelessWidget {
  final String id;
  final String title;
  final Color color;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  const ClayGameCard({super.key, required this.id, required this.title, required this.color, required this.favorite, required this.onTap, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(0),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: CustomPaint(painter: GameArtPainter(id, color)),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                    onPressed: onFavorite,
                    icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded, color: favorite ? Colors.pink.shade300 : Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ClayTypography.cardTitle.copyWith(fontSize: 16, color: ClayColors.text)),
          ),
        ],
      ),
    );
  }
}
