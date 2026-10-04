import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'core/audio/game_audio.dart';
import 'core/auth/authentication_manager.dart';
import 'core/lan/lan_host.dart';
import 'core/network/socket_manager.dart';
import 'core/room/room_manager.dart';
import 'core/session/game_session_manager.dart';
import 'core/ui/app_flavor.dart';
import 'core/ui/app_ui.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await GameAudio.init();
  // This phone was hosting games for the others (hotspot, no internet): start its server again.
  if (AppConfig.hosting) {
    try {
      await LanHost.start();
    } catch (_) {
      await AppConfig.useOnline(); // the port is busy or the network is gone: fall back to online
    }
  }
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final auth = AuthenticationManager();
  final socket = SocketManager();
  late final RoomManager rooms = RoomManager(socket);
  late final GameSessionManager session = GameSessionManager(socket);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider.value(value: socket),
        ChangeNotifierProvider.value(value: rooms),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
