// Renders Guess the Person's menu and board to build/screens/gp_*.png for review.
// Run from mobile/: flutter test tool/gp_render_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_game_screen.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_menu_screen.dart';
import 'screens_test.dart' show loadFonts, snap;

void main() {
  Future<void> shot(WidgetTester tester, String name, Widget page, {Future<void> Function()? then}) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: page)));
    await tester.pump(const Duration(milliseconds: 300));
    if (then != null) await then();
    await snap(tester, key, name);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('menu', (tester) => shot(tester, 'gp_menu', const GuessPersonMenuScreen()));
  testWidgets('board', (tester) => shot(tester, 'gp_board', const GuessPersonGameScreen(), then: () async {
        await tester.tap(find.text('START CHOOSING'));
        await tester.pump(const Duration(milliseconds: 500));
      }));
}
