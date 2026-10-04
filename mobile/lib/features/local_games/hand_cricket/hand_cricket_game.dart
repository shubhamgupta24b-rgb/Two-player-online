import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class Ball {
  final int bat, bowl;
  const Ball(this.bat, this.bowl);
  bool get out => bat == bowl;
}

/// Hand cricket (odd-even style): both players secretly show 1-6. The batter scores
/// their number unless the numbers match: OUT! One wicket each, [maxBalls] balls per
/// innings. Player 1 bats first; player 2 chases.
class HandCricketLogic extends LocalGameLogic {
  static const maxBalls = 24;
  final int showMs;
  final List<int> runs = [0, 0];
  final List<int?> picks = [null, null];
  final List<List<Ball>> balls = [[], []];
  int innings = 0;
  int _now = 0;
  int? _nextAt;
  bool over = false;

  HandCricketLogic({this.showMs = 1300});

  int get batter => innings;
  int get bowler => 1 - innings;
  bool get showingBall => _nextAt != null;
  Ball? get lastBall => balls[innings].isEmpty ? null : balls[innings].last;
  int? get target => innings == 1 ? runs[0] + 1 : null;

  @override
  bool get finished => over && !showingBall;
  @override
  List<int> get scores => runs;

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (next != null && _now >= next) {
      _nextAt = null;
      picks[0] = picks[1] = null;
      final b = balls[innings];
      final inningsOver = b.isNotEmpty && (b.last.out || b.length >= maxBalls);
      if (innings == 1 && (runs[1] > runs[0] || inningsOver)) {
        over = true;
      } else if (inningsOver) {
        innings = 1;
      }
      notifyListeners();
    }
  }

  void pick(int player, int n) {
    if (forward('pick', [player, n])) return;
    if (over || showingBall || n < 1 || n > 6 || picks[player] != null) return;
    picks[player] = n;
    if (picks[0] != null && picks[1] != null) {
      final ball = Ball(picks[batter]!, picks[bowler]!);
      balls[innings].add(ball);
      if (!ball.out) runs[batter] += ball.bat;
      _nextAt = _now + showMs;
    }
    notifyListeners();
  }
}

final handCricketInfo = LocalGameInfo(
  id: 'hand_cricket',
  title: 'Hand Cricket',
  emoji: '🏏',
  color: const Color(0xFF16A085),
  tagline: 'Same number? You\'re OUT!',
  rules: const [
    'Player 1 bats first. Both secretly pick a number from 1 to 6 on their own side.',
    'Different numbers: the batter scores their number. Same number: OUT!',
    'Then swap: player 2 chases the target. One wicket and 24 balls each. Most runs wins!',
  ],
  scoreUnit: 'runs',
  splitScreen: true,
  bot: botFor<HandCricketLogic>((g, b, now) {
    if (g.over || g.showingBall || g.picks[b.seat] != null) return;
    if (b.thinkFirst((g.innings, g.balls[g.innings].length), now, 600, 1400)) g.pick(b.seat, 1 + b.rng.nextInt(6));
  }),
  online: RelaySpec<HandCricketLogic>(
    create: (n) => HandCricketLogic(),
    save: (g) => {
      'runs': g.runs,
      'locked': [for (final p in g.picks) p != null],
      'balls': [for (final inn in g.balls) [for (final b in inn) b.bat * 10 + b.bowl]],
      'innings': g.innings,
      'showing': g.showingBall,
      'over': g.over,
    },
    load: (g, s, me) {
      g.runs.setAll(0, ints(s['runs']));
      final locked = (s['locked'] as List).cast<bool>();
      for (var i = 0; i < 2; i++) {
        g.picks[i] = locked[i] ? (g.picks[i] ?? 1) : null; // the number itself stays secret
      }
      final balls = s['balls'] as List;
      for (var i = 0; i < 2; i++) {
        g.balls[i]
          ..clear()
          ..addAll([for (final v in ints(balls[i])) Ball(v ~/ 10, v % 10)]);
      }
      g.innings = asInt(s['innings']);
      g._nextAt = s['showing'] == true ? 1 << 40 : null;
      g.over = s['over'] == true;
    },
    apply: (g, from, name, a) {
      if (name == 'pick' && asInt(a[0]) == from) g.pick(from, asInt(a[1]));
    },
    view: (context, g, players, me) => Column(children: [
      _Scoreboard(players: players, g: g),
      Expanded(child: _CricketHalf(player: players[me], index: me, g: g, players: players)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<HandCricketLogic>(
    create: () => HandCricketLogic(),
    onFinished: onFinished,
    builder: (context, g) => SplitScreen(
      middle: _Scoreboard(players: players, g: g),
      half: (i) => _CricketHalf(player: players[i], index: i, g: g, players: players),
    ),
  ),
);

class _Scoreboard extends StatelessWidget {
  final List<GpPlayer> players;
  final HandCricketLogic g;
  const _Scoreboard({required this.players, required this.g});
  @override
  Widget build(BuildContext context) => ScoreMiddleBar(
        players: players,
        scores: g.runs,
        label: g.innings == 0 ? 'INNINGS 1 · BALL ${g.balls[0].length + 1}' : 'TARGET ${g.target} · BALL ${g.balls[1].length + 1}',
      );
}

class _CricketHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final HandCricketLogic g;
  final List<GpPlayer> players;
  const _CricketHalf({required this.player, required this.index, required this.g, required this.players});

  @override
  Widget build(BuildContext context) {
    final batting = g.batter == index;
    final ball = g.lastBall;
    final picked = g.picks[index] != null;
    final String title, sub;
    if (g.showingBall && ball != null) {
      title = ball.out ? (batting ? '☝️ OUT!' : '🎯 WICKET!') : (batting ? '+${ball.bat} RUNS' : '${ball.bat} runs scored');
      sub = 'Bat ${ball.bat} · Ball ${ball.bowl}';
    } else if (g.over) {
      title = g.runs[0] == g.runs[1] ? 'TIE!' : (g.runs[index] > g.runs[1 - index] ? '🏆 YOU WIN!' : 'You lose');
      sub = '${g.runs[index]} runs';
    } else if (picked) {
      title = 'LOCKED IN ✓';
      sub = 'Waiting for ${players[1 - index].name}…';
    } else {
      title = batting ? '🏏 YOU BAT' : '🥎 YOU BOWL';
      sub = batting ? 'Pick a number. Avoid theirs!' : 'Match their number to get them OUT';
    }
    return Container(
      color: player.color.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(player.name.toUpperCase(), style: TextStyle(color: player.color, fontWeight: FontWeight.w900, letterSpacing: 1)),
        FittedBox(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28))),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (var n = 1; n <= 6; n++)
            Semantics(
              button: true,
              label: '$n',
              child: Material(
                color: picked || g.showingBall || g.over ? Colors.white10 : player.color,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: picked || g.showingBall || g.over
                      ? null
                      : () {
                          haptic(HapticWeight.selection);
                          g.pick(index, n);
                        },
                  child: SizedBox(width: 50, height: 50, child: Center(child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)))),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
