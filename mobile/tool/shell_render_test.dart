// Renders the shared game screens (intro, pause, results, how to play) to build/screens
// for review against the mockups. Run from mobile/: flutter test tool/shell_render_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/how_to_play.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/local_games/shell/pause_sheet.dart';
import 'package:multiplayer_game/features/local_games/shell/result_screen.dart';
import 'screens_test.dart' show loadFonts, snap;

void main() {
  final archery = localGames.firstWhere((g) => g.id == 'archery');
  final memory = localGames.firstWhere((g) => g.id == 'memory');
  final solo = localGames.firstWhere((g) => g.solo);

  Future<void> shot(WidgetTester tester, String name, Widget child) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: child)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await snap(tester, key, name);
  }

  Widget bg(Widget child) => Scaffold(body: GameBackground(color: archery.color, child: SafeArea(child: child)));

  testWidgets('intro', (tester) => shot(tester, 'shell_intro', LocalGameShell(game: archery)));

  testWidgets('how to play', (tester) => shot(tester, 'shell_how_to_play', HowToPlay(game: archery)));

  testWidgets('pause', (tester) => shot(tester, 'shell_pause', bg(PauseSheet(game: archery, state: 'Arrow 3 of 5'))));

  testWidgets('results', (tester) {
    final players = [GpPlayer(name: 'Meera', color: gpPlayerColors[1], score: 46), GpPlayer(name: 'Aarav', color: gpPlayerColors[0], score: 40)];
    return shot(tester, 'shell_results', bg(ResultScreen(game: archery, players: players, wins: const [1, 0], onRematch: () {}, onChangePlayers: () {}, onExit: () {})));
  });

  testWidgets('results 4 players', (tester) {
    final players = [
      for (final (i, n, s) in const [(0, 'Aarav', 6), (1, 'Meera', 4), (2, 'Rohan', 1), (3, 'Ishita', 1)]) GpPlayer(name: n, color: gpPlayerColors[i], score: s),
    ];
    return shot(tester, 'shell_results4', bg(ResultScreen(game: memory, players: players, wins: const [2, 0, 0, 0], onRematch: () {}, onChangePlayers: () {}, onExit: () {})));
  });

  testWidgets('solo result', (tester) {
    return shot(tester, 'shell_solo', bg(ResultScreen(game: solo, players: [GpPlayer(name: 'You', color: gpPlayerColors[0], score: 1280)], best: 1280, newBest: true, onRematch: () {}, onExit: () {})));
  });
}
