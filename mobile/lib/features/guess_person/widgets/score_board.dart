import 'package:flutter/material.dart';
import '../models/gp_player.dart';
import 'gp_theme.dart';

class ScoreBoard extends StatelessWidget {
  final List<GpPlayer> players;
  final bool large;
  final Set<GpPlayer> highlight;
  const ScoreBoard({super.key, required this.players, this.large = false, this.highlight = const {}});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final p in players)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: EdgeInsets.symmetric(vertical: large ? 18 : 10),
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: highlight.contains(p) ? GpColors.accent : p.color, width: highlight.contains(p) ? 3 : 2),
            ),
            child: Column(children: [
              Text(p.name.toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: large ? 16 : 13)),
              Text('${p.score}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: large ? 48 : 26, height: 1.1)),
              Text(p.score == 1 ? 'point' : 'points', style: const TextStyle(color: GpColors.muted, fontSize: 12)),
            ]),
          ),
        ),
    ]);
  }
}
