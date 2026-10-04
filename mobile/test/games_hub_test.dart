import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpHub(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(const MaterialApp(home: LocalGamesHubScreen()));
  await tester.pumpAndSettle();
}

/// The sideways row of category chips.
Finder chips() => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

void main() {
  testWidgets('search finds games by name or description', (tester) async {
    await pumpHub(tester);
    await tester.enterText(find.byType(TextField), 'ludo');
    await tester.pump();
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('Bingo'), findsNothing);
    await tester.enterText(find.byType(TextField), 'watermelon'); // in Fruit Merge's description
    await tester.pump();
    expect(find.text('Fruit Merge'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.textContaining('No games match'), findsOneWidget);
  });

  testWidgets('categories: solo shows only solo games, cards only card games', (tester) async {
    await pumpHub(tester);
    // The chips scroll sideways: swipe to the last one.
    await tester.scrollUntilVisible(find.text('🧍 Solo'), 150, scrollable: chips());
    await tester.tap(find.text('🧍 Solo'));
    await tester.pump();
    expect(find.text('👥 PLAY TOGETHER'), findsNothing);
    expect(find.text('🧍 SOLO GAMES'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('🃏 Cards'), -150, scrollable: chips());
    await tester.tap(find.text('🃏 Cards'));
    await tester.pump();
    expect(find.text('Colour Clash'), findsOneWidget);
    expect(find.text('Ludo'), findsNothing);
  });

  testWidgets('long-press stars a favourite; the Favourites chip lists it', (tester) async {
    await pumpHub(tester);
    await tester.tap(find.text('⭐ Favourites'));
    await tester.pump();
    expect(find.textContaining('No favourites yet'), findsOneWidget);
    await tester.tap(find.text('✨ All'));
    await tester.pump();
    await tester.longPress(find.text('Ludo'));
    await tester.pumpAndSettle();
    expect(find.text('⭐'), findsOneWidget);
    await tester.tap(find.text('⭐ Favourites'));
    await tester.pump();
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('Colour Clash'), findsNothing);
  });

  testWidgets('recently played games come first', (tester) async {
    await pumpHub(tester, {'recent_games': ['bingo', 'ludo']});
    expect(find.text('▶ RECENTLY PLAYED'), findsOneWidget);
    expect(find.text('▶ PLAY'), findsNWidgets(2));
  });
}
