class GameInfo {
  final String id;
  final String name;
  final bool playable; // flips to true as each game is implemented
  const GameInfo(this.id, this.name, {this.playable = false});
}

const gameCatalog = <GameInfo>[
  GameInfo('guess_person', 'Guess the Person', playable: true),
  GameInfo('crush_it', 'Crush It'),
  GameInfo('basketball_hoops', 'Basketball Hoops'),
  GameInfo('fruit_duel', 'Fruit Duel'),
  GameInfo('memory', 'Memory'),
  GameInfo('paint_fight', 'Paint Fight'),
];

String gameName(String id) => gameCatalog.firstWhere((g) => g.id == id, orElse: () => GameInfo(id, id)).name;
