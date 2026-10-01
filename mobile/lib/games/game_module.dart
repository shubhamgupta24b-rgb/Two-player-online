import 'package:flutter/material.dart';
import 'guess_person/guess_person_screen.dart';
import 'memory/memory_screen.dart';

Widget? gameScreenFor(String gameType) {
  switch (gameType) {
    case 'guess_person':
      return const GuessPersonScreen();
    case 'memory':
      return const MemoryScreen();
  }
  return null;
}