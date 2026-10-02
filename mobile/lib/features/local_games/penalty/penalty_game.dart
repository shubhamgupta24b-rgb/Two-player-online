import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/split_screen.dart';
import '../shell/ticking_play.dart';

class Kick {
  final int kicker;
  final int shot; // 0 left, 1 centre, 2 right (absolute, as seen by player 1 at the bottom)
  final int dive;
  bool get goal => shot != dive;
  const Kick(this.kicker, this.shot, this.dive);
}

/// Penalty shootout on one screen. Players alternate kicking and keeping. Both pick a
/// side in secret on their own half; the kick resolves once both have picked.
/// 5 kicks each, then sudden death (capped, so a match always ends).
class PenaltyLogic extends LocalGameLogic {
  final int kicksEach;
  final int maxKicks;
  final int showMs;
  final List<int> goals = [0, 0];
  final List<Kick> kicks = [];
  final List<int?> picks = [null, null]; // this kick's secret picks (absolute zones)
  int _now = 0;
  int? _nextAt;

  PenaltyLogic({this.kicksEach = 5, this.maxKicks = 20, this.showMs = 1600});

  int get kickNo => kicks.length;
  int get kicker => kickNo % 2;
  int get keeper => 1 - kicker;
  bool get showingResult => _nextAt != null;
  Kick? get lastKick => kicks.isEmpty ? null : kicks.last;
  int taken(int p) => kicks.where((k) => k.kicker == p).length;

  @override
  List<int> get scores => goals;

  @override
  bool get finished {
    if (showingResult) return false;
    final a = taken(0), b = taken(1);
    final leftA = a < kicksEach ? kicksEach - a : 0, leftB = b < kicksEach ? kicksEach - b : 0;
    if (goals[0] + leftA < goals[1] || goals[1] + leftB < goals[0]) return true; // can't be caught
    if (a >= kicksEach && a == b && goals[0] != goals[1]) return true; // sudden death decided
    return kickNo >= maxKicks;
  }

  @override
  void update(int elapsedMs) {
    _now = elapsedMs;
    final next = _nextAt;
    if (next != null && _now >= next) {
      _nextAt = null;
      picks[0] = picks[1] = null;
      notifyListeners();
    }
  }

  /// [zone] is absolute (0 left, 1 centre, 2 right from player 1's side). Returns true if accepted.
  bool pick(int player, int zone) {
    if (forward('pick', [player, zone])) return false;
    if (finished || showingResult || zone < 0 || zone > 2 || picks[player] != null) return false;
    picks[player] = zone;
    if (picks[0] != null && picks[1] != null) {
      final k = Kick(kicker, picks[kicker]!, picks[keeper]!);
      kicks.add(k);
      if (k.goal) goals[k.kicker]++;
      _nextAt = _now + showMs;
    }
    notifyListeners();
    return true;
  }
}

final penaltyInfo = LocalGameInfo(
  id: 'penalty',
  title: 'Penalty Shootout',
  emoji: '⚽',
  color: const Color(0xFF2FB36D),
  tagline: 'Shoot, dive, score!',
  rules: const [
    'You take turns being the kicker and the goalkeeper.',
    'Both secretly pick LEFT, MIDDLE or RIGHT on your own side.',
    'Keeper picks the same side as the shot = SAVE. Otherwise GOAL!',
    '5 kicks each, then sudden death.',
  ],
  scoreUnit: 'goals',
  splitScreen: true,
  online: RelaySpec<PenaltyLogic>(
    create: (n) => PenaltyLogic(),
    save: (g) => {
      'goals': g.goals,
      'kicks': [for (final k in g.kicks) [k.kicker, k.shot, k.dive]],
      // Only whether each player has picked: the side stays secret until both have.
      'locked': [for (final p in g.picks) p != null],
      'showing': g.showingResult,
    },
    load: (g, s, me) {
      g.goals.setAll(0, ints(s['goals']));
      g.kicks
        ..clear()
        ..addAll([for (final k in s['kicks'] as List) Kick(asInt((k as List)[0]), asInt(k[1]), asInt(k[2]))]);
      final locked = (s['locked'] as List).cast<bool>();
      for (var i = 0; i < 2; i++) {
        g.picks[i] = locked[i] ? (g.picks[i] ?? 1) : null;
      }
      g._nextAt = s['showing'] == true ? 1 << 40 : null;
    },
    apply: (g, from, name, a) {
      if (name == 'pick' && asInt(a[0]) == from) g.pick(from, asInt(a[1]));
    },
    view: (context, g, players, me) => Column(children: [
      ScoreMiddleBar(players: players, scores: g.scores, label: g.kickNo < 2 * g.kicksEach ? 'KICK ${g.kickNo ~/ 2 + 1} OF ${g.kicksEach}' : 'SUDDEN DEATH'),
      Expanded(child: _PenaltyHalf(player: players[me], index: me, g: g)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<PenaltyLogic>(
    create: () => PenaltyLogic(),
    onFinished: onFinished,
    builder: (context, g) => SplitScreen(
      middle: ScoreMiddleBar(players: players, scores: g.scores, label: g.kickNo < 2 * g.kicksEach ? 'KICK ${g.kickNo ~/ 2 + 1} OF ${g.kicksEach}' : 'SUDDEN DEATH'),
      half: (i) => _PenaltyHalf(player: players[i], index: i, g: g),
    ),
  ),
);

class _PenaltyHalf extends StatelessWidget {
  final GpPlayer player;
  final int index;
  final PenaltyLogic g;
  const _PenaltyHalf({required this.player, required this.index, required this.g});

  // Player 2 sees the screen rotated, so their left is player 1's right.
  int toAbsolute(int shown) => index == 0 ? shown : 2 - shown;

  @override
  Widget build(BuildContext context) {
    final kick = g.lastKick;
    final kicking = g.kicker == index;
    String title;
    String sub;
    if (g.showingResult && kick != null) {
      final mine = kick.kicker == index;
      title = kick.goal ? (mine ? '⚽ GOAL!' : 'They scored…') : (mine ? 'SAVED!' : '🧤 GREAT SAVE!');
      sub = 'Shot ${_side(kick.shot)} · dive ${_side(kick.dive)}';
    } else if (g.picks[index] != null) {
      title = 'LOCKED IN ✓';
      sub = 'Waiting for your rival…';
    } else {
      title = kicking ? 'YOU SHOOT' : 'YOU SAVE';
      sub = kicking ? 'Pick where to shoot' : 'Pick where to dive';
    }
    const labels = ['LEFT', 'MIDDLE', 'RIGHT'];
    final canPick = !g.showingResult && g.picks[index] == null && !g.finished;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          PlayerTagSmall(player: player),
          const Spacer(),
          Text(kicking ? 'KICKER' : 'KEEPER', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ]),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ]),
            ),
          ),
        ),
        // The goal mouth with three zones.
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white, width: 6), left: BorderSide(color: Colors.white, width: 6), right: BorderSide(color: Colors.white, width: 6)),
          ),
          child: Row(children: [
            for (var shown = 0; shown < 3; shown++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Material(
                    color: _zoneColor(toAbsolute(shown), kick),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: canPick
                          ? () {
                              if (g.pick(index, toAbsolute(shown))) HapticFeedback.selectionClick().ignore();
                            }
                          : null,
                      child: SizedBox(
                        height: 70,
                        child: Center(child: Text(labels[shown], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Color _zoneColor(int zone, Kick? kick) {
    if (g.showingResult && kick != null) {
      if (zone == kick.shot && zone == kick.dive) return GpColors.no;
      if (zone == kick.shot) return GpColors.yes;
      if (zone == kick.dive) return const Color(0xFF7A7A90);
      return Colors.white12;
    }
    return g.picks[index] == zone ? player.color : player.color.withValues(alpha: 0.35);
  }

  // Describe the zone from this player's point of view.
  String _side(int absolute) => const ['left', 'middle', 'right'][index == 0 ? absolute : 2 - absolute];
}
