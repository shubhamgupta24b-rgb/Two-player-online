// Renders Smash Karts mid-match for a design review: flutter test tool/karts_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/local_games/smash_karts/smash_karts_game.dart';
import 'render_util.dart';

Future<void> shoot(WidgetTester tester, String name, {required bool bots}) async {
  await tester.runAsync(loadFonts);
  phoneSize(tester);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: screenshotTheme(), home: withFonts(LocalGameShell(game: smashKartsInfo))),
  ));
  await tester.pump();
  if (bots) {
    await tester.ensureVisible(find.text('4').last);
    await tester.pump();
    await tester.tap(find.text('4').last);
    await tester.pump();
    await tester.ensureVisible(find.text('🤖 PLAY VS COMPUTER'));
    await tester.pump();
    await tester.tap(find.text('🤖 PLAY VS COMPUTER'));
    await tester.pump();
  }
  await tester.ensureVisible(find.text('PLAY').last);
  await tester.pump();
  await tester.tap(find.text('PLAY').last);
  await tester.pump();
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await snap(tester, key, '${name}_kart');
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await snap(tester, key, '${name}2_kart');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('vs bots (follow camera)', (t) => shoot(t, 'k1solo', bots: true));
  testWidgets('two people (whole park)', (t) => shoot(t, 'k2duo', bots: false));
}
