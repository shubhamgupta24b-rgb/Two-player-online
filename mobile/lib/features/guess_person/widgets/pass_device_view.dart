import 'package:flutter/material.dart';
import '../models/gp_player.dart';
import 'gp_theme.dart';

/// Privacy screen between players. Deliberately shows nothing about the secret person.
class PassDeviceView extends StatelessWidget {
  final String title;
  final GpPlayer to;
  final String message;
  final String buttonLabel;
  final VoidCallback onReady;
  final IconData icon;
  const PassDeviceView({
    super.key,
    required this.title,
    required this.to,
    required this.onReady,
    this.message = "Don't let the other player see your selection.",
    this.buttonLabel = "I'M READY",
    this.icon = Icons.lock_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: to.color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: to.color, width: 3)),
              child: Icon(icon, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 24),
            const Text('Pass the device to:', style: TextStyle(color: GpColors.muted, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(color: to.color, borderRadius: BorderRadius.circular(30)),
              child: Text(to.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 20),
            Text('"$message"', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic)),
            const SizedBox(height: 36),
            SizedBox(width: double.infinity, child: GpButton(buttonLabel, onPressed: onReady, icon: Icons.thumb_up_alt_rounded)),
          ]),
        ),
      ),
    );
  }
}
