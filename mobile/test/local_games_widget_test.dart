import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

/// Games that end on their own (timer) within about 30 seconds. (Snake Duel with nobody
/// steering is a tie every round, which correctly never ends the match.)
const selfFinishing = {'crush_it', 'basketball_hoops', 'fruit_duel', 'paint_fight'};

/// Opens a game, optionally picks the player count, plays it for a while with taps
/// all over the screen, and checks for layout overflow (any overflow fails the test).
/// Self-finishing games are played to the result screen and restarted with Play Again.
Future<void> playThrough(WidgetTester tester, LocalGameInfo game, Size size, int players) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: LocalGameShell(game: game)));
  expect(find.text(game.title.toUpperCase()), findsOneWidget);
  if (players > 2) {
    await tapText(tester, '$players');
    await tester.pump();
  }
  await tapText(tester, 'PLAY');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2500)); // 3-2-1
  await tester.pump(const Duration(milliseconds: 300));

  // Tap around the screen: both halves, both sides.
  for (var i = 0; i < 8; i++) {
    await tester.tapAt(Offset(size.width * (0.15 + 0.23 * (i % 4)), size.height * (i.isEven ? 0.8 : 0.2)));
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(find.byType(PauseButton), findsWidgets, reason: 'a way out is always on screen');

  if (!selfFinishing.contains(game.id)) {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    return;
  }
  await tester.pump(const Duration(seconds: 31)); // longer than any timed game
  await tester.pump(const Duration(seconds: 1)); // result delay
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.textContaining('WINS!').evaluate().isNotEmpty || find.text('DRAW!').evaluate().isNotEmpty, isTrue);
  expect(find.textContaining('MATCHES WON'), findsOneWidget);

  await tapText(tester, 'PLAY AGAIN');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2800));
  expect(find.text('PLAY AGAIN'), findsNothing, reason: 'new match running');

  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  const sizes = {'small phone': Size(320, 568), 'phone': Size(411, 914), 'tablet': Size(800, 1280)};

  testWidgets('hub lists all games with their player counts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LocalGamesHubScreen()));
    for (final t in ['Guess the Person', ...localGames.map((g) => g.title)]) {
      await tester.scrollUntilVisible(find.text(t), 100);
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('👥 2–6').evaluate(), isNotEmpty);
  });

  testWidgets('player count picker only offers what a game supports', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LocalGameShell(game: localGames.firstWhere((g) => g.id == 'math_duel'))));
    expect(find.text('PLAYERS'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsNothing);
    await tester.pumpWidget(MaterialApp(home: LocalGameShell(game: localGames.firstWhere((g) => g.id == 'tic_tac_toe'))));
    expect(find.text('PLAYERS'), findsNothing, reason: '2 players only');
  });

  for (final size in sizes.entries) {
    for (final game in localGames) {
      testWidgets('${game.title} plays through on ${size.key}', (tester) => playThrough(tester, game, size.value, 2));
    }
  }

  // Every player count on a small and a normal phone for the multi-player games.
  for (final game in localGames.where((g) => g.maxPlayers > 2)) {
    for (var n = 3; n <= game.maxPlayers; n++) {
      for (final size in [sizes['small phone']!, sizes['phone']!]) {
        testWidgets('${game.title} with $n players on ${size.width.toInt()}x${size.height.toInt()}', (tester) => playThrough(tester, game, size, n));
      }
    }
  }
}
