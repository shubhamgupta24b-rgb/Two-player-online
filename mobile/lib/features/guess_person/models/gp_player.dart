import 'package:flutter/material.dart';

class GpPlayer {
  final String name;
  final Color color;
  int score;
  GpPlayer({required this.name, required this.color, this.score = 0});
}

/// Defaults for up to 6 players: blue, red, green, yellow, purple, orange.
const gpPlayerColors = [
  Color(0xFF4D96FF),
  Color(0xFFFF6B6B),
  Color(0xFF2ECC71),
  Color(0xFFE0A800),
  Color(0xFFA855F7),
  Color(0xFFFF8A3D),
];

List<GpPlayer> defaultPlayers([int count = 2]) =>
    [for (var i = 0; i < count; i++) GpPlayer(name: 'Player ${i + 1}', color: gpPlayerColors[i % gpPlayerColors.length])];
