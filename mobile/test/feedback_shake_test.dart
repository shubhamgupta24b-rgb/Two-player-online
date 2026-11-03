import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ui/game_kit.dart';

/// Counts how many times it was mounted: a remount means the game restarted.
class _Probe extends StatefulWidget {
  const _Probe();
  static int mounts = 0;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.mounts++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  testWidgets('a shake keeps the game mounted (Snakes & Ladders snake, Colour Clash +4)', (tester) async {
    _Probe.mounts = 0;
    await tester.pumpWidget(const MaterialApp(home: FeedbackLayer(child: _Probe())));
    expect(_Probe.mounts, 1);

    final fx = tester.state<GameFeedback>(find.byType(FeedbackLayer));
    fx.shake();
    await tester.pump(const Duration(milliseconds: 50)); // mid-shake
    await tester.pumpAndSettle(); // shake finished
    fx.shake();
    await tester.pumpAndSettle();

    expect(_Probe.mounts, 1, reason: 'shaking must not remount (restart) the game');
  });
}
