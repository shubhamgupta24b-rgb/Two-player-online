import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

enum SimonPhase { showing, input, pause }

/// Simon Says: watch the pads light up, then repeat the pattern. One more step each round.
/// Score: the longest pattern you repeated.
class SimonLogic extends SoloLogic {
  static const pads = 4;
  final Random _rng;
  final List<int> sequence = [];
  SimonPhase phase = SimonPhase.pause;
  int _phaseAt = 0;
  int typed = 0;
  int? lit; // pad lit right now
  int? wrongPad;

  SimonLogic({Random? random}) : _rng = random ?? Random() {
    sequence.add(_rng.nextInt(pads));
    _phaseAt = 700;
  }

  int get flashMs => max(260, 560 - sequence.length * 20);

  @override
  void step(int now) {
    if (phase == SimonPhase.pause) {
      if (now >= _phaseAt) {
        phase = SimonPhase.showing;
        _phaseAt = now;
      }
      lit = null;
    } else if (phase == SimonPhase.showing) {
      final k = (now - _phaseAt) ~/ (flashMs + 180);
      final into = (now - _phaseAt) % (flashMs + 180);
      if (k >= sequence.length) {
        phase = SimonPhase.input;
        typed = 0;
        lit = null;
      } else {
        lit = into < flashMs ? sequence[k] : null;
      }
    }
    notifyListeners();
  }

  void press(int pad) {
    if (over || phase != SimonPhase.input) return;
    HapticFeedback.selectionClick().ignore();
    if (pad != sequence[typed]) {
      wrongPad = pad;
      HapticFeedback.heavyImpact().ignore();
      gameOver(1500);
      return;
    }
    typed++;
    if (typed == sequence.length) {
      score = sequence.length;
      sequence.add(_rng.nextInt(pads));
      phase = SimonPhase.pause;
      _phaseAt = now + 800;
    }
    notifyListeners();
  }
}

final simonInfo = LocalGameInfo(
  id: 'simon_says',
  title: 'Simon Says',
  emoji: '🟢',
  color: const Color(0xFF26A69A),
  tagline: 'Watch, remember, repeat!',
  rules: const [
    'Watch the coloured pads light up one by one.',
    'Then tap them back in exactly the same order.',
    'Each round adds one more step. How long a pattern can you remember?',
  ],
  scoreUnit: 'steps',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<SimonLogic>(
    create: () => SimonLogic(),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: switch (g.phase) {
        _ when g.over => '❌ WRONG PAD',
        SimonPhase.input => '👆 YOUR TURN (${g.typed}/${g.sequence.length})',
        _ => '👀 WATCH…',
      },
      score: g.score,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var p = 0; p < SimonLogic.pads; p++)
                () {
                  const colors = [Color(0xFF2ECC71), Color(0xFFE53935), Color(0xFFFFD43B), Color(0xFF4D96FF)];
                  final on = g.lit == p || (g.wrongPad == p);
                  return GestureDetector(
                    onTapDown: (_) => g.press(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      decoration: BoxDecoration(
                        color: on ? Color.lerp(colors[p], Colors.white, 0.45) : colors[p].withValues(alpha: g.phase == SimonPhase.input ? 0.85 : 0.55),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [if (on) BoxShadow(color: colors[p], blurRadius: 30, spreadRadius: 4)],
                      ),
                    ),
                  );
                }(),
            ],
          ),
        ),
      ),
    ),
  ),
);
