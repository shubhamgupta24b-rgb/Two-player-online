import 'package:flutter/material.dart';
import '../shell/local_game_info.dart';
import 'uno_board.dart';

final LocalGameInfo unoInfo = LocalGameInfo(
  id: 'uno',
  title: 'UNO',
  emoji: '🃏',
  color: const Color(0xFFE53935),
  tagline: 'Match colours, numbers and action cards.',
  rules: const [
    'Each player starts with 7 cards. Match the top discard by colour, number, or action.',
    'Draw one card when you cannot play. Play it immediately if legal, otherwise pass.',
    'Skip and Reverse skip the opponent in a two-player match. Draw Two and Wild Draw Four make them draw cards and lose their turn.',
    'Wild lets you choose the active colour. Wild Draw Four is legal only when you have no card of the active colour.',
    'Call UNO when you have one card left. If you end the turn without calling, draw two penalty cards.',
    'The first player to empty their hand wins the round.',
  ],
  scoreUnit: 'cards',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  play: (players, onFinished) => UnoBoard(players: players, onFinished: onFinished),
);
