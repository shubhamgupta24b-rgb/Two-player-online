import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/ui/app_ui.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';

class SplashScreen extends StatefulWidget {
  /// How long the logo shows at least, so the intro animation can play.
  final Duration minShow;
  const SplashScreen({super.key, this.minShow = const Duration(milliseconds: 1400)});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthenticationManager>();
    final socket = context.read<SocketManager>();
    final nav = Navigator.of(context);
    final results = await Future.wait([auth.restore(), Future<bool>.delayed(widget.minShow, () => true)]);
    if (!mounted) return;
    if (!results.first) {
      nav.pushReplacement(_fade(const LoginScreen()));
      return;
    }
    // Don't block on the server: 1-device games work offline, online rooms connect when they can.
    unawaited(socket.connect(AppConfig.serverUrl, auth.token).catchError((_) {}));
    nav.pushReplacement(_fade(const HomeScreen()));
  }

  static Route<void> _fade(Widget page) => PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      );

  @override
  Widget build(BuildContext context) {
    final logo = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.7, curve: Curves.elasticOut));
    final text = CurvedAnimation(parent: _intro, curve: const Interval(0.45, 1, curve: Curves.easeOut));
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(scale: Tween(begin: 0.4, end: 1.0).animate(logo), child: const AppLogo(size: 220)),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: text,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(text),
                    child: const Column(children: [
                      PartyWordmark(width: 280),
                      SizedBox(height: 12),
                      Text('One phone or many · play anywhere', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(minHeight: 6, color: AppColors.gold, backgroundColor: AppColors.glass),
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
