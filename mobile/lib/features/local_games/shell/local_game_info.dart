import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';

typedef PlayBuilder = Widget Function(List<GpPlayer> players, void Function(List<int> scores) onFinished);

/// Everything the shared shell needs to present one game.
class LocalGameInfo {
  final String id;
  final String title;
  final String emoji;
  final Color color;
  final String tagline;
  final List<String> rules;
  final String scoreUnit; // "taps", "points", "pairs", "cells"
  final bool splitScreen; // players sit at opposite ends of the phone
  final int maxPlayers; // 2-6; the intro screen lets players pick how many
  final PlayBuilder play;
  const LocalGameInfo({
    this.maxPlayers = 2,
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.tagline,
    required this.rules,
    required this.scoreUnit,
    required this.splitScreen,
    required this.play,
  });
}
