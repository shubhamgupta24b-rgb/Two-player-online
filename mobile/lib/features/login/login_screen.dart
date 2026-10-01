import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameCtrl = TextEditingController();
  bool busy = false;

  Future<void> _guest() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return _snack('Enter a name');
    final auth = context.read<AuthenticationManager>();
    final socket = context.read<SocketManager>();
    final nav = Navigator.of(context);
    setState(() => busy = true);
    try {
      await auth.signInAsGuest(name);
      await socket.connect(AppConfig.serverUrl, auth.token);
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      _snack('$e');
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('WELCOME', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 32),
            TextField(controller: nameCtrl, maxLength: 20, decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : _guest, child: Padding(padding: const EdgeInsets.all(14), child: Text(busy ? 'Connecting...' : 'Continue as Guest'))),
            const SizedBox(height: 12),
            const OutlinedButton(onPressed: null, child: Padding(padding: EdgeInsets.all(14), child: Text('Continue with Google (needs Firebase)'))),
          ]),
        ),
      ),
    );
  }
}
