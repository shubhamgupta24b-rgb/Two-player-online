import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// How the WASM game boots. Mirrors BootOptions in the game's net.ts:
/// - offline: 8 karts, 1 human + 7 AI bots, no network at all
/// - host:    this phone runs the authoritative simulation for every seat
/// - guest:   this phone predicts its own kart and renders the host's snapshots
class NitroBoot {
  final String mode; // 'offline' | 'host' | 'guest'
  final int seat;
  final int seats;
  final List<String> names;

  const NitroBoot({required this.mode, this.seat = 0, this.seats = 8, this.names = const []});

  String asJson() => jsonEncode({'mode': mode, 'seat': seat, 'seats': seats, 'names': names});
}

/// Owns the WebView that runs the original React/Three.js/Rapier WASM game,
/// bundled in the app under assets/nitro/ (loaded with loadFlutterAsset, so it
/// works fully offline). Bridge messages from the game arrive on [onMessage];
/// [run] injects JavaScript (window.__nitroNet / __nitroDebug calls).
class NitroViewController {
  _NitroGameViewState? _state;

  /// True once the page has loaded and the boot options were accepted by the game.
  bool get ready => _state?._booted ?? false;

  Future<void> run(String js) async {
    final s = _state;
    if (s == null || !s.mounted) return;
    try {
      await s._controller.runJavaScript(js);
    } catch (_) {
      // The page can be navigating away; the bridge is best-effort.
    }
  }

  /// Tells the host simulation to apply one guest's input: __nitroNet.input(seat, args).
  void sendHostInput(int seat, List<Object?> args) =>
      run('window.__nitroNet && window.__nitroNet.input($seat, ${jsonEncode(args)})');

  /// Feeds a host snapshot to a guest WebView: __nitroNet.snapshot(json).
  void sendSnapshot(String snapshotJson) =>
      run('window.__nitroNet && window.__nitroNet.snapshot(${jsonEncode(snapshotJson)})');
}

/// The game page. Recreate (or rekey) this widget to start a fresh match:
/// the WebView reloads and re-boots with the given [boot] options.
class NitroGameView extends StatefulWidget {
  final NitroBoot boot;
  final NitroViewController controller;
  /// Bridge messages from the game: {kind: snapshot|input|finish|result|boot, ...}.
  final ValueChanged<Map<String, dynamic>> onMessage;

  const NitroGameView({super.key, required this.boot, required this.controller, required this.onMessage});

  @override
  State<NitroGameView> createState() => _NitroGameViewState();
}

class _NitroGameViewState extends State<NitroGameView> {
  late final WebViewController _controller;
  bool _loaded = false;
  bool _booted = false;
  Timer? _bootRetry;
  int _bootAttempts = 0;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF05080C))
      ..addJavaScriptChannel(
        'NitroBridge',
        onMessageReceived: (message) {
          Map<String, dynamic>? decoded;
          try {
            final v = jsonDecode(message.message);
            if (v is Map<String, dynamic>) decoded = v;
          } catch (_) {}
          if (decoded != null && mounted) widget.onMessage(decoded);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _injectBoot(),
        ),
      )
      ..loadFlutterAsset('assets/nitro/index.html');
  }

  @override
  void didUpdateWidget(NitroGameView old) {
    super.didUpdateWidget(old);
    // A new boot (role change) restarts the page so the engine re-boots cleanly.
    if (old.boot.mode != widget.boot.mode || old.boot.seat != widget.boot.seat || old.boot.seats != widget.boot.seats) {
      _loaded = false;
      _booted = false;
      _controller.reload();
    }
  }

  /// The game's React shell registers window.__nitroBoot after mount, which can be
  /// slightly after onPageFinished — poll briefly until it accepts the boot options.
  Future<void> _injectBoot() async {
    _loaded = true;
    _bootAttempts = 0;
    _bootRetry?.cancel();
    _bootRetry = Timer.periodic(const Duration(milliseconds: 120), (t) async {
      if (!mounted || _booted || _bootAttempts > 60) {
        t.cancel();
        return;
      }
      _bootAttempts++;
      try {
        final result = await _controller.runJavaScriptReturningResult(
          '(function(){'
          'if (window.__nitroBoot && !window.__nitroBooted) {'
          'window.__nitroBooted = true;'
          'window.__nitroBoot(${jsonEncode(widget.boot.asJson())});'
          'return 1;'
          '}'
          'return window.__nitroBooted ? 1 : 0;'
          '})()',
        );
        if ('$result' == '1' && mounted) setState(() => _booted = true);
      } catch (_) {
        t.cancel(); // page is gone or the channel closed
      }
    });
  }

  @override
  void dispose() {
    _bootRetry?.cancel();
    widget.controller._state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        // Keep a dark cover (with a spinner) until the engine accepts the boot
        // options, so the 3D scene never flashes white half-initialised.
        AnimatedOpacity(
          opacity: _loaded && _booted ? 0 : 1,
          duration: const Duration(milliseconds: 240),
          child: const ColoredBox(
            color: Color(0xFF05080C),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF38E8FF))),
          ),
        ),
      ],
    );
  }
}
