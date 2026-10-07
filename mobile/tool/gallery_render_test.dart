// Renders the debug design gallery (materials, badges, icons, fruit) to
// build/screens/gallery.png for review. Run from mobile/: flutter test tool/gallery_render_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/core/ui/debug_gallery.dart';
import 'screens_test.dart' show loadFonts, snap;

void main() {
  testWidgets('design gallery', (tester) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(411, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: const DebugGalleryScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, key, 'gallery');
  });
}
