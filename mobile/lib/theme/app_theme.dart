import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildClayTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ClayColors.primary, brightness: Brightness.light).copyWith(
    primary: ClayColors.primary,
    onPrimary: Colors.white,
    surface: ClayColors.surface,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: ClayColors.backgroundMid,
    fontFamily: 'Nunito',
  );
}
