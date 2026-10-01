import 'package:flutter/material.dart';
import 'guess_person/guess_person_screen.dart';
import 'memory/memory_screen.dart';
import 'crush_it/crush_it_screen.dart';
import 'basketball_hoops/basketball_hoops_screen.dart';
import 'fruit_duel/fruit_duel_screen.dart';
import 'paint_fight/paint_fight_screen.dart';

Widget? gameScreenFor(String gameType){
 switch(gameType){
  case 'guess_person': return const GuessPersonScreen();
  case 'memory': return const MemoryScreen();
  case 'crush_it': return const CrushItScreen();
  case 'basketball_hoops': return const BasketballHoopsScreen();
  case 'fruit_duel': return const FruitDuelScreen();
  case 'paint_fight': return const PaintFightScreen();
 }
 return null;
}