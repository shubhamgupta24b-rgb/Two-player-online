import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const CategoryChip({super.key, required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label, style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: selected ? ClayColors.text : ClayColors.textMuted)),
        side: const BorderSide(color: ClayColors.stroke),
        selectedColor: color,
        backgroundColor: Colors.white,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
