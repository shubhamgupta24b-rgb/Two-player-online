import 'package:flutter/material.dart';

class GpPlayer {
  final String name;
  final Color color;
  int score;
  GpPlayer({required this.name, required this.color, this.score = 0});
}

/// Defaults for up to 4 players (the current mode uses the first 2).
const gpPlayerColors = [Color(0xFF4D96FF), Color(0xFFFF6B6B), Color(0xFF2ECC71), Color(0xFFFFC93C)];

List<GpPlayer> defaultPlayers([int count = 2]) =>
    [for (var i = 0; i < count; i++) GpPlayer(name: 'Player ${i + 1}', color: gpPlayerColors[i % gpPlayerColors.length])];
