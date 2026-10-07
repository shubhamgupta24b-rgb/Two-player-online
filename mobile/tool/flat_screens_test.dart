// Renders the flat app's screens for a design review.
// Run from mobile/:  flutter test tool/flat_screens_test.dart --dart-define=APP_STYLE=flat
// Writes build/screens/flat_<name>_flat.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_flavor.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_game_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'render_util.dart';

Future<GlobalKey> show(WidgetTester tester, Widget home) async {
  await tester.runAsync(loadFonts);
  phoneSize(tester);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: screenshotTheme(), home: withFonts(home)),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return key;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  test('built with APP_STYLE=flat', () => expect(flatStyle, isTrue));

  testWidgets('guess the person', (tester) async {
    final key = await show(tester, const GuessPersonGameScreen());
    await tapText(tester, 'START CHOOSING');
    await tapText(tester, 'RANDOM');
    await snap(tester, key, 'flat_gp1_choose_flat');
    await tapText(tester, 'CONFIRM');
    await tapText(tester, 'CONFIRM PERSON');
    await tapText(tester, "I'M READY");
    await tester.pump(const Duration(milliseconds: 400));
    await tapText(tester, 'HAIR');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Dialog), findsOneWidget);
    await snap(tester, key, 'flat_gp2_popup_flat');
    await tester.tap(find.text('LONG').last);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Dialog), findsNothing, reason: 'asking closes the pop-up');
    expect(find.textContaining('long hair'), findsOneWidget, reason: 'the answer banner shows the question');
    await snap(tester, key, 'flat_gp3_after_flat');
    await done(tester);
  });

  testWidgets('memory', (tester) async {
    final key = await show(tester, LocalGameShell(game: localGames.firstWhere((g) => g.id == 'memory')));
    await tapText(tester, 'PLAY');
    await tester.pump(const Duration(milliseconds: 2800));
    // Flip a few cards (two misses show four faces for a moment).
    for (final at in const [Offset(60, 220), Offset(160, 360), Offset(260, 500)]) {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 350));
    }
    await snap(tester, key, 'flat_mem_flat');
    await done(tester);
  });

  for (final id in flatGames.where((g) => g != 'memory')) {
    testWidgets(id, (tester) async {
      final game = localGames.firstWhere((g) => g.id == id);
      final key = await show(tester, LocalGameShell(game: game));
      if (game.minPlayers > 2 || game.maxPlayers > 3) await tapText(tester, '${game.minPlayers.clamp(4, game.maxPlayers)}');
      await tapText(tester, 'PLAY');
      await tester.pump(const Duration(milliseconds: 2800));
      await snap(tester, key, 'flat_${id}_1_flat');
      if (find.text('TAP TO SEE YOUR SECRET').evaluate().isNotEmpty) {
        await tapText(tester, 'TAP TO SEE YOUR SECRET');
        await tester.pump(const Duration(milliseconds: 500));
        await snap(tester, key, 'flat_${id}_2_flat');
      }
      await done(tester);
    });
  }
}
