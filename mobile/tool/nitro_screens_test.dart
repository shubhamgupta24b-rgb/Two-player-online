// Renders Nitro Knockout's intro for a design review: flutter test tool/nitro_screens_test.dart
// The match itself runs in a WebView (the WASM game), so only the shell screens are
// exercised here — the 3D scene needs a real device. Add --update-goldens to write
// tool/goldens/nitro_intro.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/nitro_knockout/nitro_knockout_game.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'render_util.dart';

Future<void> shoot(WidgetTester tester, String name) async {
  await tester.runAsync(loadFonts);
  phoneSize(tester);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: screenshotTheme(), home: withFonts(LocalGameShell(game: nitroKartsInfo))),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await expectLater(find.byKey(key), matchesGoldenFile('goldens/$name.png'));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('intro screen (you vs 7 bots)', (t) => shoot(t, 'nitro_intro'));
}
