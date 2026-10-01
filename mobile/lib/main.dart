import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth/authentication_manager.dart';
import 'core/network/socket_manager.dart';
import 'core/room/room_manager.dart';
import 'core/session/game_session_manager.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        title: 'Party Games',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF6C5CE7), brightness: Brightness.dark, useMaterial3: true),
        home: const SplashScreen(),
      ),
    );
  }
}
