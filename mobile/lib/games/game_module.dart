import 'package:flutter/material.dart';
import 'guess_person/guess_person_screen.dart';

/// Maps a gameType to its screen. Adding a game = add a folder + one line here.
Widget? gameScreenFor(String gameType) {
  switch (gameType) {
    case 'guess_person':
      return const GuessPersonScreen();
  }
  return null;
}
