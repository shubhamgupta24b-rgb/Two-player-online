import 'dart:math';
import 'package:flutter/foundation.dart';

/// Game rules for a 1-device game. Time is pushed in from outside via [update]
/// (a Ticker in the UI, plain numbers in tests), so the logic owns no timers.
abstract class LocalGameLogic extends ChangeNotifier {
  bool get finished;
  List<int> get scores;
  void update(int elapsedMs);

  /// Set when the game is played online (see online/relay_play.dart): player actions are
  /// handed to this instead of changing the state here, and the host decides.
  void Function(String name, List<Object?> args)? sendToHost;

  /// Call at the top of every player action. Returns true when the action was handed
  /// over to the host, in which case it must not be applied locally.
  @protected
  bool forward(String name, List<Object?> args) {
    final send = sendToHost;
    if (send == null) return false;
    send(name, args);
    return true;
  }

  /// Tells the UI the state changed (used after loading a state sent by the host).
  void changed() => notifyListeners();
}

/// Base for real-time duels that end after a fixed duration.
abstract class TimedDuel extends LocalGameLogic {
  final int durationMs;
  int elapsedMs = 0;
  TimedDuel(this.durationMs);

  @override
  bool get finished => elapsedMs >= durationMs;
  double get progress => (elapsedMs / durationMs).clamp(0.0, 1.0);
  int get secondsLeft => max(0, ((durationMs - elapsedMs) / 1000).ceil());

  @override
  void update(int ms) {
    if (finished) return;
    elapsedMs = min(ms, durationMs);
    onUpdate();
    notifyListeners();
  }

  /// Per-frame game step (spawning, timers...). Called before listeners are notified.
  @protected
  void onUpdate() {}
}
