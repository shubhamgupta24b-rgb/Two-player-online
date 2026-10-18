import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This phone's player's record in one game.
class GameRecord {
  final int played;
  final int wins;
  final int best; // highest score
  const GameRecord({this.played = 0, this.wins = 0, this.best = 0});

  Map<String, int> toJson() => {'p': played, 'w': wins, 'b': best};
  static GameRecord fromJson(Object? j) {
    final m = j is Map ? j : const {};
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return GameRecord(played: n('p'), wins: n('w'), best: n('b'));
  }
}

/// Personal records kept only on this phone (nothing is sent anywhere): games played,
/// wins and best score per game. Solo games also keep their older `best_<id>` value.
/// One named player on this phone. [games] is per game id.
class LocalStanding {
  final String name;
  final int wins;
  final int played;
  final int losses;
  final Map<String, GameRecord> games;
  const LocalStanding({required this.name, this.wins = 0, this.played = 0, this.losses = 0, this.games = const {}});

  double get winRate => played == 0 ? 0 : wins / played;
}

class Records {
  static const _key = 'records';
  static const _recentKey = 'recent_games';
  static const _favKey = 'favourite_games';
  static const _boardKey = 'local_board';
  static const _matchKey = 'recorded_match_ids';

  /// Bumps when a finished match is stored, so the home trending grid can refresh.
  static final revision = ValueNotifier<int>(0);

  /// Games played most recently on this phone, newest first.
  static Future<List<String>> recent() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_recentKey) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Games starred in the games list.
  static Future<Set<String>> favourites() async {
    try {
      return {...(await SharedPreferences.getInstance()).getStringList(_favKey) ?? const <String>[]};
    } catch (_) {
      return {};
    }
  }

  /// Stars or unstars a game; returns the new set.
  static Future<Set<String>> toggleFavourite(String id) async {
    final favs = await favourites();
    if (!favs.remove(id)) favs.add(id);
    try {
      await (await SharedPreferences.getInstance()).setStringList(_favKey, favs.toList());
    } catch (_) {}
    return favs;
  }

  static Future<Map<String, GameRecord>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      final map = raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map).cast<String, dynamic>();
      final out = {for (final e in map.entries) e.key: GameRecord.fromJson(e.value)};
      // Solo bests saved before records existed.
      for (final k in p.getKeys().where((k) => k.startsWith('best_'))) {
        final id = k.substring(5);
        final old = p.getInt(k) ?? 0;
        final r = out[id] ?? const GameRecord();
        if (old > r.best) out[id] = GameRecord(played: r.played, wins: r.wins, best: old);
      }
      return out;
    } catch (_) {
      return {}; // no storage (tests): nothing recorded
    }
  }

  /// Adds one finished game. [score] counts towards the best score; [won] towards wins.
  /// The same [matchId] is stored once. A second call does not add another play.
  static Future<GameRecord?> add(String gameId, {required int score, bool won = false, String? matchId}) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (matchId != null && !await _claimMatch(p, 'record:$matchId')) return GameRecord.fromJson(_map(p)[gameId]);
      final raw = p.getString(_key);
      final map = raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map).cast<String, dynamic>();
      final r = GameRecord.fromJson(map[gameId]);
      final next = GameRecord(played: r.played + 1, wins: r.wins + (won ? 1 : 0), best: score > r.best ? score : r.best);
      map[gameId] = next.toJson();
      await p.setString(_key, jsonEncode(map));
      // Recently played, newest first.
      final recent = (p.getStringList(_recentKey) ?? [])..remove(gameId);
      await p.setStringList(_recentKey, [gameId, ...recent].take(10).toList());
      revision.value++;
      return next;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _map(SharedPreferences p) {
    final raw = p.getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  /// True the first time [id] is seen. Later calls are ignored so one match cannot be counted twice.
  static Future<bool> _claimMatch(SharedPreferences p, String id) async {
    final seen = p.getStringList(_matchKey) ?? <String>[];
    if (seen.contains(id)) return false;
    final next = [...seen, id];
    await p.setStringList(_matchKey, next.length > 300 ? next.sublist(next.length - 300) : next);
    return true;
  }

  /// Records every named seat of one finished same-device match.
  /// A draw (nobody won) still counts as played and does not add a win or a loss.
  /// Returns false when [matchId] was already recorded or the match had no seats.
  static Future<bool> noteSeats({
    required String matchId,
    required String gameId,
    required List<({String name, bool win, bool loss})> seats,
  }) async {
    final named = [for (final seat in seats) if (seat.name.trim().isNotEmpty) (name: seat.name.trim(), win: seat.win, loss: seat.loss && !seat.win)];
    if (named.isEmpty) return false;
    try {
      final p = await SharedPreferences.getInstance();
      if (!await _claimMatch(p, 'seats:$matchId')) return false;
      final board = _boardMap(p);
      for (final seat in named) {
        final row = Map<String, dynamic>.from((board[seat.name] as Map?) ?? const {});
        final games = Map<String, dynamic>.from((row['games'] as Map?) ?? const {});
        final game = Map<String, dynamic>.from((games[gameId] as Map?) ?? const {});
        int n(Map source, String key) => (source[key] as num?)?.toInt() ?? 0;
        row['wins'] = n(row, 'wins') + (seat.win ? 1 : 0);
        row['played'] = n(row, 'played') + 1;
        row['losses'] = n(row, 'losses') + (seat.loss ? 1 : 0);
        game['w'] = n(game, 'w') + (seat.win ? 1 : 0);
        game['p'] = n(game, 'p') + 1;
        game['l'] = n(game, 'l') + (seat.loss ? 1 : 0);
        games[gameId] = game;
        row['games'] = games;
        board[seat.name] = row;
      }
      await p.setString(_boardKey, jsonEncode(board));
      revision.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _boardMap(SharedPreferences p) {
    final raw = p.getString(_boardKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  /// Named results saved on this phone. Empty until a finished match records a winner or a draw.
  static Future<List<LocalStanding>> standings() async {
    try {
      final board = _boardMap(await SharedPreferences.getInstance());
      return [
        for (final entry in board.entries)
          if (entry.value is Map)
            LocalStanding(
              name: entry.key,
              wins: ((entry.value as Map)['wins'] as num?)?.toInt() ?? 0,
              played: ((entry.value as Map)['played'] as num?)?.toInt() ?? 0,
              losses: ((entry.value as Map)['losses'] as num?)?.toInt() ?? 0,
              games: {
                for (final game in (((entry.value as Map)['games'] as Map?) ?? const {}).entries)
                  if (game.value is Map)
                    game.key.toString(): GameRecord(
                      played: ((game.value as Map)['p'] as num?)?.toInt() ?? 0,
                      wins: ((game.value as Map)['w'] as num?)?.toInt() ?? 0,
                    ),
              },
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Wipes this phone's records (Privacy > Delete my data).
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    await p.remove(_recentKey);
    await p.remove(_favKey);
    await p.remove(_boardKey);
    await p.remove(_matchKey);
    for (final k in p.getKeys().where((k) => k.startsWith('best_')).toList()) {
      await p.remove(k);
    }
  }
}
