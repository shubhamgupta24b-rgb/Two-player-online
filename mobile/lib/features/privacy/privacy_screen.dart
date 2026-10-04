import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/records/records.dart';
import '../../core/ui/app_ui.dart';
import '../login/login_screen.dart';

/// The privacy policy in short (the full text is on the server's /privacy page), and a way
/// to delete everything this app keeps on the phone.
/// Keep in step with server/src/pages/privacy.js.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _points = [
    ('🙂', 'No account', 'You only type a player name. No email, phone number or Google account.'),
    ('👀', 'Who sees what', 'Players in your room see your name and your moves. Nobody else.'),
    ('📱', 'Kept on this phone', 'Your name, a random player ID and your records (best scores, wins).'),
    ('🌐', 'The game server', 'Passes moves between players and forgets a room when it ends.'),
    ('🚫', 'Never collected', 'Location, contacts, photos, camera, microphone, ads or tracking.'),
  ];

  Future<void> _delete(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete my data?'),
        content: const Text('This removes your name, player ID and all your records from this phone. You can start again with a new name.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('KEEP')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final auth = context.read<AuthenticationManager>();
    final socket = context.read<SocketManager>();
    final nav = Navigator.of(context);
    socket.disconnect();
    await Records.clear();
    await auth.signOut();
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              Row(children: [
                IconButton(tooltip: 'Back', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70)),
                const Text('🛡 PRIVACY', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ]),
              const SizedBox(height: 8),
              for (final (emoji, title, text) in _points)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.stroke)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text(text, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.35)),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 6),
              const Text('The full policy is on the game server\'s /privacy page and in the app\'s store listing.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('DELETE MY DATA ON THIS PHONE', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
      );
}
