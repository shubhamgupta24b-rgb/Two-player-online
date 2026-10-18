import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/network/socket_manager.dart';
import 'package:multiplayer_game/core/room/room_manager.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/features/leaderboard/leaderboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedSocket extends SocketManager {
  final Map<String, Map<String, dynamic>> replies;
  _ScriptedSocket(this.replies);

  @override
  Future<Map<String, dynamic>> request(String event, [Map<String, dynamic>? payload]) async {
    return replies[event] ?? {'ok': false, 'error': 'OFFLINE'};
  }
}

Future<void> _pumpBoard(WidgetTester tester, {required SocketManager socket, required AuthenticationManager auth}) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      Provider<SocketManager>.value(value: socket),
      ChangeNotifierProvider.value(value: RoomManager(socket)),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const LeaderboardScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('rankByWins puts the most wins first, then win rate, then games played, then name', () {
    final ranked = rankByWins(const [
      BoardRow(name: 'Zed', wins: 1, played: 1),
      BoardRow(name: 'amy', wins: 0, played: 9),
      BoardRow(name: 'Ned', wins: 1, played: 4),
      BoardRow(name: 'Bea', wins: 1, played: 4),
    ]);
    expect(ranked.map((r) => r.name).toList(), ['Zed', 'Bea', 'Ned', 'amy']);
  });

  test('rowsFromLeaderboardJson ranks by wins and drops blank names', () {
    final rows = rowsFromLeaderboardJson(jsonEncode({
      'players': [
        {'username': 'Bo', 'wins': 2, 'played': 2},
        {'username': '  ', 'wins': 99, 'played': 99},
        {'username': 'Ada', 'wins': 2, 'played': 5},
      ],
    }));
    expect(rows.map((r) => r.name).toList(), ['Bo', 'Ada']);
    expect(rows.map((r) => r.wins).toList(), [2, 2]);
  });

  testWidgets('offline leaderboard shows only this phone and no invented players', (tester) async {
    SharedPreferences.setMockInitialValues({
      'uid': 'u1',
      'name': 'Asha',
      'records': jsonEncode({
        'memory': {'p': 4, 'w': 2, 'b': 10},
        'ludo': {'p': 1, 'w': 1, 'b': 1},
      }),
    });
    final auth = AuthenticationManager();
    await auth.restore();
    await _pumpBoard(tester, socket: _ScriptedSocket(const {}), auth: auth);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5 played'), findsOneWidget);
    expect(find.text('Playing now unavailable'), findsOneWidget);
    expect(find.textContaining('saved on this phone'), findsOneWidget);
    expect(find.textContaining('8,472'), findsNothing);
  });

  testWidgets('a server board is ordered by wins and shows who is playing now', (tester) async {
    SharedPreferences.setMockInitialValues({'uid': 'u1', 'name': 'Asha'});
    final auth = AuthenticationManager();
    await auth.restore();
    await _pumpBoard(
      tester,
      auth: auth,
      socket: _ScriptedSocket({
        'online_counts': {
          'ok': true,
          'total': 4,
          'games': [
            {'id': 'memory', 'playing': 2},
          ],
        },
        'leaderboard': {
          'ok': true,
          'source': 'database',
          'players': [
            {'username': 'Bo', 'wins': 1, 'played': 3},
            {'username': 'Ada', 'wins': 4, 'played': 4},
          ],
        },
      }),
    );
    expect(find.text('4 playing now'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.textContaining('saved on this phone'), findsNothing);
    final ada = tester.getTopLeft(find.text('Ada')).dy;
    final bo = tester.getTopLeft(find.text('Bo')).dy;
    expect(ada, lessThan(bo));
  });

  testWidgets('an empty phone with no server results stays empty', (tester) async {
    SharedPreferences.setMockInitialValues({'uid': 'u1', 'name': 'Asha'});
    final auth = AuthenticationManager();
    await auth.restore();
    await _pumpBoard(tester, socket: _ScriptedSocket(const {}), auth: auth);
    expect(find.textContaining('No wins yet'), findsOneWidget);
    expect(find.text('Asha'), findsNothing);
  });
}
