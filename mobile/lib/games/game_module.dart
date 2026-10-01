import 'package:flutter/material.dart';
import 'guess_person/guess_person_screen.dart';
import 'memory/memory_screen.dart';
import 'crush_it/crush_it_screen.dart';
import 'basketball_hoops/basketball_hoops_screen.dart';

Widget? gameScreenFor(String gameType){
 switch(gameType){
  case 'guess_person': return const GuessPersonScreen();
  case 'memory': return const MemoryScreen();
  case 'crush_it': return const CrushItScreen();
  case 'basketball_hoops': return const BasketballHoopsScreen();
 }
 return null;
}