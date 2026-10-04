import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/create_room/create_room_screen.dart';
import 'package:multiplayer_game/features/home/home_screen.dart';
import 'package:multiplayer_game/features/join_room/join_room_screen.dart';
import 'package:multiplayer_game/features/privacy/privacy_screen.dart';
import 'package:multiplayer_game/features/records/records_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/login/login_screen.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_screen.dart';
import 'package:multiplayer_game/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(find.bySemanticsLabel('Party Games'), findsWidgets, reason: 'logo and wordmark');
    expect(find.text('GAMES'), findsWidgets);
    await bootSplash(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    expect(find.text('WELCOME!'), findsOneWidget);
    expect(find.text('?'), findsOneWidget, reason: 'empty avatar');
    await tester.tap(find.text("LET'S PLAY"));
    await tester.pump();
    expect(find.text('Enter your name to start'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.enterText(find.byType(TextField), 'asha');
    await tester.pump();
    expect(find.text('A'), findsOneWidget, reason: 'avatar shows the initial');
    await tester.runAsync(() async {
      await tester.tap(find.text("LET'S PLAY"));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hi, asha 👋'), findsOneWidget);
    expect(auth.displayName, 'asha');
    expect(socket.connects.single, auth.token, reason: 'connects in the background');
  });

  testWidgets('returning player goes straight to home', (tester) async {
    final (_, socket) = await pumpApp(tester, const SplashScreen(minShow: Duration.zero), prefs: {'uid': 'u1', 'name': 'Ravi'});
    await bootSplash(tester);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hi, Ravi 👋'), findsOneWidget);
    expect(socket.connects, ['dev:u1:Ravi']);
  });

  for (final size in const [Size(320, 568), Size(411, 914)]) {
    testWidgets('create room: pick a game, filter, players follow the game limits (${size.width.toInt()})', (tester) async {
      await pumpApp(tester, const CreateRoomScreen(), size: size);
      await tester.pump();
      expect(find.text('CREATE A ROOM'), findsOneWidget);
      expect(find.text('Guess the Person (quiz)'), findsNothing);
      // Colour Clash is first and selected: up to 6 players.
      expect(find.bySemanticsLabel('Colour Clash'), findsOneWidget);
      Finder count(int n) => find.descendant(of: find.byType(GestureDetector), matching: find.text('$n'));
      await tester.tap(count(6).last);
      await tester.pump();

      // Raja Mantri: exactly 4 players.
      await tester.tap(find.text('Raja Mantri Chor Sipahi').first);
      await tester.pump();
      // A room for 6 can still start with Raja Mantri's 4 players later: just a hint, not a block.
      expect(find.text('Needs 4 players: you can switch games in the room'), findsOneWidget);
      await tester.tap(count(4).last);
      await tester.pump();
      expect(find.text('Can the Mantri catch the Chor?'), findsOneWidget);

      // Filter to action games.
      await tester.ensureVisible(find.text('ACTION'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACTION'));
      await tester.pump();
      expect(find.text('Air Hockey'), findsOneWidget);
      expect(find.text('Ludo'), findsNothing);
      await tester.tap(find.text('Air Hockey'));
      await tester.pump();
      expect(find.text('CREATE ROOM'), findsOneWidget);
      final chips = find.ancestor(of: find.text('ACTION'), matching: find.byType(ListView));
      await tester.dragUntilVisible(find.text('ALL'), chips, const Offset(120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALL'));
      await tester.pump();
      expect(find.text('Colour Clash'), findsWidgets, reason: 'back to all games, from the top');
    });
  }

  for (final size in const [Size(320, 568), Size(411, 914), Size(800, 1280)]) {
    testWidgets('home lays out and every section opens on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final (auth, _) = await pumpApp(tester, const HomeScreen(), prefs: {'uid': 'u1', 'name': 'A very long player name'}, size: size);
      await tester.runAsync(auth.restore);
      await tester.pump();
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('PLAY ON\nONE DEVICE'), findsOneWidget);

      Future<void> openAndBack(Finder target, Type page) async {
        await tester.scrollUntilVisible(target, 120, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(target); // also scrolls the sideways featured row
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);
        Navigator.of(tester.element(find.byType(page))).pop();
        await tester.pumpAndSettle();
      }

      await openAndBack(find.text('PLAY ON\nONE DEVICE'), LocalGamesHubScreen);
      await openAndBack(find.text('CREATE ROOM'), CreateRoomScreen);
      await openAndBack(find.text('JOIN ROOM'), JoinRoomScreen);
      await openAndBack(find.text('Colour Clash'), LocalGameShell);
      // Featured games scroll sideways.
      await tester.dragUntilVisible(find.text('Raja Mantri'), find.byType(ListView).last, const Offset(-150, 0));
      await openAndBack(find.text('Raja Mantri'), RmcsMenuScreen);
      await openAndBack(find.text('SEE ALL'), LocalGamesHubScreen);
      await tester.scrollUntilVisible(find.text('Privacy'), 120, scrollable: find.byType(Scrollable).first);
      expect(find.text('QUICK PLAY'), findsOneWidget);
      await openAndBack(find.text('🏆 MY RECORDS'), RecordsScreen);
      await openAndBack(find.text('Privacy'), PrivacyScreen);
      // No server addresses on screen: just Online / Same Wi-Fi.
      expect(find.textContaining('Server: '), findsNothing);
      await tester.scrollUntilVisible(find.text('🌐 ONLINE'), -120, scrollable: find.byType(Scrollable).first);
      expect(find.text('📶 SAME WI-FI'), findsOneWidget);
      expect(find.text('Friends anywhere'), findsOneWidget);
    });
  }
}
