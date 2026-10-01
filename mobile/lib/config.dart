class AppConfig {
  // Android emulator -> host machine. For a physical device pass your PC's LAN IP:
  // flutter run --dart-define=SERVER_URL=http://192.168.1.20:3000
  static const serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'http://10.0.2.2:3000');
}
