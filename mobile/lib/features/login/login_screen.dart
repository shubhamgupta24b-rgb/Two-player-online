import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/ui/app_ui.dart';
import '../guess_person/widgets/gp_theme.dart' show GpButton;
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameCtrl = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() => setState(() {})); // live avatar preview
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _guest() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return _snack('Enter your name to start');
    final auth = context.read<AuthenticationManager>();
    final socket = context.read<SocketManager>();
    final nav = Navigator.of(context);
    setState(() => busy = true);
    try {
      await auth.signInAsGuest(name);
      // Don't wait for the server: 1-device games work offline, online rooms connect when they can.
      unawaited(socket.connect(AppConfig.serverUrl, auth.token).catchError((_) {}));
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      _snack('$e');
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final name = nameCtrl.text.trim();
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: AppLogo(size: 170)),
                  const SizedBox(height: 18),
                  const Text('WELCOME!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Text('Party games for friends: on one phone or online.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.stroke)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: name.isEmpty ? const [Colors.white24, Colors.white10] : const [AppColors.blue, AppColors.purple]),
                          ),
                          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("WHO'S PLAYING?", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                            Text('Friends will see this name in rooms.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        maxLength: 20,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => busy ? null : _guest(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        decoration: const InputDecoration(hintText: 'Your name', counterText: '', prefixIcon: Icon(Icons.person_rounded, color: AppColors.muted)),
                      ),
                      const SizedBox(height: 14),
                      GpButton(busy ? 'GETTING READY…' : "LET'S PLAY", icon: Icons.play_arrow_rounded, onPressed: busy ? null : _guest),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white38),
                    SizedBox(width: 6),
                    Flexible(child: Text('Google sign-in coming soon. Guest play needs no account.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
