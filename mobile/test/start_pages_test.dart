import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/core/ui/components.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/features/home/home_screen.dart';
import 'package:multiplayer_game/features/join_room/join_room_screen.dart';
import 'package:multiplayer_game/features/privacy/privacy_screen.dart';
import 'package:multiplayer_game/features/quick_play/quick_play_screen.dart';
import 'package:multiplayer_game/features/records/records_screen.dart';
import 'package:multiplayer_game/features/leaderboard/leaderboard_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/login/login_screen.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_screen.dart';
import 'package:multiplayer_game/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell_helpers.dart';

/// Never touches the network; remembers who tried to connect.
class FakeSocket extends SocketManager {
  final connects = <String>[];
  @override
  Future<void> connect(String url, String token) async => connects.add(token);
}

Future<(AuthenticationManager, FakeSocket)> pumpApp(WidgetTester tester, Widget home, {Map<String, Object> prefs = const {}, Size size = const Size(411, 914)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final auth = AuthenticationManager();
  final socket = FakeSocket();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      Provider<SocketManager>.value(value: socket),
      ChangeNotifierProvider.value(value: RoomManager(socket)),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: home),
  ));
  return (auth, socket);
}

/// Runs the splash's real async start-up (SharedPreferences) and its intro.
Future<void> bootSplash(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('first launch: splash -> login -> home with your name', (tester) async {
    final (auth, socket) = await pumpApp(tester, const SplashScreen(minShow: Duration.zero));
    await tester.pump(const Duration(milliseconds: 400)); // the splash fades in
    expect(find.bySemanticsLabel('RivalRooms'), findsWidgets, reason: 'logo and name');
    expect(find.text('RivalRooms'), findsOneWidget);
    await bootSplash(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    expect(find.text('WELCOME!'), findsOneWidget);
    expect(find.text('?'), findsOneWidget, reason: 'empty avatar');
    await tester.tap(find.text('Play as guest'));
    await tester.pump();
    expect(find.text('Enter your name to start'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.enterText(find.byType(TextField), 'asha');
    await tester.pump();
    expect(find.text('A'), findsOneWidget, reason: 'avatar shows the initial');
    await tester.runAsync(() async {
      await tester.tap(find.text('Play as guest'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Play Local'), findsOneWidget);
    expect(auth.displayName, 'asha');
    expect(socket.connects.single, auth.token, reason: 'connects in the background');
  });

  testWidgets('returning player goes straight to home', (tester) async {
    final (_, socket) = await pumpApp(tester, const SplashScreen(minShow: Duration.zero), prefs: {'uid': 'u1', 'name': 'Ravi'});
    await bootSplash(tester);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Play Online'), findsOneWidget);
    expect(socket.connects, ['dev:u1:Ravi']);
  });

  for (final size in const [Size(320, 568), Size(411, 914)]) {
    testWidgets('create room: pick a game, filter, players follow the game limits (${size.width.toInt()})', (tester) async {
      await pumpApp(tester, const CreateRoomScreen(), size: size);
      await tester.pump();
      expect(find.text('CREATE A ROOM'), findsOneWidget);
      expect(find.text('Guess the Person (quiz)'), findsNothing);
      // Colour Clash is first and selected: up to 6 players.
      expect(find.bySemanticsLabel(RegExp('^Colour Clash, ')), findsOneWidget);
      await setPlayers(tester, 6);

      // Raja Mantri: exactly 4 players.
      await tester.tap(find.text('Raja Mantri Chor Sipahi').first);
      await tester.pump();
      // A room for 6 can still start with Raja Mantri's 4 players later: just a hint, not a block.
      expect(find.text('Needs 4 players: you can switch games in the room'), findsOneWidget);
      await setPlayers(tester, 4);
      expect(find.text('Can the Mantri catch the Chor?'), findsOneWidget);

      // Filter to action games.
      await tester.ensureVisible(find.text('Action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action'));
      await tester.pump();
      expect(find.text('Air Hockey'), findsOneWidget);
      expect(find.text('Ludo'), findsNothing);
      await tester.tap(find.text('Air Hockey'));
      await tester.pump();
      expect(find.text('Create room'), findsOneWidget);
      final chips = find.ancestor(of: find.text('Action'), matching: find.byType(ListView));
      await tester.dragUntilVisible(find.text('All'), chips, const Offset(120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pump();
      expect(find.text('Colour Clash'), findsWidgets, reason: 'back to all games, from the top');
    });
  }

  for (final size in const [Size(320, 568), Size(411, 914), Size(800, 1280)]) {
    testWidgets('home lays out and every section opens on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final (auth, _) = await pumpApp(tester, const HomeScreen(), prefs: {'uid': 'u1', 'name': 'A very long player name'}, size: size);
      await tester.runAsync(auth.restore);
      await tester.pump();
      expect(find.text('Play Online'), findsOneWidget);
      expect(find.text('Play Local'), findsOneWidget);
      expect(find.text('Play with Friends'), findsOneWidget);
      expect(find.text('TWO PLAYER GAMES'), findsOneWidget);

      final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

      /// Scrolls the main vertical list until [target] is on screen, then taps it.
      Future<void> tapOnScreen(Finder target, {Finder? scrollable}) async {
        final scroller = scrollable ?? vertical.first;
        await tester.scrollUntilVisible(target, 200, scrollable: scroller);
        await tester.pumpAndSettle();
        final hit = target.hitTestable();
        expect(hit, findsOneWidget);
        await tester.tap(hit);
        await tester.pumpAndSettle();
      }

      Future<void> open(Finder target) async {
        await tapOnScreen(target);
      }

      Future<void> openAndBack(Finder target, Type page) async {
        await open(target);
        expect(find.byType(page), findsOneWidget);
        Navigator.of(tester.element(find.byType(page))).pop();
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(find.byType(PlayerBadge), 40, scrollable: vertical.first);
      await tester.tap(find.byType(PlayerBadge));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      for (final (label, page) in const [('Leaderboard', LeaderboardScreen), ('My records', RecordsScreen), ('Privacy', PrivacyScreen)]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);
        if (page == LeaderboardScreen) expect(find.text('Ranked by games won'), findsOneWidget);
        Navigator.of(tester.element(find.byType(page))).pop();
        await tester.pumpAndSettle();
        if (page != PrivacyScreen) await tapOnScreen(find.byType(PlayerBadge));
      }

      await openAndBack(find.text('Play Local'), LocalGamesHubScreen);
      for (final (label, page) in const [('Create room', CreateRoomScreen), ('Join room', JoinRoomScreen), ('Quick play', QuickPlayScreen)]) {
        await open(find.text('Play Online'));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);
        Navigator.of(tester.element(find.byType(page))).pop();
        await tester.pumpAndSettle();
      }
      await open(find.text('Play Local'));
      Future<void> tapGame(String title) async {
        final label = find.text(title);
        final grid = find.descendant(
          of: find.byType(LocalGamesHubScreen),
          matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
        ).first;
        for (var i = 0; i < 24; i++) {
          await tester.drag(grid, const Offset(0, 700));
          await tester.pump();
        }
        for (var i = 0; i < 80 && label.hitTestable().evaluate().isEmpty; i++) {
          await tester.drag(grid, const Offset(0, -220));
          await tester.pump();
        }
        expect(label.hitTestable(), findsOneWidget, reason: '$title is on screen');
        await tester.tap(label.hitTestable());
        await tester.pumpAndSettle();
      }

      await tapGame('Memory');
      expect(find.byType(LocalGameShell), findsOneWidget);
      Navigator.of(tester.element(find.byType(LocalGameShell))).pop();
      await tester.pumpAndSettle();
      await tapGame('Raja Mantri Chor Sipahi');
      expect(find.byType(RmcsMenuScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(RmcsMenuScreen))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(LocalGamesHubScreen))).pop();
      await tester.pumpAndSettle();
      await open(find.text('Play with Friends'));
      expect(find.text('Same Wi-Fi'), findsOneWidget);
      expect(find.textContaining('Server: '), findsNothing);
    });
  }
}
