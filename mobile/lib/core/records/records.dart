import 'dart:convert';
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
class Records {
  static const _key = 'records';

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
  static Future<GameRecord?> add(String gameId, {required int score, bool won = false}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      final map = raw == null ? <String, dynamic>{} : (jsonDecode(raw) as Map).cast<String, dynamic>();
      final r = GameRecord.fromJson(map[gameId]);
      final next = GameRecord(played: r.played + 1, wins: r.wins + (won ? 1 : 0), best: score > r.best ? score : r.best);
      map[gameId] = next.toJson();
      await p.setString(_key, jsonEncode(map));
      return next;
    } catch (_) {
      return null;
    }
  }

  /// Wipes this phone's records (Privacy > Delete my data).
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    for (final k in p.getKeys().where((k) => k.startsWith('best_')).toList()) {
      await p.remove(k);
    }
  }
}
