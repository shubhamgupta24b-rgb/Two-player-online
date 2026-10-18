/// All Games columns.
///
/// From 340dp, three columns so each complete pair of rows is six cards.
/// Narrower widths use two columns so the titles stay readable.
/// Wide layouts use six columns, one full batch per row.
int allGamesColumns(double width) {
  if (width >= 900) return 6;
  if (width >= 340) return 3;
  return 2;
}

const int allGamesBatchRows = 2;

int allGamesBatchSize(double width) => allGamesColumns(width) * allGamesBatchRows;

/// How many complete six-card (or width-adjusted) batches [count] fills.
int completeGameBatches(int count, double width) {
  final size = allGamesBatchSize(width);
  if (size <= 0) return 0;
  return count ~/ size;
}

/// Shown until this phone or the server has play data. These are real games, not a fixed ranking.
const trendingFallbackIds = ['memory', 'smash_karts', 'ludo', 'air_hockey'];

/// Home trending grid is always two rows of two.
const trendingSlots = 4;

/// Players currently in a live room, from `online_counts`. Unknown ids and empty rooms are dropped.
Map<String, int> livePlayersFromCounts(Map<String, dynamic>? payload, Set<String> known) {
  final rows = trendingIdsFromCounts(payload, known);
  if (payload == null || payload['ok'] != true || payload['games'] is! List) return const {};
  final counts = <String, int>{};
  for (final item in payload['games'] as List) {
    if (item is! Map) continue;
    final id = item['id']?.toString() ?? '';
    final playing = (item['playing'] as num?)?.toInt() ?? 0;
    if (playing <= 0 || !known.contains(id) || !rows.contains(id)) continue;
    counts[id] = playing;
  }
  return counts;
}

/// Rank by live players, then lifetime plays, then how recently the game was opened.
/// A recent play is worth more than an old one. Ties break by game id.
/// Fewer than [trendingSlots] scored games are filled from [fallback], which is only a
/// stand-in until real plays exist. The result is never longer than [trendingSlots].
List<String> rankTrending({
  required Set<String> known,
  Map<String, int> plays = const {},
  List<String> recent = const [],
  Map<String, int> live = const {},
  List<String> fallback = trendingFallbackIds,
}) {
  final scores = <String, int>{};
  void bump(String id, int amount) {
    if (amount <= 0 || !known.contains(id)) return;
    scores[id] = (scores[id] ?? 0) + amount;
  }

  for (final entry in plays.entries) {
    bump(entry.key, entry.value);
  }
  for (var i = 0; i < recent.length; i++) {
    bump(recent[i], recent.length - i);
  }
  for (final entry in live.entries) {
    bump(entry.key, entry.value * 8);
  }
  final ranked = scores.entries.toList()
    ..sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return a.key.compareTo(b.key);
    });
  final out = [for (final row in ranked.take(trendingSlots)) row.key];
  if (out.isEmpty) {
    return [for (final id in fallback) if (known.contains(id)) id].take(trendingSlots).toList();
  }
  for (final id in fallback) {
    if (out.length >= trendingSlots) break;
    if (known.contains(id) && !out.contains(id)) out.add(id);
  }
  return out;
}

/// Games people are actually in, from the server `online_counts` payload.
/// Empty when the payload is missing, offline, or has no known game with players.
List<String> trendingIdsFromCounts(Map<String, dynamic>? payload, Set<String> known) {
  if (payload == null || payload['ok'] != true) return const [];
  final games = payload['games'];
  if (games is! List) return const [];
  final rows = <(String, int)>[];
  for (final item in games) {
    if (item is! Map) continue;
    final id = item['id']?.toString() ?? '';
    final playing = (item['playing'] as num?)?.toInt() ?? 0;
    if (id.isEmpty || playing <= 0 || !known.contains(id)) continue;
    rows.add((id, playing));
  }
  rows.sort((a, b) {
    final byCount = b.$2.compareTo(a.$2);
    if (byCount != 0) return byCount;
    return a.$1.compareTo(b.$1);
  });
  return [for (final row in rows.take(8)) row.$1];
}
