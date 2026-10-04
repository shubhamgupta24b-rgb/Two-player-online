import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import 'game_style.dart';
import 'local_game_info.dart';
import 'local_game_shell.dart' show PauseButton;

/// Runs a "take turns" match: each player in order gets the whole screen for [durationMs];
/// computer players ([botSeats]) take their turn instantly. Reports everyone's scores at the end.
class TurnsPlay extends StatefulWidget {
  final TurnsSpec spec;
  final List<GpPlayer> players;
  final Set<int> botSeats;
  final int durationMs;
  final void Function(List<int> scores) onFinished;
  final Random? random;
  const TurnsPlay({super.key, required this.spec, required this.players, required this.botSeats, required this.durationMs, required this.onFinished, this.random});

  @override
  State<TurnsPlay> createState() => _TurnsPlayState();
}

enum _Step { ready, playing, scored }

class _TurnsPlayState extends State<TurnsPlay> {
  late final List<int?> scores = List.filled(widget.players.length, null);
  late final Random rng = widget.random ?? Random();
  int index = 0;
  var step = _Step.ready;

  @override
  void initState() {
    super.initState();
    _skipBots();
  }

  /// Computer players take their turns straight away (no need to watch them).
  void _skipBots() {
    while (index < widget.players.length && widget.botSeats.contains(index)) {
      scores[index] = widget.spec.simulate(widget.durationMs, rng);
      index++;
    }
    if (index >= widget.players.length) _finish();
  }

  void _finish() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished([for (final s in scores) s ?? 0]);
      });

  void _done(int score) {
    if (!mounted || step != _Step.playing) return;
    HapticFeedback.mediumImpact().ignore();
    setState(() {
      scores[index] = score;
      step = _Step.scored;
    });
  }

  void _next() => setState(() {
        index++;
        step = _Step.ready;
        _skipBots();
      });

  @override
  Widget build(BuildContext context) {
    if (index >= widget.players.length) return const SizedBox.shrink();
    final p = widget.players[index];
    return switch (step) {
      _Step.playing => KeyedSubtree(key: ValueKey('turn$index'), child: widget.spec.play(p, widget.durationMs, _done)),
      _Step.ready => _Card(
          emoji: '📲',
          title: index == 0 ? '${p.whose} TURN FIRST' : 'PASS THE PHONE TO',
          name: p.name,
          color: p.color,
          line: '${_time(widget.durationMs)} on the whole screen. Everyone else, just watch! 👀',
          button: 'START',
          onTap: () => setState(() => step = _Step.playing),
          scores: scores,
          players: widget.players,
        ),
      _Step.scored => _Card(
          emoji: '⭐',
          title: '${p.whose} SCORE',
          name: '${scores[index]}',
          color: p.color,
          line: _nextLine(),
          button: _hasNextPerson() ? 'NEXT PLAYER' : 'SEE RESULTS',
          onTap: _next,
          scores: scores,
          players: widget.players,
        ),
    };
  }

  bool _hasNextPerson() => [for (var i = index + 1; i < widget.players.length; i++) i].any((i) => !widget.botSeats.contains(i));

  String _nextLine() {
    for (var i = index + 1; i < widget.players.length; i++) {
      if (!widget.botSeats.contains(i)) return 'Next up: ${widget.players[i].name}';
    }
    return widget.botSeats.isEmpty ? 'That was the last turn!' : 'The computer plays its turns now.';
  }

  static String _time(int ms) {
    final s = ms ~/ 1000;
    return s % 60 == 0 ? '${s ~/ 60} min' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _Card extends StatelessWidget {
  final String emoji, title, name, line, button;
  final Color color;
  final VoidCallback onTap;
  final List<int?> scores;
  final List<GpPlayer> players;
  const _Card({
    required this.emoji,
    required this.title,
    required this.name,
    required this.color,
    required this.line,
    required this.button,
    required this.onTap,
    required this.scores,
    required this.players,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: PauseButton()),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(emoji, style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 6),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
                  const SizedBox(height: 4),
                  FittedBox(child: Text(name.toUpperCase(), style: TextStyle(color: color, fontSize: 44, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 8),
                  Text(line, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 22),
                  GpButton(button, icon: Icons.play_arrow_rounded, color: color, textColor: Colors.white, onPressed: onTap),
                  const SizedBox(height: 22),
                  // Scores so far.
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < players.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scores[i] == null ? Colors.white10 : players[i].color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: players[i].color, width: 2),
                        ),
                        child: Text('${players[i].name} · ${scores[i] ?? '—'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      );
}

/// Top bar for a player's full-screen turn: who's playing, score and time left.
class TurnBar extends StatelessWidget {
  final GpPlayer player;
  final int score;
  final int secondsLeft;
  const TurnBar({super.key, required this.player, required this.score, required this.secondsLeft});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(children: [
          const PauseButton(),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: player.color, borderRadius: BorderRadius.circular(12)),
            child: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const Spacer(),
          ScorePill('$score', color: player.color),
          const SizedBox(width: 8),
          Text('⏱ ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
              style: TextStyle(color: secondsLeft <= 10 ? GpColors.no : Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
      );
}
