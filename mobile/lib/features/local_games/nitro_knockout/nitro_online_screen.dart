import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/authentication_manager.dart';
import '../../../core/network/socket_manager.dart';
import '../../../core/room/room_manager.dart';
import '../../../core/session/game_session_manager.dart';
import '../../../core/ui/components.dart';
import 'nitro_game_view.dart';

/// Nitro Knockout over the internet (rooms of 2-10 people).
///
/// The host's WebView runs the real simulation (Rapier physics) for every seat and
/// publishes validated snapshots ~12 times a second through the game server; each
/// guest predicts its own kart locally, renders everyone else from snapshots with
/// interpolation, and streams centi-unit inputs to the host. The server stays the
/// authority on the room: join/ready/start/finish/rematch/reconnect, and it rejects
/// malformed frames, inputs and scores.
class NitroOnlineScreen extends StatefulWidget {
  const NitroOnlineScreen({super.key});
  @override
  State<NitroOnlineScreen> createState() => _NitroOnlineScreenState();
}

class _NitroOnlineScreenState extends State<NitroOnlineScreen> {
  final NitroViewController _vc = NitroViewController();
  late final GameSessionManager _session = context.read<GameSessionManager>();

  String _myId = '';
  List<String> _ids = const [];
  List<String> _names = const [];
  String _hostId = '';
  bool _host = false;
  bool _haveRoster = false;
  Map<String, dynamic>? _lastState;

  bool _firstSnapshot = false; // guest: the current host's first frame arrived
  int _sentVersion = 0; // guest: last snapshot version forwarded to the WebView
  bool _published = false; // host: this WebView has published a frame (the match is running)
  bool _finishSent = false; // host: nitro:finish was accepted (or is being retried)
  int _matchNo = 0; // bumped on every (re)start: rekeys the WebView for a fresh match

  // Host: which guest inputs have been applied.
  int _acked = 0;
  // Guest: latest input, flushed at the game's own cadence.
  List<Object?>? _pendingInput;
  Timer? _inputFlush;

  @override
  void initState() {
    super.initState();
    _myId = context.read<AuthenticationManager>().token.split(':')[1];
    _session.addListener(_onSession);
    _onSession();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _inputFlush?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _state => _session.state;

  void _onSession() {
    final st = _state;
    if (st == null || st['nitro'] != true) return;
    final players = (st['players'] as List? ?? const []).cast<Map>();
    final ids = [for (final p in players) p['userId'] as String];
    final hostId = st['host'] as String? ?? '';
    final version = (st['version'] as num?)?.toInt() ?? 0;
    if (!_haveRoster || (ids.length != _ids.length)) {
      _ids = ids;
      // Kart labels and the kill feed: keep names short (the server caps feed names at 64).
      _names = [for (final p in players) _short('${p['username']}')];
      _haveRoster = _ids.isNotEmpty;
    }
    final host = hostId == _myId;
    if (hostId != _hostId && hostId.isNotEmpty && _haveRoster) {
      // Host migration: the server re-pointed the room host. Re-boot as the new role.
      _hostId = hostId;
      _host = host;
      _matchNo++;
      // The server still holds the old host's last frame: only frames after it are new.
      _resetMatchState(staleVersion: version);
    } else if (_hostId.isEmpty) {
      _hostId = hostId;
      _host = host;
    }
    if (_lastState != null && version < ((_lastState!['version'] as num?)?.toInt() ?? 0)) {
      // Versions only rise within a match, so a drop is a rematch (a fresh game object),
      // even if a reconnect skipped its version 0: restart the WebView.
      _matchNo++;
      _resetMatchState();
    }
    _lastState = st;

    if (_host) {
      for (final i in (st['inputs'] as List? ?? const []).cast<Map>()) {
        final seq = (i['seq'] as num).toInt();
        if (seq <= _acked) continue;
        _acked = seq;
        final from = _ids.indexOf(i['from'] as String);
        if (from >= 0) {
          _vc.sendHostInput(from, List<Object?>.from(i['args'] as List));
        }
      }
    } else {
      final raw = st['state'];
      // Room changes also notify the session; only forward frames the host actually published.
      if (raw != null && version > _sentVersion) {
        _sentVersion = version;
        _vc.sendSnapshot(jsonEncode(raw));
        _firstSnapshot = true;
      }
    }
    if (mounted) setState(() {});
  }

  /// The game renders names as HTML (kill feed), so strip markup characters; keep it short.
  static String _short(String raw) {
    final name = raw.replaceAll(RegExp('[<>&"\'`]'), '').trim();
    if (name.isEmpty) return 'Player';
    return name.length <= 20 ? name : '${name.substring(0, 19)}…';
  }

  void _resetMatchState({int staleVersion = 0}) {
    _acked = 0;
    _sentVersion = staleVersion;
    _firstSnapshot = false;
    _published = false;
    _finishSent = false;
    _pendingInput = null;
    _inputFlush?.cancel();
    _inputFlush = null;
  }

  void _action(String type, Map<String, dynamic> payload) {
    // Fire-and-forget: a rejected frame or input is replaced by the next one ~80 ms later.
    _session.action(type, payload).ignore();
  }

  /// The finish is sent once, so it can't be fire-and-forget: without it the room never
  /// leaves 'playing'. Retries through a dropped connection, a timeout or the rate limit
  /// for as long as this match is on screen (a handover or rematch starts a new one).
  Future<void> _sendFinish(List<Object?> scores) async {
    if (_finishSent) return;
    _finishSent = true;
    final match = _matchNo;
    for (var attempt = 0; mounted && match == _matchNo; attempt++) {
      final ack = await _session.action('nitro:finish', {'scores': scores});
      if (ack['ok'] == true || !const {'OFFLINE', 'TIMEOUT', 'RATE_LIMITED'}.contains(ack['error'])) return;
      await Future<void>.delayed(Duration(seconds: 1 << attempt.clamp(0, 3))); // 1, 2, 4, then every 8 s
    }
  }

  void _onMessage(Map<String, dynamic> message) {
    switch (message['kind']) {
      case 'snapshot':
        // Host: publish one authoritative frame (the game paces itself at ~12.5 Hz).
        if (!_host) return;
        final data = message['data'];
        if (data is! String) return;
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map<String, dynamic>) {
            _published = true;
            _action('nitro:state', {'state': parsed, 'ack': _acked});
          }
        } catch (_) {}
      case 'input':
        // Guest: stream our steering/throttle to the host (latest wins).
        if (_host) return;
        final args = message['args'];
        if (args is! List || args.length != 4) return;
        _pendingInput = List<Object?>.from(args);
        _inputFlush ??= Timer(const Duration(milliseconds: 60), () {
          _inputFlush = null;
          final args = _pendingInput;
          _pendingInput = null;
          if (args != null) _action('nitro:input', {'args': args});
        });
      case 'finish':
        // Host: the match is over — the server ends the round and shows results.
        if (!_host) return;
        final scores = message['scores'];
        if (scores is! List) return;
        _sendFinish(List<Object?>.from(scores));
      default:
        break;
    }
  }

  NitroBoot? get _boot {
    if (!_haveRoster) return null;
    final me = _ids.indexOf(_myId);
    if (me < 0) return null;
    return NitroBoot(mode: _host ? 'host' : 'guest', seat: me, seats: _ids.length, names: _names);
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketManager?>();
    final room = context.watch<RoomManager?>()?.room;
    final boot = _boot;

    if (boot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    context.watch<GameSessionManager>(); // rebuild on every game_state
    // Fresh matches and host handovers both wait for the (new) host's first frame.
    final waiting = !_host && !_firstSnapshot;

    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: ValueKey('nitro-match$_matchNo${boot.mode}${boot.seat}'),
          child: NitroGameView(controller: _vc, boot: boot, onMessage: _onMessage),
        ),
        _NitroBanners(myId: _myId, socket: socket, room: room),
        if (waiting)
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(18)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38E8FF))),
                  SizedBox(width: 10),
                  Text('Waiting for the host to start the race…',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
              ),
            ),
          ),
        // Until the host's first frame: the PLAY button is in the game, under this hint.
        if (_host && !_published)
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(14)),
                child: const Text('You are the HOST · tap PLAY in the game to start everyone',
                    style: TextStyle(color: Color(0xFFFFE66D), fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Non-blocking connection states: our socket, and players (or the host) who dropped.
class _NitroBanners extends StatelessWidget {
  final String myId;
  final SocketManager? socket;
  final Room? room;
  const _NitroBanners({required this.myId, required this.socket, required this.room});

  @override
  Widget build(BuildContext context) {
    final s = socket;
    final away = room?.players.where((p) => !p.connected && p.userId != myId).toList() ?? const <RoomPlayer>[];
    final hostId = room?.hostId;
    final hostAway = hostId != null && away.any((p) => p.userId == hostId);
    Widget banners(bool online) {
      final list = <Widget>[
        if (!online) const AppBanner(text: 'Connection lost · reconnecting…', tone: Tone.warn),
        if (online && hostAway) const AppBanner(text: 'The host lost connection. Waiting for them to come back…', tone: Tone.info),
        if (online && !hostAway && away.isNotEmpty)
          AppBanner(text: '${away.map((p) => p.username).join(', ')} lost connection. Waiting for them…', tone: Tone.info),
      ];
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Column(children: list),
      );
    }

    if (s == null) return banners(true);
    return ValueListenableBuilder<bool>(valueListenable: s.connected, builder: (_, on, __) => banners(on));
  }
}
