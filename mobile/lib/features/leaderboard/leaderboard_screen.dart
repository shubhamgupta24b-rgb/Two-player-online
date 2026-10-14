import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/records/records.dart';
import '../../core/ui/tokens.dart';

const leaderboardCream = Color(0xFFF4EFE4);
const leaderboardInk = Color(0xFF1C1A17);

/// One ranked player. [wins] decides the order; [played] and [name] only break ties.
class BoardRow {
  final String name;
  final int wins;
  final int played;
  const BoardRow({required this.name, required this.wins, required this.played});
}

List<BoardRow> rankByWins(List<BoardRow> rows) {
  final copy = [...rows];
  copy.sort((a, b) {
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    final byPlayed = b.played.compareTo(a.played);
    if (byPlayed != 0) return byPlayed;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return copy;
}

/// Online leaderboard. Order is games won, then games played, then name.
/// A live "playing now" total is shown separately and does not change the order.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<BoardRow>? _rows;
  bool _fromPhone = false;
  int? _playingNow;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final socket = context.read<SocketManager>();
    final counts = await socket.request('online_counts');
    final board = await socket.request('leaderboard');
    if (!mounted) return;
    int? playing;
    if (counts['ok'] == true && counts['total'] is num) playing = (counts['total'] as num).toInt();
    final remote = _remoteRows(board);
    if (remote.isNotEmpty) {
      setState(() {
        _playingNow = playing;
        _fromPhone = false;
        _rows = rankByWins(remote);
      });
      return;
    }
    final local = await _phoneRow();
    if (!mounted) return;
    setState(() {
      _playingNow = playing;
      _fromPhone = local != null;
      _rows = local == null ? const [] : [local];
    });
  }

  List<BoardRow> _remoteRows(Map<String, dynamic> board) {
    if (board['ok'] != true) return const [];
    return rowsFromLeaderboardJson(board);
  }

  Future<BoardRow?> _phoneRow() async {
    final records = await Records.all();
    var played = 0, wins = 0;
    for (final r in records.values) {
      played += r.played;
      wins += r.wins;
    }
    if (played == 0 && wins == 0) return null;
    if (!mounted) return null;
    final name = context.read<AuthenticationManager>().displayName.trim();
    return BoardRow(name: name.isEmpty ? 'You' : name, wins: wins, played: played);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: leaderboardCream,
      body: SafeArea(
        child: rows == null
            ? const Center(child: Text('Loading scores', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: leaderboardInk)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: leaderboardInk),
                    ),
                    const Expanded(child: Text('Leaderboard', textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.display, fontSize: 28, color: leaderboardInk))),
                    const SizedBox(width: 48),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Ranked by games won', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF5C564C))),
                  const SizedBox(height: 14),
                  _PlayingNow(count: _playingNow),
                  const SizedBox(height: 16),
                  if (_fromPhone)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('Showing your wins saved on this phone. Other players appear when the server has their results.',
                          style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5C564C))),
                    ),
                  if (rows.isEmpty)
                    const _EmptyBoard()
                  else
                    for (var i = 0; i < rows.length; i++) ...[
                      _RankCard(place: i + 1, row: rows[i]),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
      ),
    );
  }
}

class _PlayingNow extends StatelessWidget {
  final int? count;
  const _PlayingNow({required this.count});

  @override
  Widget build(BuildContext context) {
    final n = count;
    final label = n == null ? 'Playing now unavailable' : '$n playing now';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF1F8A4C), borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        const Icon(Icons.circle, size: 10, color: Color(0xFFB6F5C8)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontFamily: Fonts.display, fontSize: 20, height: 1.1, color: Colors.white))),
      ]),
    );
  }
}

class _RankCard extends StatelessWidget {
  final int place;
  final BoardRow row;
  const _RankCard({required this.place, required this.row});

  Color get _tint => switch (place) {
        1 => const Color(0xFFFFD56A),
        2 => const Color(0xFFD7E2EA),
        3 => const Color(0xFFFFC4A8),
        _ => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: _tint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1C1A17), width: place <= 3 ? 2 : 1),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFF1C1A17), shape: BoxShape.circle),
          child: Text('$place', style: const TextStyle(fontFamily: Fonts.display, fontSize: 18, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Fonts.display, fontSize: 22, height: 1.05, color: leaderboardInk)),
            Text('${row.played} played', style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF5C564C))),
          ]),
        ),
        Text('${row.wins}', style: const TextStyle(fontFamily: Fonts.display, fontSize: 28, color: leaderboardInk)),
        const SizedBox(width: 4),
        const Text('wins', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF5C564C))),
      ]),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF1C1A17))),
      child: const Text('No wins yet. Finish a game and the ranking will start here.', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: leaderboardInk)),
    );
  }
}

/// Parses a server leaderboard payload the same way the screen does. Exposed for tests.
List<BoardRow> rowsFromLeaderboardJson(Object? raw) {
  final board = raw is String ? jsonDecode(raw) : raw;
  if (board is! Map || board['players'] is! List) return const [];
  return rankByWins([
    for (final row in board['players'] as List)
      if (row is Map)
        BoardRow(
          name: row['username']?.toString().trim() ?? '',
          wins: (row['wins'] as num?)?.toInt() ?? 0,
          played: (row['played'] as num?)?.toInt() ?? 0,
        ),
  ].where((r) => r.name.isNotEmpty).toList());
}
