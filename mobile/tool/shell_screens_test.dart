// Renders the shared shell screens (countdown, pause menu, results) to PNGs for review.
// Run from mobile/:  flutter test tool/shell_screens_test.dart
// Writes build/screens/shell_*.png at 411x914.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'screens_test.dart' show loadFonts, snap;

Future<GlobalKey> open(WidgetTester tester, LocalGameInfo game) async {
  await tester.runAsync(loadFonts);
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final theme = buildAppTheme();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: const ['Segoe UI Emoji'])),
      home: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Roboto', fontFamilyFallback: ['Segoe UI Emoji']),
        child: LocalGameShell(game: game),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return key;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pump();
  await tester.tap(find.text(text).first);
  await tester.pump();
}

void main() {
  testWidgets('countdown, pause menu and a 4-player result', (tester) async {
    final key = await open(tester, localGames.firstWhere((g) => g.id == 'crush_it'));
    await tapText(tester, '4');
    await tapText(tester, 'PLAY');
    await tester.pump(const Duration(milliseconds: 500));
    await snap(tester, key, 'shell_countdown');
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.tap(find.byType(PauseButton).first);
    await tester.pumpAndSettle();
    await snap(tester, key, 'shell_pause');
    await tapText(tester, 'RESUME');
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 40; i++) {
      await tester.tapAt(Offset(60 + (i % 4) * 90.0, 300 + (i % 3) * 200.0));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(seconds: 32));
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await snap(tester, key, 'shell_result');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a solo result', (tester) async {
    final key = await open(tester, localGames.firstWhere((g) => g.id == 'whack_mole'));
    await tapText(tester, 'PLAY');
    await tester.pump(const Duration(seconds: 40));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await snap(tester, key, 'shell_solo_result');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
