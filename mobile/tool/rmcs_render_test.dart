// Renders Raja Mantri's menu and table to build/screens/rmcs_*.png for review.
// Run from mobile/: flutter test tool/rmcs_render_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_game.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_screen.dart';
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

  testWidgets('menu', (tester) => shot(tester, 'rmcs_menu', const RmcsMenuScreen()));
  testWidgets('table', (tester) {
    final g = RmcsGame(totalRounds: 5);
    return shot(tester, 'rmcs_table', RmcsGameScreen(game: g), then: () async {
      await tester.pump(const Duration(milliseconds: 2400));
      for (var i = 0; i < 4; i++) {
        g.showPeek();
        await tester.pump(const Duration(milliseconds: 700));
        g.passPeek();
      }
      await tester.pump(const Duration(milliseconds: 1600));
    });
  });
}
