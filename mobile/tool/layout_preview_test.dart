// Renders the new home and wins leaderboard with sample server data.
// Run from mobile/: flutter test tool/layout_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/features/home/home_screen.dart';
import 'package:multiplayer_game/features/leaderboard/leaderboard_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens_test.dart' show loadFonts, snap;

class _PreviewSocket extends SocketManager {
  @override
  Future<Map<String, dynamic>> request(String event, [Map<String, dynamic>? payload]) async {
    if (event == 'online_counts') {
      return {
        'ok': true,
        'total': 18,
        'games': [
          {'id': 'memory', 'playing': 8},
          {'id': 'ludo', 'playing': 5},
          {'id': 'smash_karts', 'playing': 3},
          {'id': 'colour_clash', 'playing': 2},
        ],
      };
    }
    if (event == 'leaderboard') {
      return {
        'ok': true,
        'players': [
          {'username': 'Meera', 'wins': 24, 'played': 31},
          {'username': 'Aarav', 'wins': 18, 'played': 29},
          {'username': 'Rohan', 'wins': 18, 'played': 22},
          {'username': 'Ishita', 'wins': 11, 'played': 19},
          {'username': 'Kabir', 'wins': 7, 'played': 14},
        ],
      };
    }
    return {'ok': true};
  }
}

void main() {
  Future<GlobalKey> shot(WidgetTester tester, String name, Widget page, {Size size = const Size(390, 844)}) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'uid': 'me', 'name': 'Aarav', 'recent_games': ['memory']});
    final auth = AuthenticationManager();
    await tester.runAsync(auth.restore);
    final socket = _PreviewSocket()..connected.value = true;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<SocketManager>.value(value: socket),
          ChangeNotifierProvider.value(value: RoomManager(socket)),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: page),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await snap(tester, key, name);
    return key;
  }

  testWidgets('home preview', (tester) async {
    final key = await shot(tester, 'preview_home', const HomeScreen());
    await tester.tap(find.text('All Games'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, key, 'preview_all_games');
    await tester.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, key, 'preview_all_games_later');
  });

  testWidgets('narrow home', (tester) async {
    final key = await shot(tester, 'preview_home_narrow', const HomeScreen(), size: const Size(320, 568));
    await tester.tap(find.text('All Games'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, key, 'preview_all_games_narrow');
  });

  testWidgets('memory setup preview', (tester) async {
    final key = await shot(tester, 'preview_create_room', const CreateRoomScreen());
    await tester.scrollUntilVisible(
      find.text('Memory'),
      400,
      scrollable: find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)).first,
      maxScrolls: 80,
    );
    await tester.tap(find.text('Memory').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, key, 'preview_memory_setup');
  });

  testWidgets('games preview', (tester) async {
    final key = await shot(tester, 'preview_games', const LocalGamesHubScreen());
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -720));
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, key, 'preview_games_grid');
  });
  testWidgets('leaderboard preview', (tester) => shot(tester, 'preview_leaderboard', const LeaderboardScreen()));
}
