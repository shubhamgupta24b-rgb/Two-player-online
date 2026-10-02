import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Built-in default. Android emulator -> host machine; for phones build with
  // flutter build apk --dart-define=SERVER_URL=http://192.168.1.20:3000
  static const defaultServerUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'http://10.0.2.2:3000');

  /// The server in use: the player's saved choice (Home > Server), else the built-in default.
  static String serverUrl = defaultServerUrl;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      serverUrl = p.getString('server_url') ?? defaultServerUrl;
    } catch (_) {
      serverUrl = defaultServerUrl;
    }
  }

  /// Accepts "192.168.1.20:3000" or a full URL; returns the normalised URL, or null if invalid.
  static String? normalise(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return null;
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  static Future<void> save(String url) async {
    serverUrl = url;
    final p = await SharedPreferences.getInstance();
    await p.setString('server_url', url);
  }
}
