import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class MathQuestion {
  final String text;
  final int answer;
  final List<int> options; // 4 choices, one of them correct
  const MathQuestion(this.text, this.answer, this.options);
}

/// Both players see the same sum. First correct answer scores; a wrong answer locks
/// you out of that question. If both are wrong, a new sum comes up. First to [target].
class MathDuelLogic extends LocalGameLogic {
  final int target;
  final int pauseMs;
  final Random _rng;
  final List<int> score;
  late MathQuestion question;
  final Set<int> lockedOut = {};
  int? solvedBy;
  int _now = 0;
  int? _nextAt;
  int questionNo = 0;

  MathDuelLogic({this.target = 7, this.pauseMs = 1000, int players = 2, Random? random})
      : _rng = random ?? Random(),
        score = List.filled(players, 0) {
    question = makeQuestion(_rng);
  }

  /// Sums get a little harder as the game goes on.
  static MathQuestion makeQuestion(Random r, [int level = 0]) {
    final op = r.nextInt(level < 3 ? 2 : 3); // + and - first, then × too
    late int a, b, ans;
    late String sym;
    switch (op) {
      case 0:
        a = 2 + r.nextInt(20 + level * 5);
        b = 2 + r.nextInt(20 + level * 5);
        ans = a + b;
        sym = '+';
      case 1:
        a = 10 + r.nextInt(30 + level * 5);
        b = 1 + r.nextInt(a - 1);
        ans = a - b;
        sym = '−';
      default:
        a = 2 + r.nextInt(10);
        b = 2 + r.nextInt(10);
        ans = a * b;
        sym = '×';
    }
    final opts = <int>{ans};
    while (opts.length < 4) {
      final d = 1 + r.nextInt(10);
      final wrong = r.nextBool() ? ans + d : ans - d;
      if (wrong >= 0) opts.add(wrong);
    }
    return MathQuestion('$a $sym $b', ans, opts.toList()..shuffle(r));
  }

  @override
  List<int> get scores => score;
  @override
  bool get finished => score.any((s) => s >= target);
  bool get betweenQuestions => _nextAt != null;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (next != null && _now >= next && !finished) {
      _nextAt = null;
      questionNo++;
      question = makeQuestion(_rng, questionNo ~/ 3);
      lockedOut.clear();
      solvedBy = null;
      notifyListeners();
    }
  }

  /// Returns true for a correct answer, false for a wrong one, null if the tap didn't count.
  bool? answer(int player, int value) {
    if (finished || betweenQuestions || lockedOut.contains(player)) return null;
    if (value == question.answer) {
      score[player]++;
      solvedBy = player;
      _nextAt = _now + pauseMs;
      notifyListeners();
      return true;
    }
    lockedOut.add(player);
    if (lockedOut.length == score.length) _nextAt = _now + pauseMs; // nobody got it
    notifyListeners();
    return false;
  }
}

final mathDuelInfo = LocalGameInfo(
  id: 'math_duel',
  title: 'Math Duel',
  emoji: '🧮',
  color: const Color(0xFF6C5CE7),
  tagline: 'Quick maths, quicker fingers!',
  rules: const [
    'Both of you get the same sum.',
    'Tap the right answer first to score. A wrong answer locks you out of that sum.',
    'Sums get harder as you go. First to 7 wins. 2 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: true,
  maxPlayers: 4,
  play: (players, onFinished) => TickingPlay<MathDuelLogic>(
    create: () => MathDuelLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      middle: ScoreMiddleBar(players: players, scores: g.scores, label: 'FIRST TO ${g.target}'),
      center: ZoneCenterChip('FIRST TO ${g.target}'),
      zone: (i) => _MathHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _MathHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final MathDuelLogic g;
  const _MathHalf({required this.player, required this.index, required this.g});

  @override
  Widget build(BuildContext context) {
    final locked = g.lockedOut.contains(index);
    final status = g.solvedBy == null
        ? (locked ? (g.betweenQuestions ? 'Nobody got it! = ${g.question.answer}' : 'Wrong! Wait for the next one') : '')
        : (g.solvedBy == index ? 'Correct! +1' : 'Too slow! = ${g.question.answer}');
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          PlayerTagSmall(player: player),
          Text('  ${g.score[index]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(status, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ]),
        Expanded(
          child: Center(
            child: FittedBox(
              child: Text('${g.question.text} = ?', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        Row(children: [
          for (final v in g.question.options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _AnswerButton(
                  value: v,
                  color: player.color,
                  state: g.solvedBy != null && v == g.question.answer
                      ? 1
                      : (locked && !g.betweenQuestions ? -1 : 0),
                  onTap: () {
                    final r = g.answer(index, v);
                    if (r != null) (r ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact()).ignore();
                  },
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final int value;
  final Color color;
  final int state; // 1 = the correct answer revealed, -1 = locked out
  final VoidCallback onTap;
  const _AnswerButton({required this.value, required this.color, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: state == -1 ? 0.4 : 1,
        child: Material(
          color: state == 1 ? GpColors.yes : color,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              height: 72,
              child: Center(child: FittedBox(child: Text('$value', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)))),
            ),
          ),
        ),
      );
}
