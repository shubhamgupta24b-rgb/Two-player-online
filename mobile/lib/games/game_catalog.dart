class GameInfo {
  final String id;
  final String name;
  final bool playable;
  const GameInfo(this.id, this.name, {this.playable = false});
}
const gameCatalog=<GameInfo>[
  GameInfo('guess_person','Guess the Person',playable:true),
  GameInfo('crush_it','Crush It',playable:true),
  GameInfo('basketball_hoops','Basketball Hoops',playable:true),
  GameInfo('fruit_duel','Fruit Duel',playable:true),
  GameInfo('memory','Memory',playable:true),
  GameInfo('paint_fight','Paint Fight',playable:true),
];
String gameName(String id)=>gameCatalog.firstWhere((g)=>g.id==id,orElse:()=>GameInfo(id,id)).name;