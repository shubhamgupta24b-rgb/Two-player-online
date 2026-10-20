import 'package:flutter/material.dart';
import '../../core/records/records.dart';
import '../../features/local_games/shell/game_art.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/clay_button.dart';
import '../../widgets/clay_card.dart';
import '../../widgets/game_info_chip.dart';
import '../../widgets/pastel_background.dart';
import 'game_mode_screen.dart';
import 'home_games.dart';

class GameDetailsScreen extends StatefulWidget {
  final HomeGame game;
  const GameDetailsScreen({super.key, required this.game});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  late bool _favorite;

  @override
  void initState() {
    super.initState();
    _favorite = false;
    _load();
  }

  Future<void> _load() async {
    final favs = await Records.favourites();
    if (mounted) setState(() => _favorite = favs.contains(widget.game.id));
  }

  Future<void> _toggleFavorite() async {
    final favs = await Records.toggleFavourite(widget.game.id);
    if (mounted) setState(() => _favorite = favs.contains(widget.game.id));
  }

  void _showRules() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('${widget.game.title} Rules', style: ClayTypography.section.copyWith(fontSize: 22)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.game.rules.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('${i + 1}. ${widget.game.rules[i]}', style: ClayTypography.body),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageHeight = constraints.maxHeight < 700 ? 180.0 : 220.0;
              return SingleChildScrollView(
                padding: ClaySpacing.page,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: ClayColors.text),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: _favorite ? 'Remove favorite' : 'Add favorite',
                          onPressed: _toggleFavorite,
                          icon: Icon(_favorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded, color: Colors.pink.shade300),
                        ),
                      ],
                    ),
                    ClayCard(
                      padding: const EdgeInsets.all(0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(height: imageHeight, child: CustomPaint(painter: GameArtPainter(game.id, game.color))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(game.title, style: ClayTypography.title),
                    const SizedBox(height: 6),
                    Text(game.subtitle, style: ClayTypography.bodyMuted),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GameInfoChip(icon: Icons.people_alt_rounded, text: game.playersLabel),
                        GameInfoChip(icon: Icons.schedule_rounded, text: game.duration),
                        GameInfoChip(icon: Icons.auto_graph_rounded, text: game.difficulty),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClayCard(
                      child: Text(game.rules.isEmpty ? 'No rules available yet.' : game.rules.first, style: ClayTypography.body),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showRules,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(color: ClayColors.stroke),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              backgroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.menu_book_rounded, color: ClayColors.text),
                            label: Text('Rules', style: ClayTypography.body),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClayButton(
                            'Play',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameModeScreen(game: game))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
