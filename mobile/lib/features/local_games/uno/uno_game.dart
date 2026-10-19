import 'package:flutter/material.dart';

import 'colour_clash/colour_clash_game.dart' show colourClashInfo;
import 'shell/local_game_info.dart';

/// UNO entry point. Reuses the existing card-duel engine and relay adapter so the
/// local and online variants share a single authoritative rules/state implementation.
/// The visual layer can evolve independently without duplicating multiplayer logic.
final unoInfo = LocalGameInfo(
  id: 'uno',
  title: 'UNO',
  emoji: '🃏',
  color: const Color(0xFF3478F6),
  tagline: 'Match colours, numbers and action cards',
  rules: const [
    'Deal seven cards to each player. Match the discard by colour, number, or symbol.',
    'If you cannot play, draw one card. A newly drawn playable card may be played.',
    'Skip skips the opponent. In a two-player game, Reverse also skips the opponent.',
    'Draw Two makes the opponent draw two cards and lose their turn.',
    'Wild lets you choose the next colour. Wild Draw Four is only legal when you have no card matching the current colour.',
    'Call UNO when you play down to one card. If caught before the opponent starts their turn, draw two penalty cards.',
    'The first player to empty their hand wins the round.',
    'Classic cumulative scoring: number cards are face value, Skip/Reverse/Draw Two are 20 points, and Wild/Wild Draw Four are 50 points. First to 500 wins.',
  ],
  scoreUnit: 'cards',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  play: colourClashInfo.play,
  bot: colourClashInfo.bot,
  online: colourClashInfo.online,
);
