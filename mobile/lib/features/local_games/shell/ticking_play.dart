import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'local_game_logic.dart';

/// Hosts a [LocalGameLogic]: drives it from a Ticker, rebuilds on change, reports the
/// final scores exactly once, and disposes everything with the widget.
class TickingPlay<T extends LocalGameLogic> extends StatefulWidget {
  final T Function() create;
  final Widget Function(BuildContext context, T logic) builder;
  final void Function(List<int> scores) onFinished;
  const TickingPlay({super.key, required this.create, required this.builder, required this.onFinished});

  @override
  State<TickingPlay<T>> createState() => _TickingPlayState<T>();
}

class _TickingPlayState<T extends LocalGameLogic> extends State<TickingPlay<T>> with SingleTickerProviderStateMixin {
  late final T logic = widget.create();
  late final Ticker _ticker;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      logic.update(elapsed.inMilliseconds);
      if (logic.finished && !_reported) {
        _reported = true;
        _ticker.stop();
        // Short pause so players see the final state before the result screen.
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onFinished(List.of(logic.scores));
        });
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    logic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: logic, builder: (context, _) => widget.builder(context, logic));
}
