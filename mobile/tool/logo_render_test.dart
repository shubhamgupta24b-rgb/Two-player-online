// Renders the in-app logo (PartyLogoPainter) to build/screens/logo_*.png, to compare with
// docs/app-logo/store/icon_1024.png. Run from mobile/: flutter test tool/logo_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/party_logo.dart';

Future<void> render(String name, CustomPainter painter, double size) async {
  final rec = ui.PictureRecorder();
  painter.paint(Canvas(rec), Size(size, size));
  final image = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File('build/screens/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('logo', (tester) async {
    await tester.runAsync(() async {
      await render('logo_rounded', const PartyLogoPainter(), 512);
      await render('logo_foreground', const PartyLogoPainter(rounded: false, artScale: 0.7), 512);
    });
  });
}
