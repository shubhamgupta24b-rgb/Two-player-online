// Renders the app's main screens (outside the games) for a design review.
// Run from mobile/:  flutter test tool/app_screens_test.dart
// Writes build/screens/app_<name>_shot.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/session/game_session_manager.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_menu_screen.dart';
import 'package:multiplayer_game/features/home/home_screen.dart';
import 'package:multiplayer_game/features/join_room/join_room_screen.dart';
import 'package:multiplayer_game/features/lobby/lobby_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/login/login_screen.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_game.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_screen.dart';
import 'package:multiplayer_game/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'render_util.dart';

class _QuietSocket extends SocketManager {
  @override
  Future<void> connect(String url, String token) async {}
  @override
  Future<Map<String, dynamic>> request(String event, [Map<String, dynamic>? payload]) async => {'ok': true};
}

Room _room({String status = 'lobby', Map? party}) => Room.fromJson({
      'code': 'K7QX2M', 'gameType': 'ludo', 'hostId': 'me', 'status': status, 'maxPlayers': 4,
      'players': [
        {'userId': 'me', 'username': 'Asha', 'ready': true, 'connected': true},
        {'userId': 'op', 'username': 'Ravi', 'ready': true, 'connected': true},
        {'userId': 'p3', 'username': 'Meera', 'ready': false, 'connected': true},
      ],
      'party': party, 'playable': ['ludo', 'colour_clash', 'snakes_ladders', 'find_spy', 'quiz_battle'],
    });

Future<(GlobalKey, RoomManager, GameSessionManager)> show(WidgetTester tester, Widget home, {Room? room}) async {
  await tester.runAsync(loadFonts);
  phoneSize(tester);
  SharedPreferences.setMockInitialValues({'uid': 'me', 'name': 'Asha'});
  final auth = AuthenticationManager();
  await tester.runAsync(auth.restore);
  final socket = _QuietSocket();
  final rm = RoomManager(socket)..room = room;
  final session = GameSessionManager(socket);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<SocketManager>.value(value: socket),
        ChangeNotifierProvider.value(value: rm),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: screenshotTheme(), home: withFonts(home)),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 600));
  return (key, rm, session);
}

Future<void> done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('splash', (tester) async {
    final (key, _, _) = await show(tester, const SplashScreen(minShow: Duration(seconds: 3)));
    await tester.pump(const Duration(milliseconds: 1200));
    await snap(tester, key, 'app_1splash_shot');
    await tester.pump(const Duration(seconds: 3));
    await done(tester);
  });

  testWidgets('login', (tester) async {
    final (key, _, _) = await show(tester, const LoginScreen());
    await snap(tester, key, 'app_2login_shot');
    await done(tester);
  });

  testWidgets('home', (tester) async {
    final (key, _, _) = await show(tester, const HomeScreen());
    await snap(tester, key, 'app_3home_shot');
    await done(tester);
  });

  testWidgets('hub', (tester) async {
    final (key, _, _) = await show(tester, const LocalGamesHubScreen());
    await snap(tester, key, 'app_4hub_shot');
    await tester.scrollUntilVisible(find.text('🧍 SOLO GAMES'), 300);
    await tester.pump();
    await snap(tester, key, 'app_5hubsolo_shot');
    await done(tester);
  });

  testWidgets('create & join room', (tester) async {
    final (key, _, _) = await show(tester, const CreateRoomScreen());
    await snap(tester, key, 'app_6create_shot');
    await done(tester);
    final (key2, _, _) = await show(tester, const JoinRoomScreen());
    await snap(tester, key2, 'app_7join_shot');
    await done(tester);
  });

  testWidgets('lobby & results', (tester) async {
    final (key, rm, session) = await show(tester, const LobbyScreen(), room: _room());
    await snap(tester, key, 'app_8lobby_shot');
    rm.room = _room(status: 'finished', party: {
      'games': ['ludo', 'colour_clash', 'find_spy', 'quiz_battle', 'snakes_ladders'], 'index': 1,
      'totals': {'me': 5, 'op': 4, 'p3': 3}, 'lastPoints': {'me': 3, 'op': 2, 'p3': 1}, 'done': false,
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
    await tester.pump(const Duration(milliseconds: 600));
    await snap(tester, key, 'app_9results_shot');
    await done(tester);
  });

  testWidgets('raja mantri', (tester) async {
    final (key, _, _) = await show(tester, const RmcsMenuScreen());
    await snap(tester, key, 'app_raja1menu_shot');
    await done(tester);
    final g = RmcsGame();
    final (key2, _, _) = await show(tester, RmcsGameScreen(game: g));
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, key2, 'app_raja2peek_shot');
    await done(tester);
  });

  testWidgets('guess the person', (tester) async {
    final (key, _, _) = await show(tester, const GuessPersonMenuScreen());
    await snap(tester, key, 'app_gp_menu_shot');
    await done(tester);
  });

  // A few games mid-play against the computer, and the score screens.
  for (final (id, ms) in [('ludo', 9000), ('colour_clash', 3000), ('snakes_ladders', 9000), ('tic_tac_toe', 1500), ('memory', 6000), ('quiz_battle', 4000)]) {
    testWidgets('vs computer: $id', (tester) async {
      final game = localGames.firstWhere((g) => g.id == id);
      final (key, _, _) = await show(tester, LocalGameShell(game: game));
      await tester.ensureVisible(find.text('🤖 PLAY VS COMPUTER'));
      await tester.pump();
      await tester.tap(find.text('🤖 PLAY VS COMPUTER'));
      await tester.pump();
      await tester.ensureVisible(find.text('PLAY'));
      await tester.pump();
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      for (var t = 0; t < 2600 + ms; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await snap(tester, key, 'app_bot_${id}_shot');
      await done(tester);
    });
  }

  testWidgets('score screens', (tester) async {
    // Flappy Jump ends after one fall; Crush It ends on its own timer.
    for (final (id, secs) in [('flappy_jump', 6), ('crush_it', 34)]) {
      final game = localGames.firstWhere((g) => g.id == id);
      final (key, _, _) = await show(tester, LocalGameShell(game: game));
      await tester.ensureVisible(find.text('PLAY'));
      await tester.pump();
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2600));
      if (id == 'flappy_jump') await tester.tapAt(const Offset(200, 500));
      for (var t = 0; t < secs * 10; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await snap(tester, key, 'app_result_${id}_shot');
      await done(tester);
    }
  });
}
