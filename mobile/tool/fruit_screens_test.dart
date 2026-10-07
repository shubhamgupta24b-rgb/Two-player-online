// Renders Fruit Merge mid-game for a design review: flutter test tool/fruit_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/local_games/fruit_merge/fruit_merge_game.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'render_util.dart';

Future<void> playAndSnap(WidgetTester tester, String name, {int players = 1}) async {
  await tester.runAsync(loadFonts);
  phoneSize(tester);
  final key = GlobalKey();
  final game = players == 1 ? fruitMergeInfo : fruitBattleInfo;
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: screenshotTheme(), home: withFonts(LocalGameShell(game: game))),
  ));
  await tester.pump();
  await snap(tester, key, '${name}_intro_fruit');
  final play = find.text('PLAY').last;
  await tester.ensureVisible(play);
  await tester.pump();
  await tester.tap(play);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2700));
  // Drop fruit across the box(es), letting them fall.
  final xs = [0.2, 0.5, 0.8, 0.35, 0.65, 0.5, 0.25, 0.75, 0.5, 0.4, 0.6, 0.3, 0.7, 0.5];
  final size = tester.view.physicalSize;
  for (final x in xs) {
    if (players == 1) {
      await tester.tapAt(Offset(10 + x * (size.width - 20), size.height * 0.5));
    } else {
      await tester.tapAt(Offset(size.width * (0.1 + x * 0.8), size.height * 0.75)); // player 1 (bottom)
      await tester.tapAt(Offset(size.width * (0.9 - x * 0.8), size.height * 0.25)); // player 2 (top, upside down)
    }
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  await snap(tester, key, '${name}_play_fruit');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('solo', (t) => playAndSnap(t, 'fruit1solo'));
  testWidgets('battle', (t) => playAndSnap(t, 'fruit2battle', players: 2));
  test('theme loads', () => expect(buildAppTheme(), isNotNull));
}
