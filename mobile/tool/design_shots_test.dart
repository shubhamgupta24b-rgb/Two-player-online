// Renders the same set of screens before and after a redesign, with real fonts.
// Run from mobile/:  flutter test tool/design_shots_test.dart --dart-define=SHOTS=before
// Writes ../docs/redesign-shots/<SHOTS>/<name>.png
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/session/game_session_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/core/ui/components.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/features/home/home_screen.dart';
import 'package:multiplayer_game/features/join_room/join_room_screen.dart';
import 'package:multiplayer_game/features/lobby/lobby_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/game_art.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/login/login_screen.dart';
import 'package:multiplayer_game/features/privacy/privacy_screen.dart';
import 'package:multiplayer_game/features/quick_play/quick_play_screen.dart';
import 'package:multiplayer_game/features/records/records_screen.dart';
import 'package:multiplayer_game/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _set = String.fromEnvironment('SHOTS', defaultValue: 'after');
const _dark = !bool.fromEnvironment('LIGHT');
const _size = Size(390, 844);
const _ratio = 2.0;

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  var any = false;
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      l.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      any = true;
    }
  }
  if (any) await l.load();
}

Future<void> _fonts() async {
  final dir = Directory('assets/fonts');
  final byFamily = <String, List<String>>{};
  for (final f in dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ttf') || f.path.endsWith('.otf'))) {
    final family = f.uri.pathSegments.last.split(RegExp(r'[-.]')).first;
    byFamily.putIfAbsent(family, () => []).add(f.path);
  }
  for (final e in byFamily.entries) {
    final family = switch (e.key) {
      'LilitaOne' => 'Lilita One',
      'BricolageGrotesque' => 'Bricolage Grotesque',
      'DMSans' => 'DM Sans',
      final k => k
    };
    await _font(family, e.value);
  }
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  // The "before" app used Nunito for body text; the redesign uses the phone's system face.
  await _font(
      'Roboto',
      byFamily['Nunito'] ??
          [
            for (final w in ['Regular', 'Medium', 'Bold'])
              '$root/bin/cache/artifacts/material_fonts/Roboto-$w.ttf'
          ]);
  await _font('Noto Color Emoji', ['/tmp/emoji/e.ttf']);
  await _font('MaterialIcons',
      ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

class _QuietSocket extends SocketManager {
  @override
  Future<void> connect(String url, String token) async {}
  @override
  Future<Map<String, dynamic>> request(String event,
          [Map<String, dynamic>? payload]) async =>
      {'ok': true};
}

Room _room({String status = 'lobby', Map? party}) => Room.fromJson({
      'code': 'K7QX2M',
      'gameType': 'ludo',
      'hostId': 'me',
      'status': status,
      'maxPlayers': 4,
      'players': [
        {'userId': 'me', 'username': 'Asha', 'ready': true, 'connected': true},
        {'userId': 'op', 'username': 'Ravi', 'ready': true, 'connected': true},
        {
          'userId': 'p3',
          'username': 'Meera',
          'ready': false,
          'connected': true
        },
      ],
      'party': party,
      'playable': [
        'ludo',
        'colour_clash',
        'snakes_ladders',
        'find_spy',
        'quiz_battle'
      ],
    });

final _key = GlobalKey();

String _titleOf(String id) => id == 'guess_person'
    ? (_set == 'before' ? 'Guess the Person' : 'Face Hunt')
    : (_set == 'before' ? 'Raja Mantri Chor Sipahi' : 'Chit Court');

Future<(RoomManager, GameSessionManager)> _show(
    WidgetTester tester, Widget home,
    {Room? room, Size size = _size}) async {
  await tester.runAsync(_fonts);
  tester.view.physicalSize = size * _ratio;
  tester.view.devicePixelRatio = _ratio;
  tester.view.padding = size == _size
      ? const FakeViewPadding(top: 94, bottom: 68)
      : FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'uid': 'me', 'name': 'Asha'});
  final auth = AuthenticationManager();
  await tester.runAsync(auth.restore);
  final socket = _QuietSocket();
  final rm = RoomManager(socket)..room = room;
  final session = GameSessionManager(socket);
  final base = buildAppTheme(_dark ? Brightness.dark : Brightness.light);
  await tester.pumpWidget(RepaintBoundary(
    key: _key,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<SocketManager>.value(value: socket),
        ChangeNotifierProvider.value(value: rm),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: base.copyWith(
            textTheme: base.textTheme
                .apply(fontFamilyFallback: const ['Noto Color Emoji'])),
        home: DefaultTextStyle.merge(
            style: const TextStyle(fontFamilyFallback: ['Noto Color Emoji']),
            child: home),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 700));
  return (rm, session);
}

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: _ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('../docs/redesign-shots/$_set/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

/// First match of any of these labels, whatever the redesign calls them.
Finder _any(List<String> labels) {
  for (final s in labels) {
    final f = find.text(s);
    if (f.evaluate().isNotEmpty) return f.first;
  }
  return find
      .byWidgetPredicate((w) =>
          w is Text &&
          labels.any(
              (s) => (w.data ?? '').toUpperCase().contains(s.toUpperCase())))
      .first;
}

Future<void> _tap(WidgetTester tester, List<String> labels) async {
  final f = _any(labels);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void _shot(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, body);
}

void main() {
  _shot('splash', (t) async {
    await _show(t, const SplashScreen(minShow: Duration(seconds: 3)));
    await t.pump(const Duration(milliseconds: 1200));
    await _snap(t, '01_splash');
    await t.pump(const Duration(seconds: 3));
    await _done(t);
  });
  _shot('login', (t) async {
    await _show(t, const LoginScreen());
    await _snap(t, '02_login');
    await _done(t);
  });
  _shot('home', (t) async {
    await _show(t, const HomeScreen());
    await _snap(t, '03_home');
    await _done(t);
  });
  _shot('room and records tabs', (t) async {
    await _show(t, const HomeScreen());
    await t.tap(find.bySemanticsLabel('Rooms'));
    await t.pumpAndSettle();
    await _snap(t, '14_rooms_tab');
    await t.tap(find.bySemanticsLabel('Records'));
    await t.pumpAndSettle();
    await _snap(t, '15_records_tab');
    await _done(t);
  });
  _shot('library', (t) async {
    await _show(t, const LocalGamesHubScreen());
    await _snap(t, '04_library');
    await _done(t);
  });
  _shot('all previews', (t) async {
    final ids = [
      ...localGames.map((g) => (g.id, g.title, g.color)),
      ('guess_person', _titleOf('guess_person'), const Color(0xFFFFC93C)),
      ('raja_mantri', _titleOf('raja_mantri'), const Color(0xFF8A1C3A))
    ];
    await _show(
        t,
        Material(
          color: const Color(0xFF161513),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (id, title, color) in ids)
              SizedBox(
                width: 122,
                height: 116,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CustomPaint(
                                  painter: GameArtPainter(id, color),
                                  size: Size.infinite))),
                      Text(title,
                          maxLines: 1,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, height: 1.4)),
                    ]),
              ),
          ]),
        ),
        size: const Size(1040, 1300));
    await t.pump(const Duration(milliseconds: 300));
    await _snap(t, '90_all_game_previews');
    await _done(t);
  });
  _shot('icons', (t) async {
    await _show(
        t,
        Material(
          color: const Color(0xFF211F1B),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final i in GameIcons.values) GameIcon(i, size: 48)
            ]),
          ),
        ),
        size: const Size(760, 500));
    await _snap(t, '91_all_icons');
    await _done(t);
  });
  _shot('create', (t) async {
    await _show(t, const CreateRoomScreen());
    await _snap(t, '05_create_room');
    await _done(t);
  });
  _shot('join', (t) async {
    await _show(t, const JoinRoomScreen());
    await _snap(t, '06_join_room');
    await _done(t);
  });
  _shot('lobby', (t) async {
    final (rm, session) = await _show(t, const LobbyScreen(), room: _room());
    await _snap(t, '07_lobby');
    rm.room = _room(status: 'finished', party: {
      'games': [
        'ludo',
        'colour_clash',
        'find_spy',
        'quiz_battle',
        'snakes_ladders'
      ],
      'index': 1,
      'totals': {'me': 5, 'op': 4, 'p3': 3},
      'lastPoints': {'me': 3, 'op': 2, 'p3': 1},
      'done': false,
    });
    session.result = {
      'ranking': [
        {'userId': 'me', 'username': 'Asha', 'score': 1, 'rank': 1},
        {'userId': 'op', 'username': 'Ravi', 'score': 0, 'rank': 2},
        {'userId': 'p3', 'username': 'Meera', 'score': 0, 'rank': 2},
      ],
      'winners': ['me'],
    };
    rm.notifyListeners();
    session.notifyListeners();
    await t.pump(const Duration(milliseconds: 700));
    await _snap(t, '08_room_results');
    await _done(t);
  });
  _shot('quick play', (t) async {
    await _show(t, const QuickPlayScreen());
    await _snap(t, '09_quick_play');
    await _done(t);
  });
  _shot('records', (t) async {
    await _show(t, const RecordsScreen());
    await _snap(t, '10_records');
    await _done(t);
  });
  _shot('privacy', (t) async {
    await _show(t, const PrivacyScreen());
    await _snap(t, '11_privacy');
    await _done(t);
  });
  _shot('settings', (t) async {
    await _show(t, const HomeScreen());
    await t.tap(find.byTooltip('Settings').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await _snap(t, '12_settings');
    await _done(t);
  });
  _shot('intro, pause, rules', (t) async {
    final game = localGames.firstWhere((g) => g.id == 'ludo');
    await _show(t, LocalGameShell(game: game));
    await _snap(t, '13_game_start');
    await _done(t);
  });
  for (final id in [
    'ludo',
    'colour_clash',
    'tic_tac_toe',
    'quiz_battle',
    'connect_four',
    'memory'
  ]) {
    _shot('in game $id', (t) async {
      final game = localGames.firstWhere((g) => g.id == id);
      await _show(t, LocalGameShell(game: game));
      final cpu = find.byKey(const ValueKey('cpu1'));
      if (cpu.evaluate().isNotEmpty) {
        await t.ensureVisible(cpu);
        await t.pump();
        await t.tap(cpu);
        await t.pump();
      }
      await _tap(t, ['Start']);
      for (var i = 0; i < 80; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final opening = switch (id) {
        'tic_tac_toe' => 'Row 1, column 1: empty',
        'connect_four' => 'Column 4',
        'memory' => 'Hidden card 1',
        _ => null,
      };
      if (opening != null) {
        await t.tap(find.bySemanticsLabel(opening));
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
      }
      await _snap(t, '20_ingame_$id');
      await _done(t);
    });
  }
}
