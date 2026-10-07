// Renders "take turns" screens for a design review: flutter test tool/turns_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'render_util.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> shoot(WidgetTester tester, String id, String name) async {
  await tester.runAsync(loadFonts);
  phoneSize(tester);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: screenshotTheme(), home: withFonts(LocalGameShell(game: localGames.firstWhere((g) => g.id == id)))),
  ));
  await tester.pump();
  await tapText(tester, '⏱ 2 min');
  await tester.ensureVisible(find.text('👤 TAKE TURNS'));
  await tester.pump();
  await snap(tester, key, '${name}1intro_turn');
  await tapText(tester, 'PLAY');
  await snap(tester, key, '${name}2pass_turn');
  await tapText(tester, 'START');
  for (var i = 0; i < 10; i++) {
    await tester.tapAt(Offset(80.0 + (i % 5) * 60, 500));
    await tester.pump(const Duration(milliseconds: 500));
  }
  await snap(tester, key, '${name}3play_turn');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('fruit merge battle', (t) => shoot(t, 'fruit_merge_battle', 'tfm'));
  testWidgets('basketball', (t) => shoot(t, 'basketball_hoops', 'tbb'));
}
