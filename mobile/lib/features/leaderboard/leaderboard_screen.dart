import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/records/records.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/tokens.dart';
import '../home/home_chrome.dart';
import '../local_games/local_games_hub_screen.dart';

const leaderboardCream = Color(0xFFF4EFE4);
const leaderboardInk = Color(0xFF1C1A17);

/// Wins and games played for one game.
class GameTally {
  final int wins;
  final int played;
  final int losses;
  const GameTally({this.wins = 0, this.played = 0, this.losses = 0});
}

/// One ranked player. Wins come first, then win rate, then games played, then name.
class BoardRow {
  final String name;
  final int wins;
  final int played;
  final int losses;
  final Map<String, GameTally> games;
  const BoardRow({required this.name, required this.wins, required this.played, this.losses = 0, this.games = const {}});

  double get winRate => played == 0 ? 0 : wins / played;
}

List<BoardRow> rankByWins(List<BoardRow> rows) {
  final copy = [...rows];
  copy.sort((a, b) {
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    if (a.played > 0 && b.played > 0) {
      final byRate = (b.wins * a.played).compareTo(a.wins * b.played);
      if (byRate != 0) return byRate;
    }
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
  bool _error = false;
  String? _game;
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
        _error = false;
        _rows = rankByWins(remote);
      });
      return;
    }
    final seats = await _seatRows();
    if (!mounted) return;
    if (seats.isNotEmpty) {
      setState(() {
        _playingNow = playing;
        _fromPhone = true;
        _error = false;
        _rows = rankByWins(seats);
      });
      return;
    }
    final local = await _phoneRow();
    if (!mounted) return;
    setState(() {
      _playingNow = playing;
      _fromPhone = local != null;
      _error = local == null && board['ok'] != true;
      _rows = local == null ? const [] : [local];
    });
  }

  List<BoardRow> _remoteRows(Map<String, dynamic> board) {
    if (board['ok'] != true) return const [];
    return rowsFromLeaderboardJson(board);
  }

  Future<List<BoardRow>> _seatRows() async {
    final seats = await Records.standings();
    return [
      for (final seat in seats)
        BoardRow(
          name: seat.name,
          wins: seat.wins,
          played: seat.played,
          losses: seat.losses,
          games: {
            for (final entry in seat.games.entries)
              entry.key: GameTally(wins: entry.value.wins, played: entry.value.played),
          },
        ),
    ];
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
    return BoardRow(
      name: name.isEmpty ? 'You' : name,
      wins: wins,
      played: played,
      games: {
        for (final entry in records.entries)
          if (entry.value.played > 0) entry.key: GameTally(wins: entry.value.wins, played: entry.value.played),
      },
    );
  }

  List<BoardRow> _visible(List<BoardRow> rows) {
    final id = _game;
    if (id == null) return rows;
    return rankByWins([
      for (final row in rows)
        if (row.games[id] case final tally?)
          if (tally.played > 0) BoardRow(name: row.name, wins: tally.wins, played: tally.played, losses: tally.losses),
    ]);
  }

  List<String> _gameIds(List<BoardRow> rows) {
    final ids = <String>{for (final row in rows) ...row.games.keys};
    final list = ids.toList()..sort();
    return list;
  }

  String _gameTitle(String id) {
    for (final game in listedGames()) {
      if (game.id == id) return game.title;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return ListenableBuilder(
      listenable: AppSettings.homeLight,
      builder: (context, _) {
        final colors = HomeColors.of(context);
        final shown = rows == null ? const <BoardRow>[] : _visible(rows);
        final gameIds = rows == null ? const <String>[] : _gameIds(rows);
        return Scaffold(
          backgroundColor: colors.bg,
          body: SafeArea(
            child: rows == null
                ? Center(child: Text('Loading scores', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: colors.text)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      Row(children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                        ),
                        Expanded(child: Text('Leaderboard', textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.display, fontSize: 28, color: colors.text))),
                        const SizedBox(width: 48),
                      ]),
                      const SizedBox(height: 6),
                      Text('Ranked by games won', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: colors.muted)),
                      const SizedBox(height: 14),
                      _PlayingNow(count: _playingNow),
                      const SizedBox(height: 16),
                      if (_fromPhone)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text('Showing your wins saved on this phone. Other players appear when the server has their results.',
                              style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w700, color: colors.muted)),
                        )
                      else if (rows.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text('Online rankings from finished matches.', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w700, color: colors.muted)),
                        ),
                      if (_error)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Expanded(child: Text('Could not reach the server.', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w700, color: colors.muted))),
                            TextButton(onPressed: _load, child: Text('Try again', style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w800, color: colors.blue))),
                          ]),
                        ),
                      if (gameIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              _GameChip(label: 'All', selected: _game == null, onTap: () => setState(() => _game = null)),
                              for (final id in gameIds) _GameChip(label: _gameTitle(id), selected: _game == id, onTap: () => setState(() => _game = id)),
                            ]),
                          ),
                        ),
                      if (shown.isEmpty)
                        const _EmptyBoard()
                      else
                        for (var i = 0; i < shown.length; i++) ...[
                          _RankCard(place: i + 1, row: shown[i]),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _GameChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GameChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = HomeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.blue : colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? colors.blue : colors.border),
          ),
          child: Text(label, style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : colors.text)),
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
            if (row.played > 0)
              Text('${(row.winRate * 100).round()}% win rate', style: const TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5C564C))),
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

Map<String, GameTally> _gamesFromJson(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is Map)
        entry.key.toString(): GameTally(
          wins: ((entry.value as Map)['wins'] as num?)?.toInt() ?? ((entry.value as Map)['w'] as num?)?.toInt() ?? 0,
          played: ((entry.value as Map)['played'] as num?)?.toInt() ?? ((entry.value as Map)['p'] as num?)?.toInt() ?? 0,
          losses: ((entry.value as Map)['losses'] as num?)?.toInt() ?? ((entry.value as Map)['l'] as num?)?.toInt() ?? 0,
        ),
  };
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
          played: (row['played'] as num?)?.toInt() ?? (row['gamesPlayed'] as num?)?.toInt() ?? 0,
          losses: (row['losses'] as num?)?.toInt() ?? 0,
          games: _gamesFromJson(row['games']),
        ),
  ].where((r) => r.name.isNotEmpty).toList());
}
