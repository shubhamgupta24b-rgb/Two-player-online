import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/authentication_manager.dart';
import '../../../core/network/socket_manager.dart';
import '../widgets/mp_ui.dart';
import 'mp_create_room_screen.dart';
import 'mp_join_room_screen.dart';

/// Entry point of the simple multiplayer UI. Push it from anywhere:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const MpHomeScreen()));
class MpHomeScreen extends StatelessWidget {
  const MpHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketManager>();
    final name = context.watch<AuthenticationManager>().displayName;
    void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Theme(
      data: buildMpTheme(),
      child: Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.isEmpty ? 'Hey there' : 'Hey, $name',
                          style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                      const SizedBox(height: 2),
                      const Text('Multiplayer', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: socket.connected,
                    builder: (_, online, __) => online
                        ? const StatusPill('ONLINE', color: AppColors.success, icon: Icons.circle)
                        : const StatusPill('OFFLINE', color: AppColors.muted, icon: Icons.circle_outlined),
                  ),
                ]),
                const SizedBox(height: 28),
                const SectionLabel('Play with friends'),
                MenuCard(
                  icon: Icons.add_circle_rounded,
                  title: 'Create Room',
                  subtitle: 'Pick a game and invite 1–3 friends',
                  color: AppColors.primary,
                  onTap: () => go(const MpCreateRoomScreen()),
                ),
                const SizedBox(height: 12),
                MenuCard(
                  icon: Icons.login_rounded,
                  title: 'Join Room',
                  subtitle: 'Enter the code your friend shared',
                  color: AppColors.accent,
                  onTap: () => go(const MpJoinRoomScreen()),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: socket.connected,
                  builder: (_, online, __) => online
                      ? const SizedBox.shrink()
                      : const Padding(
                          padding: EdgeInsets.only(top: 12, left: 4, right: 4),
                          child: Text('Not connected to the game server — rooms will work once it connects.',
                              style: TextStyle(color: AppColors.warning, fontSize: 12)),
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
