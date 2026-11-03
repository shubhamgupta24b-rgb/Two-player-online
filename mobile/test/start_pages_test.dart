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
import 'package:multiplayer_game/features/quick_play/quick_play_screen.dart';
import 'package:multiplayer_game/features/records/records_screen.dart';
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

Future<(AuthenticationManager, FakeSocket)> pumpApp(
    WidgetTester tester, Widget home,
    {Map<String, Object> prefs = const {},
    Size size = const Size(411, 914)}) async {
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
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('first launch: splash -> login -> home with your name',
      (tester) async {
    final (auth, socket) =
        await pumpApp(tester, const SplashScreen(minShow: Duration.zero));
    await tester.pump(const Duration(milliseconds: 400)); // the splash fades in
    expect(find.bySemanticsLabel('Party Games'), findsWidgets,
        reason: 'logo and name');
    expect(find.text('Party Games'), findsOneWidget);
    await bootSplash(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    expect(find.text("Who's playing?"), findsOneWidget);
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
    expect(find.bySemanticsLabel('Play'), findsWidgets);
    expect(auth.displayName, 'asha');
    expect(socket.connects.single, auth.token,
        reason: 'connects in the background');
  });

  testWidgets('returning player goes straight to home', (tester) async {
    final (_, socket) = await pumpApp(
        tester, const SplashScreen(minShow: Duration.zero),
        prefs: {'uid': 'u1', 'name': 'Ravi'});
    await bootSplash(tester);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsWidgets);
    expect(socket.connects, ['dev:u1:Ravi']);
  });

  for (final size in const [Size(320, 568), Size(411, 914)]) {
    testWidgets(
        'create room: pick a game, filter, players follow the game limits (${size.width.toInt()})',
        (tester) async {
      await pumpApp(tester, const CreateRoomScreen(), size: size);
      await tester.pump();
      expect(find.text('Create a room'), findsOneWidget);
      expect(find.text('Guess the Person (quiz)'), findsNothing);
      // Colour Clash is first and selected: up to 6 players.
      expect(find.bySemanticsLabel(RegExp('^Colour Riot, ')), findsOneWidget);
      await setPlayers(tester, 6);

      // Raja Mantri: exactly 4 players.
      await tester.tap(find.text('Chit Court').first);
      await tester.pump();
      // A room for 6 can still start with Raja Mantri's 4 players later: just a hint, not a block.
      expect(find.text('Needs 4 players. You can switch games in the room'),
          findsOneWidget);
      await setPlayers(tester, 4);
      expect(find.text('Can the Mantri catch the Chor?'), findsOneWidget);

      // Filter to action games.
      await tester.ensureVisible(find.text('Action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action'));
      await tester.pump();
      expect(find.text('Puck Rush'), findsOneWidget);
      expect(find.text('Token Rush'), findsNothing);
      await tester.tap(find.text('Puck Rush'));
      await tester.pump();
      expect(find.text('Create room'), findsOneWidget);
      final chips = find.ancestor(
          of: find.text('Action'), matching: find.byType(ListView));
      await tester.dragUntilVisible(
          find.text('All'), chips, const Offset(120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pump();
      expect(find.text('Colour Riot'), findsWidgets,
          reason: 'back to all games, from the top');
    });
  }

  for (final size in const [Size(320, 568), Size(411, 914), Size(800, 1280)]) {
    testWidgets(
        'home lays out and every section opens on ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      final (auth, _) = await pumpApp(tester, const HomeScreen(),
          prefs: {'uid': 'u1', 'name': 'A very long player name'}, size: size);
      await tester.runAsync(auth.restore);
      await tester.pump();
      expect(find.byType(LocalGamesHubScreen), findsOneWidget);

      Future<void> openAndBack(Finder target, Type page) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);
        Navigator.of(tester.element(find.byType(page))).pop();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.bySemanticsLabel('Rooms'));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      for (final (label, page) in const [
        ('Create room', CreateRoomScreen),
        ('Join room', JoinRoomScreen),
        ('Quick play', QuickPlayScreen)
      ]) {
        await openAndBack(find.text(label), page);
      }
      expect(find.textContaining('Server: '), findsNothing);
      expect(find.text('Same Wi-Fi'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Records'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordsScreen), findsOneWidget);
      await openAndBack(find.text('Privacy & your data'), PrivacyScreen);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Memory');
      await tester.pumpAndSettle();
      await openAndBack(find.text('Flip Twice'), LocalGameShell);
      await tester.enterText(find.byType(TextField), 'Raja Mantri');
      await tester.pumpAndSettle();
      await openAndBack(find.text('Chit Court'), RmcsMenuScreen);
    });
  }
}
