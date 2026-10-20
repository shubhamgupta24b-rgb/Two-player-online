import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class ClayTypography {
  static const title = TextStyle(fontFamily: 'Lilita One', fontSize: 28, height: 1.05, color: ClayColors.text);
  static const section = TextStyle(fontFamily: 'Lilita One', fontSize: 20, height: 1.1, color: ClayColors.text);
  static const cardTitle = TextStyle(fontFamily: 'Lilita One', fontSize: 18, height: 1.1, color: ClayColors.text);
  static const body = TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: ClayColors.text);
  static const bodyMuted = TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: ClayColors.textMuted);
  static const button = TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white);
}
