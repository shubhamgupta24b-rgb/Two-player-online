// Helpers for rendering real-looking screenshots in tests (real fonts, emoji, icons).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      any = true;
    }
  }
  if (any) await loader.load();
}

Future<void> loadFonts() async {
  await _load('Roboto', [for (final f in ['segoeui.ttf', 'segoeuib.ttf', 'seguibl.ttf', 'seguisb.ttf']) 'C:\\Windows\\Fonts\\$f']);
  await _load('Segoe UI Emoji', [r'C:\Windows\Fonts\seguiemj.ttf']);
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\sg857\Downloads\flutter\flutter';
  await _load('MaterialIcons', ['$root\\bin\\cache\\artifacts\\material_fonts\\MaterialIcons-Regular.otf']);
}

/// The app theme with real fonts and emoji fallback.
ThemeData screenshotTheme() {
  final t = buildAppTheme();
  return t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: const ['Segoe UI Emoji']));
}

Widget withFonts(Widget child) => DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto', fontFamilyFallback: ['Segoe UI Emoji']), child: child);

void phoneSize(WidgetTester tester, [Size size = const Size(411, 914)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> snap(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/screens/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
