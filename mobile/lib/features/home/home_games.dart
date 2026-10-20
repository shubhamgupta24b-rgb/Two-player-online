import 'package:flutter/material.dart';
import '../../features/guess_person/screens/guess_person_menu_screen.dart';
import '../../features/local_games/local_games_hub_screen.dart' show localGames;
import '../../features/local_games/shell/local_game_info.dart';
import '../../features/local_games/shell/local_game_shell.dart';
import '../../features/raja_mantri/rmcs_screen.dart';
import '../../games/game_catalog.dart';

enum HomeGameCategory { board, card, arcade, sports }

class HomeGame {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final int minPlayers;
  final int maxPlayers;
  final HomeGameCategory category;
  final String duration;
  final String difficulty;
  final List<String> rules;
  final bool onlineSupported;

  const HomeGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.minPlayers,
    required this.maxPlayers,
    required this.category,
    required this.duration,
    required this.difficulty,
    required this.rules,
    required this.onlineSupported,
  });

  String get playersLabel => minPlayers == maxPlayers ? '$maxPlayers players' : '$minPlayers-$maxPlayers players';
}

const _sportsIds = {
  'air_hockey',
  'ping_pong',
  'mini_golf',
  'basketball_hoops',
  'darts',
  'carrom',
  'eight_ball_pool',
  'hand_cricket',
  'penalty',
};

const _arcadeIds = {
  'fruit_cut',
  'smash_karts',
  'snake_duel',
  'reaction_tap',
  'math_duel',
  'fruit_duel',
  'crush_it',
  'shooting_gallery',
  'slingshot',
  'archery',
  'colour_clash',
};

const _guessRules = [
  'Pick one secret person each round.',
  'Ask only yes/no questions to narrow down choices.',
  'Eliminate people based on answers until one remains.',
  'Guess correctly before your opponent to win.',
];

const _rmcsRules = [
  'Four roles are shuffled: Raja, Mantri, Chor, Sipahi.',
  'Raja and Mantri reveal first; Sipahi must find the Chor.',
  'Correct guess scores for Raja/Mantri/Sipahi; wrong guess helps Chor.',
  'Play multiple rounds and total the points.',
];

List<HomeGame> buildHomeGames() {
  final onlineIds = {for (final g in gameCatalog) g.id};
  final byId = {for (final g in localGames) g.id: g};

  final out = <HomeGame>[
    const HomeGame(
      id: 'guess_person',
      title: 'Guess the Person',
      subtitle: 'Ask smart questions and find the secret face.',
      color: Color(0xFFFFC93C),
      minPlayers: 2,
      maxPlayers: 6,
      category: HomeGameCategory.board,
      duration: '8-15 min',
      difficulty: 'Easy',
      rules: _guessRules,
      onlineSupported: false,
    ),
    const HomeGame(
      id: 'raja_mantri',
      title: 'Raja Mantri Chor Sipahi',
      subtitle: 'Can the Sipahi identify the Chor?',
      color: Color(0xFF8A1C3A),
      minPlayers: 4,
      maxPlayers: 4,
      category: HomeGameCategory.card,
      duration: '5-12 min',
      difficulty: 'Medium',
      rules: _rmcsRules,
      onlineSupported: onlineIds.contains('raja_mantri'),
    ),
  ];

  for (final info in localGames) {
    HomeGameCategory category = HomeGameCategory.arcade;
    final gameCategory = gameCatalog.where((x) => x.id == info.id).firstOrNull?.category;
    if (_sportsIds.contains(info.id)) {
      category = HomeGameCategory.sports;
    } else if (gameCategory == GameCategory.board) {
      category = HomeGameCategory.board;
    } else if (gameCategory == GameCategory.cards) {
      category = HomeGameCategory.card;
    } else if (_arcadeIds.contains(info.id) || gameCategory == GameCategory.action || gameCategory == GameCategory.party) {
      category = HomeGameCategory.arcade;
    }

    out.add(HomeGame(
      id: info.id,
      title: info.title,
      subtitle: info.tagline,
      color: info.color,
      minPlayers: info.minPlayers,
      maxPlayers: info.maxPlayers,
      category: category,
      duration: _estimateDuration(info),
      difficulty: _difficulty(info),
      rules: info.rules,
      onlineSupported: onlineIds.contains(info.id),
    ));
  }

  return out;
}

String _estimateDuration(LocalGameInfo g) {
  if (g.maxPlayers <= 1) return '3-8 min';
  if (g.id == 'chess' || g.id == 'backgammon') return '10-25 min';
  if (g.id == 'uno') return '8-18 min';
  if (g.id == 'battleship') return '12-20 min';
  return '5-15 min';
}

String _difficulty(LocalGameInfo g) {
  if ({'chess', 'backgammon', 'battleship', 'checkers'}.contains(g.id)) return 'Hard';
  if ({'uno', 'colour_clash', 'memory', 'math_duel', 'connect_four'}.contains(g.id)) return 'Medium';
  return 'Easy';
}

Widget localGamePage(String id) {
  if (id == 'guess_person') return const GuessPersonMenuScreen();
  if (id == 'raja_mantri') return const RmcsMenuScreen();
  final game = localGames.firstWhere((g) => g.id == id);
  return LocalGameShell(game: game);
}
