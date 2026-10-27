import 'package:flutter/material.dart';
import '../../core/ui/app_ui.dart';
import '../../core/ui/app_flavor.dart';
import '../local_games/local_games_hub_screen.dart';
import '../home/home_screen.dart';

/// Minimal clay-style entry screen: the only two choices are online play and
/// offline same-device play. The detailed choices are shown after tapping.
class PlayModeScreen extends StatelessWidget {
  const PlayModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flat = flatStyle;
    final ink = flat ? FlatPalette.ink : Colors.white;
    final muted = flat ? FlatPalette.inkMuted : Colors.white70;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLogo(size: 132),
                    const SizedBox(height: 18),
                    Text('Two Player Games', textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Lilita One', fontSize: 34, color: ink)),
                    const SizedBox(height: 8),
                    Text('Choose how you want to play', textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: muted)),
                    const SizedBox(height: 32),
                    _ModeCard(
                      icon: Icons.public_rounded,
                      title: 'Play Online',
                      subtitle: 'Play with friends anywhere',
                      gradient: const [Color(0xFF4C8DFF), Color(0xFF2864E8)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineModeScreen())),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      icon: Icons.phone_android_rounded,
                      title: 'Play Offline',
                      subtitle: 'Two players on the same phone',
                      gradient: const [Color(0xFFFF9CC7), Color(0xFFEE6E9C)],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalGamesHubScreen())),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Connection choice shown after tapping Play Online.
class OnlineModeScreen extends StatelessWidget {
  const OnlineModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flat = flatStyle;
    final ink = flat ? FlatPalette.ink : Colors.white;
    final muted = flat ? FlatPalette.inkMuted : Colors.white70;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Align(alignment: Alignment.centerLeft, child: IconButton(
                    tooltip: 'Back', onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: ink))),
                  const AppLogo(size: 92),
                  const SizedBox(height: 12),
                  Text('Play Online', style: TextStyle(fontFamily: 'Lilita One', fontSize: 30, color: ink)),
                  const SizedBox(height: 8),
                  Text('Choose how to connect with other players', textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
                  const SizedBox(height: 28),
                  _ModeCard(
                    icon: Icons.public_rounded,
                    title: 'Online',
                    subtitle: 'Play through the internet',
                    gradient: const [Color(0xFF4C8DFF), Color(0xFF2864E8)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                  ),
                  const SizedBox(height: 16),
                  _ModeCard(
                    icon: Icons.wifi_rounded,
                    title: 'Same Host',
                    subtitle: 'Use one phone hotspot or the same Wi-Fi',
                    gradient: const [Color(0xFFFFB86B), Color(0xFFF18B45)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen(openSameHostOnStart: true))),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _ModeCard({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(28),
    child: InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x1A566080), blurRadius: 22, offset: Offset(0, 8))],
        ),
        child: Row(children: [
          Container(width: 68, height: 68,
            decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x22334466), blurRadius: 8, offset: Offset(0, 4))]),
            child: Icon(icon, size: 34, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Lilita One', fontSize: 22, color: Color(0xFF173477))),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF68738F))),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF68738F)),
        ]),
      ),
    ),
  );
}
