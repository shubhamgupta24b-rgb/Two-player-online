import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/game_hud.dart' show MomentWatcher;
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
    if (forward('answer', [player, value])) return null;
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
  bot: botFor<MathDuelLogic>((g, b, now) {
    if (g.finished || g.betweenQuestions || g.solvedBy != null || g.lockedOut.contains(b.seat)) return;
    if (!b.thinkFirst(g.questionNo, now, 1800, 4500)) return;
    final q = g.question;
    g.answer(b.seat, b.chance(0.75) ? q.answer : b.pick(q.options.where((o) => o != q.answer).toList()));
  }),
  online: RelaySpec<MathDuelLogic>(
    create: (n) => MathDuelLogic(players: n),
    save: (g) => {
      'score': g.score,
      'q': g.question.text,
      'answer': g.question.answer,
      'options': g.question.options,
      'locked': g.lockedOut.toList(),
      'solvedBy': g.solvedBy,
      'between': g.betweenQuestions,
      'no': g.questionNo,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.question = MathQuestion(s['q'] as String, asInt(s['answer']), ints(s['options']));
      g.lockedOut
        ..clear()
        ..addAll(ints(s['locked']));
      g.solvedBy = nInt(s['solvedBy']);
      g._nextAt = s['between'] == true ? 1 << 40 : null;
      g.questionNo = asInt(s['no']);
    },
    apply: (g, from, name, a) {
      if (name == 'answer' && asInt(a[0]) == from) g.answer(from, asInt(a[1]));
    },
    view: (context, g, players, me) => Column(children: [
      ScoreMiddleBar(players: players, scores: g.scores, label: 'First to ${g.target}'),
      Expanded(child: _MathHalf(player: players[me], index: me, g: g)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<MathDuelLogic>(
    create: () => MathDuelLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => MomentWatcher<int?>(
      value: g.solvedBy,
      onChange: (fx, _, who) {
        if (who == null) return;
        fx?.flash(StatusColors.success);
        fx?.pop('+1 ${players[who].name}');
      },
      child: PlayerZones(
        count: players.length,
        colors: [for (final p in players) p.color],
        middle: ScoreMiddleBar(players: players, scores: g.scores, label: 'First to ${g.target}'),
        center: ZoneCenterChip('First to ${g.target}'),
        zone: (i) => _MathHalf(player: players[i], index: i, g: g),
      ),
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
    final seat = PlayerPalette.indexOf(player.color) ?? index;
    // Small zones (3-4 players sit sideways): lay out at 250 px tall and scale down to fit.
    return LayoutBuilder(builder: (context, c) {
      const design = 250.0;
      final half = _half(locked, status, seat);
      return c.maxHeight >= design ? half : FittedBox(child: SizedBox(width: c.maxWidth * design / c.maxHeight, height: design, child: half));
    });
  }

  Widget _half(bool locked, String status, int seat) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            PlayerBadge(index: seat, size: 22, color: player.color, initial: player.name),
            const SizedBox(width: 6),
            Flexible(child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, color: nameColor(player.color), fontWeight: FontWeight.w900, fontSize: 14))),
            const SizedBox(width: 6),
            Text('${g.score[index]}', style: const TextStyle(fontFamily: Fonts.display, color: Colors.white, fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(status,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w900, color: g.solvedBy == index ? StatusColors.success : (status.isEmpty ? Colors.white : const Color(0xFFFF8E8B)))),
            ),
          ]),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft, child: Pips(filled: g.score[index], total: g.target, color: player.color, size: 9)),
          const SizedBox(height: 8),
          // The sum, chalked on a little blackboard.
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF23423A),
                borderRadius: Radii.rCard,
                border: Border.all(color: const Color(0xFF8A5A2B), width: 5),
                boxShadow: Shadows.small,
              ),
              child: Center(
                child: FittedBox(
                  child: Text('${g.question.text} = ?', style: const TextStyle(fontFamily: Fonts.display, color: Color(0xFFF4F1E8), fontSize: 56, shadows: [Shadow(color: Color(0x55FFFFFF), blurRadius: 6)])),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Stack(alignment: Alignment.center, children: [
            Row(children: [
              for (final v in g.question.options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _AnswerButton(
                      value: v,
                      color: player.color,
                      state: g.solvedBy != null && v == g.question.answer ? 1 : (locked && !g.betweenQuestions ? -1 : 0),
                      onTap: () {
                        final r = g.answer(index, v);
                        if (r != null) (r ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact()).ignore();
                      },
                    ),
                  ),
                ),
            ]),
            if (locked && !g.betweenQuestions)
              IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: NeonPalette.overlay, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF8E8B), width: 2)),
                  child: const GameIcon(GameIcons.lock, size: 26, color: Color(0xFFFF8E8B)),
                ),
              ),
          ]),
        ]),
      );
}

class _AnswerButton extends StatelessWidget {
  final int value;
  final Color color;
  final int state; // 1 = the correct answer revealed, -1 = locked out
  final VoidCallback onTap;
  const _AnswerButton({required this.value, required this.color, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fill = state == 1 ? StatusColors.success : color;
    return Opacity(
      opacity: state == -1 ? 0.35 : 1,
      child: Semantics(
        button: true,
        label: '$value',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(fill, Colors.white, 0.18)!, fill]),
              borderRadius: Radii.rButton,
              boxShadow: Shadows.edge(Color.lerp(fill, Colors.black, 0.45)!, depth: 5),
            ),
            child: FittedBox(child: Text('$value', style: const TextStyle(fontFamily: Fonts.display, color: Colors.white, fontSize: 32, fontFeatures: [FontFeature.tabularFigures()]))),
          ),
        ),
      ),
    );
  }
}
