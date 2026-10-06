// Renders the app pages (home, hub, lobby, login, records, create/join room, quick play,
// privacy) to build/screens/page_*.png for review against mockups/app.
// Run from mobile/: flutter test tool/pages_render_test.dart
// (add --dart-define=APP_STYLE=flat for the flat app; files get a _flat suffix).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/ui/app_flavor.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/features/home/home_screen.dart';
import 'package:multiplayer_game/features/join_room/join_room_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/lobby/lobby_screen.dart';
import 'package:multiplayer_game/features/login/login_screen.dart';
import 'package:multiplayer_game/features/privacy/privacy_screen.dart';
import 'package:multiplayer_game/features/quick_play/quick_play_screen.dart';
import 'package:multiplayer_game/features/records/records_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens_test.dart' show loadFonts, snap;

class _Socket extends SocketManager {
  @override
  Future<void> connect(String url, String token) async {}
}

void main() {
  const suffix = flatStyle ? '_flat' : '';

  Future<void> shot(WidgetTester tester, String name, Widget page, {Room? room, Map<String, Object> prefs = const {}}) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member (a render test, run with flutter test)
    SharedPreferences.setMockInitialValues({'uid': 'me', 'name': 'Aarav', ...prefs});
    final auth = AuthenticationManager();
    await tester.runAsync(auth.restore);
    final socket = _Socket()..connected.value = true;
    final rm = RoomManager(socket)..room = room;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<SocketManager>.value(value: socket),
          ChangeNotifierProvider.value(value: rm),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: page),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await snap(tester, key, 'page_$name$suffix');
  }

  testWidgets('home', (tester) => shot(tester, 'home', const HomeScreen(), prefs: {'recent_games': ['archery']}));
  testWidgets('hub', (tester) => shot(tester, 'hub', const LocalGamesHubScreen(), prefs: {'favourite_games': ['archery']}));
  testWidgets('login', (tester) => shot(tester, 'login', const LoginScreen()));
  testWidgets('records', (tester) => shot(tester, 'records', const RecordsScreen(), prefs: {
        'records': '{"archery":{"p":6,"w":4,"b":46},"memory":{"p":3,"w":1,"b":6},"game_2048":{"p":9,"w":0,"b":2048}}',
        'recent_games': ['memory', 'archery'],
      }));
  testWidgets('create', (tester) => shot(tester, 'create', const CreateRoomScreen()));
  testWidgets('join', (tester) => shot(tester, 'join', const JoinRoomScreen()));
  testWidgets('quick', (tester) => shot(tester, 'quick', const QuickPlayScreen()));
  testWidgets('privacy', (tester) => shot(tester, 'privacy', const PrivacyScreen()));
  testWidgets('lobby', (tester) => shot(
        tester,
        'lobby',
        const LobbyScreen(),
        room: Room.fromJson({
          'code': 'K7Q2PX', 'gameType': 'memory', 'hostId': 'me', 'status': 'lobby', 'maxPlayers': 4,
          'players': [
            {'userId': 'me', 'username': 'Aarav', 'ready': true, 'connected': true},
            {'userId': 'b', 'username': 'Meera', 'ready': true, 'connected': true},
            {'userId': 'c', 'username': 'Rohan', 'ready': false, 'connected': true},
          ],
          'playable': ['memory', 'ludo'],
        }),
      ));
}
