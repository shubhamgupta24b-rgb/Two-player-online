import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

/// Plays every timed game end to end (with some taps) at three screen sizes,
/// checking for layout overflow and that the result screen and Play Again work.
void main() {
  const sizes = {'small phone': Size(320, 568), 'phone': Size(411, 914), 'tablet': Size(800, 1280)};

  testWidgets('hub lists all six games', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LocalGamesHubScreen()));
    for (final t in ['Guess the Person', 'Crush It', 'Basketball Hoops', 'Fruit Duel', 'Memory', 'Paint Fight']) {
      await tester.scrollUntilVisible(find.text(t), 100);
      expect(find.text(t), findsOneWidget);
    }
  });

  for (final size in sizes.entries) {
    for (final game in localGames) {
      testWidgets('${game.title} plays through on ${size.key}', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(home: LocalGameShell(game: game)));
        expect(find.text(game.title.toUpperCase()), findsOneWidget);
        await tapText(tester, 'PLAY');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2500)); // 3-2-1
        await tester.pump(const Duration(milliseconds: 300));

        // Tap around both halves of the screen a few times.
        final s = tester.view.physicalSize;
        for (var i = 0; i < 6; i++) {
          await tester.tapAt(Offset(s.width * (0.3 + 0.2 * (i % 3)), s.height * (i.isEven ? 0.75 : 0.25)));
          await tester.pump(const Duration(milliseconds: 600));
        }

        if (game.id == 'memory') {
          expect(find.textContaining("'S TURN").evaluate().isNotEmpty || find.text('NO MATCH…').evaluate().isNotEmpty, isTrue);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
          return;
        }

        await tester.pump(const Duration(seconds: 31)); // longer than any game
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
      });
    }
  }
}
