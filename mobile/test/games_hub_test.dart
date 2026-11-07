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

/// Picks [label] from the Game type dropdown on the Play tab.
Future<void> pickFilter(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('gameFilter')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search finds games by name or description', (tester) async {
    await pumpHub(tester);
    await tester.enterText(find.byType(TextField), 'ludo');
    await tester.pump();
    expect(find.text('Token Rush'), findsOneWidget);
    expect(find.text('Line Caller'), findsNothing);
    await tester.enterText(find.byType(TextField), 'watermelon'); // in Fruit Merge's description
    await tester.pump();
    expect(find.text('Juicebox'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.textContaining('No games match'), findsOneWidget);
  });

  testWidgets('categories: solo shows only solo games, cards only card games', (tester) async {
    await pumpHub(tester);
    await pickFilter(tester, 'Solo');
    expect(find.text('Play together'), findsNothing);
    expect(find.text('Double Up'), findsOneWidget);
    expect(find.text('Token Rush'), findsNothing);
    await pickFilter(tester, 'Cards');
    expect(find.text('Colour Riot'), findsOneWidget);
    expect(find.text('Token Rush'), findsNothing);
  });

  testWidgets('long-press stars a favourite; the Favourites chip lists it', (tester) async {
    await pumpHub(tester);
    await pickFilter(tester, 'Favourites');
    expect(find.textContaining('No favourites yet'), findsOneWidget);
    await pickFilter(tester, 'All');
    await tester.ensureVisible(find.text('Token Rush'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Token Rush'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Unstar Token Rush'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await pickFilter(tester, 'Favourites');
    expect(find.text('Token Rush'), findsOneWidget);
    expect(find.text('Colour Riot'), findsNothing);
  });

  testWidgets('recently played games come first', (tester) async {
    await pumpHub(tester, {'recent_games': ['bingo', 'ludo']});
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Play .* again\$')), findsNWidgets(2));
  });
}
