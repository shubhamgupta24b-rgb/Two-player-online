import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GameInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const GameInfoChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ClayColors.stroke)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: ClayColors.textMuted),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 12, color: ClayColors.text)),
      ]),
    );
  }
}
