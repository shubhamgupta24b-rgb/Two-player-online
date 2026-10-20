import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class ClayDecoration {
  static List<BoxShadow> get softShadow => const [
        BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 8)),
        BoxShadow(color: Color(0x66FFFFFF), blurRadius: 10, offset: Offset(-4, -4)),
      ];

  static BoxDecoration surface({double radius = 24, Color color = ClayColors.surface}) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ClayColors.stroke),
        boxShadow: softShadow,
      );
}
