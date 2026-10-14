import 'package:shared_preferences/shared_preferences.dart';

/// Unlocked level for one game (or one difficulty), kept on this phone.
/// Level 1 is always open. Clearing level N unlocks N + 1.
class LevelProgress {
  static String _key(String id) => 'lvl_$id';

  static Future<int> unlocked(String id) async {
    try {
      return (await SharedPreferences.getInstance()).getInt(_key(id)) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  /// Records that [level] was finished. Returns the highest level now unlocked.
  static Future<int> markCleared(String id, int level) async {
    final next = level + 1;
    try {
      final p = await SharedPreferences.getInstance();
      final cur = p.getInt(_key(id)) ?? 1;
      final value = next > cur ? next : cur;
      await p.setInt(_key(id), value);
      return value;
    } catch (_) {
      return next;
    }
  }
}
