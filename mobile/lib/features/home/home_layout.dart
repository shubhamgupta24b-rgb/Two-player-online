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

/// Shown when the server has no live rooms. These are real games, not ranked.
const trendingFallbackIds = ['memory', 'smash_karts', 'ludo', 'air_hockey'];

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
