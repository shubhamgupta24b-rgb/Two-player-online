import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';

/// Battleship for 2 on an 8x8 sea. Fleets are placed at random. Take turns firing at the
/// other sea: a hit lets you fire again, a miss passes the turn. Sink the whole fleet to win.
class BattleshipLogic extends LocalGameLogic {
  static const size = 8;
  static const fleet = [4, 3, 3, 2, 2];

  /// ships[player] = list of ships, each a list of cells (row * size + col).
  final List<List<List<int>>> ships;
  final List<Set<int>> shots = [{}, {}]; // shots[p] = cells player p fired at (on the other sea)
  int turn = 0;
  int? lastShot;
  String message = 'Fire at the enemy sea!';
  int revealedFor = -1; // one phone: whose view is uncovered (not part of the online state)

  BattleshipLogic({Random? random}) : ships = [randomFleet(random ?? Random()), randomFleet(random ?? Random())];

  static List<List<int>> randomFleet(Random rng) {
    final taken = <int>{};
    final out = <List<int>>[];
    for (final len in fleet) {
      while (true) {
        final across = rng.nextBool();
        final r = rng.nextInt(across ? size : size - len + 1), c = rng.nextInt(across ? size - len + 1 : size);
        final cells = [for (var i = 0; i < len; i++) across ? r * size + c + i : (r + i) * size + c];
        // Ships don't touch, not even corner to corner (easier to read on a small board).
        final near = {
          for (final x in cells)
            for (var dr = -1; dr <= 1; dr++)
              for (var dc = -1; dc <= 1; dc++)
                if ((x ~/ size + dr) >= 0 && (x ~/ size + dr) < size && (x % size + dc) >= 0 && (x % size + dc) < size) (x ~/ size + dr) * size + x % size + dc,
        };
        if (near.any(taken.contains)) continue;
        taken.addAll(cells);
        out.add(cells);
        break;
      }
    }
    return out;
  }

  int other(int p) => 1 - p;
  bool isShip(int player, int cell) => ships[player].any((s) => s.contains(cell));
  bool sunk(int player, List<int> ship) => ship.every(shots[other(player)].contains);
  int shipsLeft(int player) => ships[player].where((s) => !sunk(player, s)).length;

  @override
  bool get finished => shipsLeft(0) == 0 || shipsLeft(1) == 0;
  @override
  List<int> get scores => [shipsLeft(1) == 0 ? 1 : 0, shipsLeft(0) == 0 ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  /// The player whose turn it is fires at [cell] of the other sea. Returns false if not allowed.
  bool fire(int cell) {
    if (forward('fire', [cell])) return false;
    if (finished || cell < 0 || cell >= size * size || shots[turn].contains(cell)) return false;
    shots[turn].add(cell);
    lastShot = cell;
    final target = other(turn);
    final ship = ships[target].where((s) => s.contains(cell)).firstOrNull;
    if (ship == null) {
      message = '💦 Miss!';
      turn = target;
    } else if (sunk(target, ship)) {
      message = finished ? '🚢 Whole fleet sunk!' : '💥 Sunk a ship of ${ship.length}! Fire again';
    } else {
      message = '🔥 Hit! Fire again';
    }
    notifyListeners();
    return true;
  }

  void reveal(int player) {
    revealedFor = player;
    notifyListeners();
  }
}

/// Hunt and target: finish off a damaged ship along its line, otherwise search on a
/// checkerboard (every ship covers at least one black square).
int battleshipBotPick(BattleshipLogic g, int me, Random rng) {
  final enemy = g.other(me);
  final mine = g.shots[me];
  bool open(int r, int c) => r >= 0 && r < BattleshipLogic.size && c >= 0 && c < BattleshipLogic.size && !mine.contains(r * BattleshipLogic.size + c);
  // Hits on ships that aren't sunk yet.
  final hits = [for (final c in mine) if (g.isShip(enemy, c) && !g.sunk(enemy, g.ships[enemy].firstWhere((s) => s.contains(c)))) c];
  final targets = <int>[];
  if (hits.length >= 2) {
    // Keep going along the line the hits make.
    final sameRow = hits.every((h) => h ~/ 8 == hits.first ~/ 8);
    final cols = hits.map((h) => h % 8).toList()..sort();
    final rows = hits.map((h) => h ~/ 8).toList()..sort();
    if (sameRow) {
      final r = hits.first ~/ 8;
      if (open(r, cols.first - 1)) targets.add(r * 8 + cols.first - 1);
      if (open(r, cols.last + 1)) targets.add(r * 8 + cols.last + 1);
    } else {
      final c = hits.first % 8;
      if (open(rows.first - 1, c)) targets.add((rows.first - 1) * 8 + c);
      if (open(rows.last + 1, c)) targets.add((rows.last + 1) * 8 + c);
    }
  }
  if (targets.isEmpty) {
    for (final h in hits) {
      final r = h ~/ 8, c = h % 8;
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        if (open(r + dr, c + dc)) targets.add((r + dr) * 8 + c + dc);
      }
    }
  }
  if (targets.isNotEmpty) return targets[rng.nextInt(targets.length)];
  final hunt = [for (var i = 0; i < 64; i++) if (!mine.contains(i) && (i ~/ 8 + i % 8).isEven) i];
  final any = [for (var i = 0; i < 64; i++) if (!mine.contains(i)) i];
  final pool = hunt.isNotEmpty ? hunt : any;
  return pool[rng.nextInt(pool.length)];
}

final battleshipInfo = LocalGameInfo(
  id: 'battleship',
  title: 'Battleship',
  emoji: '🚢',
  color: const Color(0xFF1E88E5),
  tagline: 'Find their fleet before they find yours!',
  rules: const [
    'Each of you has a hidden fleet of 5 ships on an 8×8 sea.',
    'On your turn, tap a square of the enemy sea to fire. Hit = fire again, miss = their turn.',
    'Sink every enemy ship to win!',
    'On one phone, pass it over between turns and don\'t peek at the other fleet.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  bot: botFor<BattleshipLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst((g.shots[0].length, g.shots[1].length), now, 700, 1400)) return;
    g.fire(battleshipBotPick(g, b.seat, b.rng));
  }),
  online: RelaySpec<BattleshipLogic>(
    create: (n) => BattleshipLogic(),
    save: (g) => {
      'ships': [for (final fleet in g.ships) [for (final s in fleet) ...s]],
      'shots': [for (final s in g.shots) s.toList()],
      'turn': g.turn,
      'last': g.lastShot,
      'msg': g.message,
    },
    load: (g, s, me) {
      final fleets = s['ships'] as List;
      for (var p = 0; p < 2; p++) {
        final cells = ints(fleets[p]);
        var i = 0;
        for (var k = 0; k < BattleshipLogic.fleet.length; k++) {
          g.ships[p][k] = cells.sublist(i, i + BattleshipLogic.fleet[k]);
          i += BattleshipLogic.fleet[k];
        }
      }
      final shots = s['shots'] as List;
      for (var p = 0; p < 2; p++) {
        g.shots[p]
          ..clear()
          ..addAll(ints(shots[p]));
      }
      g.turn = asInt(s['turn']);
      g.lastShot = nInt(s['last']);
      g.message = s['msg'] as String;
    },
    apply: (g, from, name, a) {
      if (name == 'fire' && from == g.turn) g.fire(asInt(a[0]));
    },
    view: (context, g, players, me) => _BattleTable(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<BattleshipLogic>(
    create: () => BattleshipLogic(),
    onFinished: onFinished,
    builder: (context, g) => _BattleTable(
      g: g,
      players: players,
      me: BotScope.humanSeat(context),
      bots: {for (var i = 0; i < 2; i++) if (BotScope.isBot(context, i)) i},
    ),
  ),
);

class _BattleTable extends StatelessWidget {
  final BattleshipLogic g;
  final List<GpPlayer> players;
  final int? me;
  final Set<int> bots;
  const _BattleTable({required this.g, required this.players, this.me, this.bots = const {}});

  @override
  Widget build(BuildContext context) {
    final passing = me == null;
    // Whose seas are shown: this phone's player, or (passing the phone) the player whose turn it is.
    final viewer = me ?? (bots.contains(g.turn) ? g.other(g.turn) : g.turn);
    final covered = passing && !bots.contains(g.turn) && g.revealedFor != g.turn && !g.finished;
    final myTurn = viewer == g.turn && !bots.contains(g.turn) && !g.finished;
    final enemy = g.other(viewer);
    final current = players[g.turn];
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(children: [
          Row(children: [
            const PauseButton(),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                g.finished ? '🏆 ${players[g.scores[0] == 1 ? 0 : 1].name.toUpperCase()} WINS!' : (myTurn ? (passing ? '${current.whose} TURN: FIRE!' : 'YOUR TURN: FIRE!') : '${current.name} is aiming…'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: current.color, fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(g.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          _SeaLabel('🎯 ENEMY SEA · ${g.shipsLeft(enemy)} ships left', players[enemy].color),
          Expanded(
            flex: 3,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _Sea(g: g, owner: enemy, showShips: g.finished, onFire: myTurn && !covered ? g.fire : null),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SeaLabel('🛡 YOUR FLEET · ${g.shipsLeft(viewer)} ships left', players[viewer].color),
          Expanded(flex: 2, child: Center(child: AspectRatio(aspectRatio: 1, child: _Sea(g: g, owner: viewer, showShips: true)))),
        ]),
      ),
      if (covered) _PassCover(player: current, onReveal: () => g.reveal(g.turn)),
    ]);
  }
}

class _SeaLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SeaLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: TextStyle(color: Color.lerp(color, Colors.white, 0.4), fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1)),
      );
}

/// One player's sea. [onFire] makes its squares tappable.
class _Sea extends StatelessWidget {
  final BattleshipLogic g;
  final int owner;
  final bool showShips;
  final bool Function(int cell)? onFire;
  const _Sea({required this.g, required this.owner, required this.showShips, this.onFire});

  @override
  Widget build(BuildContext context) {
    final shotsHere = g.shots[g.other(owner)];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: onFire != null ? GpColors.accent : Colors.white24, width: onFire != null ? 3 : 1.5),
      ),
      child: GridView.count(
        crossAxisCount: BattleshipLogic.size,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var cell = 0; cell < 64; cell++)
            Builder(builder: (context) {
              final shot = shotsHere.contains(cell);
              final ship = g.isShip(owner, cell);
              final sunkShip = ship && g.sunk(owner, g.ships[owner].firstWhere((s) => s.contains(cell)));
              final color = sunkShip
                  ? const Color(0xFF5D4037)
                  : ship && (showShips || shot)
                      ? const Color(0xFF90A4AE)
                      : Colors.white.withValues(alpha: 0.08);
              return GestureDetector(
                onTap: onFire == null || shot
                    ? null
                    : () {
                        HapticFeedback.mediumImpact().ignore();
                        onFire!(cell);
                      },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    border: cell == g.lastShot && shot ? Border.all(color: GpColors.accent, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  child: shot ? FittedBox(child: Text(ship ? (sunkShip ? '💥' : '🔥') : '•', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18))) : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PassCover extends StatelessWidget {
  final GpPlayer player;
  final VoidCallback onReveal;
  const _PassCover({required this.player, required this.onReveal});
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Container(
          color: GpColors.bgBottom.withValues(alpha: 0.98),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('📲', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            const Text('PASS THE PHONE TO', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900, letterSpacing: 2)),
            Text(player.name.toUpperCase(), style: TextStyle(color: player.color, fontWeight: FontWeight.w900, fontSize: 32)),
            const SizedBox(height: 6),
            const Text('No peeking at the other fleet! 🙈', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            GpButton('SHOW MY SEA', icon: Icons.visibility_rounded, color: player.color, textColor: Colors.white, onPressed: onReveal),
          ]),
        ),
      );
}
