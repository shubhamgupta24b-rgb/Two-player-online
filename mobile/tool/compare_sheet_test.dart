// Builds side-by-side before/after images from docs/redesign-shots.
// Run from mobile/:  flutter test tool/compare_sheet_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const _root = '../docs/redesign-shots';
const pairs = [
  ('Splash', '01_splash', '01_splash'),
  ('Sign-in', '02_login', '02_login'),
  ('Home becomes the Play tab', '03_home', '03_home'),
  ('Game library', '04_library', '04_library'),
  ('Create room', '05_create_room', '05_create_room'),
  ('Join room', '06_join_room', '06_join_room'),
  ('Lobby', '07_lobby', '07_lobby'),
  ('Room results', '08_room_results', '08_room_results'),
  ('Quick play', '09_quick_play', '09_quick_play'),
  ('Records', '10_records', '15_records_tab'),
  ('Privacy', '11_privacy', '11_privacy'),
  ('Settings', '12_settings', '12_settings'),
  ('Game start', '13_game_start', '13_game_start'),
  ('Tic-Tac-Toe becomes Three Up (new board)', '20_ingame_tic_tac_toe', '20_ingame_tic_tac_toe'),
  ('Connect Four becomes Drop Four (new board)', '20_ingame_connect_four', '20_ingame_connect_four'),
  ('Memory becomes Flip Twice (new board)', '20_ingame_memory', '20_ingame_memory'),
  ('Ludo becomes Token Rush', '20_ingame_ludo', '20_ingame_ludo'),
  ('Colour Clash becomes Colour Riot', '20_ingame_colour_clash', '20_ingame_colour_clash'),
  ('Quiz Battle becomes Buzzer Brawl', '20_ingame_quiz_battle', '20_ingame_quiz_battle'),
  ('All 62 game previews', '90_all_game_previews', '90_all_game_previews'),
  ('Icon set', '91_all_icons', '91_all_icons'),
];

Future<ui.Image> _load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void _text(Canvas c, String t, Offset at, double size, Color color, {double? center}) {
  final p = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Sheet', fontSize: size, color: color)), textDirection: TextDirection.ltr)..layout();
  p.paint(c, center == null ? at : Offset(center - p.width / 2, at.dy));
}

Future<void> _save(ui.Picture pic, int w, int h, String path) async {
  final img = await pic.toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Draws one pair at [x], [y]; each image scaled to [panel] wide. Returns the height used.
double _pair(Canvas c, ui.Image a, ui.Image b, double x, double y, double panel, double gap) {
  final h = panel * a.height / a.width > panel * b.height / b.width ? panel * a.height / a.width : panel * b.height / b.width;
  void draw(ui.Image i, double dx) {
    final r = Rect.fromLTWH(dx, y, panel, panel * i.height / i.width);
    final clip = RRect.fromRectAndRadius(r, const Radius.circular(18));
    c.save();
    c.clipRRect(clip);
    c.drawImageRect(i, Offset.zero & Size(i.width.toDouble(), i.height.toDouble()), r, Paint()..filterQuality = FilterQuality.medium);
    c.restore();
  }

  draw(a, x);
  draw(b, x + panel + gap);
  return h;
}

void main() {
  testWidgets('sheets', (tester) async {
    await tester.runAsync(() async {
      final l = FontLoader('Sheet')..addFont(Future.value(ByteData.view(File('assets/fonts/DMSans-Variable.ttf').readAsBytesSync().buffer)));
      await l.load();
      const bg = Color(0xFF161513), ink = Color(0xFFF5EFE4), muted = Color(0xFFC0B8AA);
      final loaded = <(String, String, ui.Image, ui.Image)>[];
      for (final (title, b, a) in pairs) {
        loaded.add((title, a, await _load('$_root/before/$b.png'), await _load('$_root/after/$a.png')));
      }
      // One image per pair.
      for (var i = 0; i < loaded.length; i++) {
        final (title, name, before, after) = loaded[i];
        const panel = 520.0, gap = 32.0, m = 40.0, top = 150.0;
        final hA = panel * before.height / before.width, hB = panel * after.height / after.width;
        final h = (hA > hB ? hA : hB) + top + m;
        const w = panel * 2 + gap + m * 2;
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);
        _text(c, title, const Offset(m, 32), 38, ink);
        _text(c, 'Before', const Offset(m, 100), 26, muted);
        _text(c, 'After', const Offset(m + panel + gap, 100), 26, muted);
        _pair(c, before, after, m, top, panel, gap);
        await _save(rec.endRecording(), w.toInt(), h.toInt(), '$_root/compare/${(i + 1).toString().padLeft(2, '0')}_$name.png');
      }
      // Everything on one sheet: the screens, then previews and icons.
      const panel = 200.0, gap = 12.0, group = 40.0, cols = 4, m = 40.0, labelH = 56.0, rowH = panel * 844 / 390 + labelH + 48;
      final screens = loaded.where((e) => !e.$2.startsWith('9')).toList();
      final rows = (screens.length / cols).ceil();
      final w = m * 2 + cols * (panel * 2 + gap) + (cols - 1) * group;
      final h = m * 2 + 70 + rows * rowH;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);
      _text(c, 'Party Games: before and after', const Offset(m, m), 44, ink);
      for (var i = 0; i < screens.length; i++) {
        final (title, _, before, after) = screens[i];
        final x = m + (i % cols) * (panel * 2 + gap + group), y = m + 70 + (i ~/ cols) * rowH;
        final clipped = title.length > 44 ? '${title.substring(0, 43)}…' : title;
        _text(c, clipped, Offset(x, y + 6), 20, ink);
        _text(c, 'Before', Offset(x, y + 34), 15, muted);
        _text(c, 'After', Offset(x + panel + gap, y + 34), 15, muted);
        _pair(c, before, after, x, y + labelH, panel, gap);
      }
      await _save(rec.endRecording(), w.toInt(), h.toInt(), '$_root/compare/00_whole_app.png');
    });
  });
}
