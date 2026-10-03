import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/multiplayer_ui/widgets/mp_ui.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: buildMpTheme(), home: Scaffold(body: child));

  testWidgets('MenuCard shows title/subtitle and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(MenuCard(
      icon: Icons.add,
      title: 'Create Room',
      subtitle: 'Invite friends',
      color: AppColors.primary,
      onTap: () => taps++,
    )));
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('Invite friends'), findsOneWidget);
    await tester.tap(find.text('Create Room'));
    expect(taps, 1);
  });

  testWidgets('BusyButton shows spinner and is disabled while busy', (tester) async {
    await tester.pumpWidget(wrap(BusyButton(label: 'JOIN ROOM', busy: true, onPressed: () {})));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('JOIN ROOM'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('PlayerAvatar shows uppercase initial', (tester) async {
    await tester.pumpWidget(wrap(const PlayerAvatar(name: 'shivani', color: Colors.red)));
    expect(find.text('S'), findsOneWidget);
  });
}
