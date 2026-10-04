import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'text_scale_test.dart' show scaled, phone;

void main() {
  testWidgets('intro only', (tester) async {
    phone(tester);
    await tester.pumpWidget(scaled(LocalGameShell(game: localGames.firstWhere((g) => g.id == 'colour_clash'))));
    await tester.pump(const Duration(milliseconds: 400));
    debugPrint('INTRO DONE');
  });
}
