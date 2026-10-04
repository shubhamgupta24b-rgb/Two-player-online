import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../party/party_widgets.dart' show PassCover;
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

// Board palette: open sea, grey hulls.
const _sea = [Color(0xFF0B3C7A), Color(0xFF125AA8)];
const _hull = Color(0xFF8C9BA5);
const _wreck = Color(0xFF4E3B31);

class _BattleTable extends StatelessWidget {
  final BattleshipLogic g;
  final List<GpPlayer> players;
  final int? me;
  final Set<int> bots;
  const _BattleTable({required this.g, required this.players, this.me, this.bots = const {}});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final passing = me == null;
    // Whose seas are shown: this phone's player, or (passing the phone) the player whose turn it is.
    final viewer = me ?? (bots.contains(g.turn) ? g.other(g.turn) : g.turn);
    final covered = passing && !bots.contains(g.turn) && g.revealedFor != g.turn && !g.finished;
    final myTurn = viewer == g.turn && !bots.contains(g.turn) && !g.finished;
    final enemy = g.other(viewer);
    final current = players[g.turn];
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.s),
        child: Column(children: [
          GameHud(players: players, turn: g.finished ? null : g.turn, extra: (i) => '🚢${g.shipsLeft(i)}'),
          GameStatus(
            player: current,
            height: 44,
            turnText: myTurn ? (passing ? '${current.whose} TURN: FIRE!' : 'YOUR TURN: FIRE!') : '${current.name} is aiming…',
            message: g.finished ? '🏆 ${players[g.scores[0] == 1 ? 0 : 1].name.toUpperCase()} WINS!' : null,
          ),
          if (g.message.isNotEmpty) Semantics(liveRegion: true, child: Text(g.message, textAlign: TextAlign.center, style: t.styles.bodyStrong)),
          const SizedBox(height: Space.xs),
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
          const SizedBox(height: Space.s),
          _SeaLabel('🛡 YOUR FLEET · ${g.shipsLeft(viewer)} ships left', players[viewer].color),
          Expanded(flex: 2, child: Center(child: AspectRatio(aspectRatio: 1, child: _Sea(g: g, owner: viewer, showShips: true)))),
        ]),
      ),
      if (covered) PassCover(player: current, holdLabel: 'HOLD TO SEE YOUR SEA', note: 'No peeking at the other fleet! 🙈', onReveal: () => g.reveal(g.turn)),
    ]);
  }
}

class _SeaLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SeaLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: Text(text, style: context.tk.styles.label.copyWith(color: Color.lerp(color, Colors.white, 0.45))),
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
      padding: const EdgeInsets.all(Space.xs),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _sea, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: Radii.rMd,
        border: Border.all(color: onFire != null ? Brand.gold : Colors.white24, width: onFire != null ? 3 : 1.5),
        boxShadow: onFire != null ? [BoxShadow(color: Brand.gold.withValues(alpha: 0.35), blurRadius: 14)] : null,
      ),
      child: CustomPaint(
        painter: const _Waves(),
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
                final visible = ship && (showShips || shot);
                return Semantics(
                  button: onFire != null && !shot,
                  label: '${String.fromCharCode(65 + cell ~/ 8)}${cell % 8 + 1}: ${shot ? (ship ? (sunkShip ? 'sunk' : 'hit') : 'miss') : (visible ? 'ship' : 'water')}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onFire == null || shot
                        ? null
                        : () {
                            haptic(HapticWeight.medium);
                            final hit = g.isShip(owner, cell);
                            onFire!(cell);
                            GameAudio.sfx(hit ? 'boom' : 'pop');
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: sunkShip ? _wreck : (visible ? _hull : Colors.white.withValues(alpha: 0.06)),
                        gradient: visible && !sunkShip ? const LinearGradient(colors: [Color(0xFFB0BEC5), _hull], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
                        borderRadius: BorderRadius.circular(visible ? 6 : 3),
                        border: cell == g.lastShot && shot ? Border.all(color: Brand.gold, width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: shot
                          ? (ship
                              ? FittedBox(child: Text(sunkShip ? '💥' : '🔥', style: const TextStyle(fontSize: 18)))
                              : FractionallySizedBox(
                                  widthFactor: 0.5,
                                  heightFactor: 0.5,
                                  child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2))),
                                ))
                          : null,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Faint wave lines behind the sea grid.
class _Waves extends CustomPainter {
  const _Waves();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var y = size.height / 10; y < size.height; y += size.height / 7) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += size.width / 12) {
        path.quadraticBezierTo(x + size.width / 24, y - 4, x + size.width / 12, y);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}