import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/table_physics.dart';
import '../shell/ticking_play.dart';

/// Carrom. Player 1 is white, player 2 is black. Pocket your coins. The queen only
/// counts if you pocket one of your own coins before the turn ends. Pocketing the
/// striker gives one of your coins back. Clear your coins with the queen covered to win.
class CarromLogic extends LocalGameLogic {
  static const pockets = [
    Pocket(0.06, 0.06, 0.055),
    Pocket(0.94, 0.06, 0.055),
    Pocket(0.06, 0.94, 0.055),
    Pocket(0.94, 0.94, 0.055),
  ];
  final List<Disk> disks = [];
  int turn = 0;
  bool moving = false;
  int queen =
      -1; // -1 on the board, -2 waiting to be covered, else the player who covered it
  int? winner;
  String note = 'Aim, set the power, then shoot.';
  int _last = 0;
  int? _shotAt;
  final List<int> _sunk = [];

  CarromLogic() {
    disks.add(Disk(x: 0.5, y: 0.86, r: 0.045, id: 0, group: 0));
    disks.add(Disk(x: 0.5, y: 0.5, r: 0.034, id: 1, group: 3));
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      disks.add(Disk(
        x: 0.5 + cos(a) * (i.isEven ? 0.09 : 0.15),
        y: 0.5 + sin(a) * (i.isEven ? 0.09 : 0.15),
        r: 0.032,
        id: i + 2,
        group: i.isEven ? 1 : 2,
      ));
    }
  }

  int get mine => turn == 0 ? 1 : 2;
  int left(int group) => disks.where((d) => d.group == group && !d.sunk).length;
  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => [winner == 0 ? 1 : 0, winner == 1 ? 1 : 0];

  void shoot(int player, double angle, double power) {
    if (forward('shoot', [player, angle, power])) return;
    if (moving || finished || player != turn) return;
    angle = angle.clamp(-1.1, 1.1);
    power = power.clamp(0.6, 3.2);
    final s = disks.first;
    s.sunk = false;
    s.x = 0.5;
    s.y = player == 0 ? 0.84 : 0.16;
    s.vx = sin(angle) * power;
    s.vy = player == 0 ? -cos(angle).abs() * power : cos(angle).abs() * power;
    moving = true;
    _shotAt = null;
    _sunk.clear();
    notifyListeners();
  }

  @override
  void update(int ms) {
    if (!moving) return;
    _shotAt ??= ms;
    final dt = (_last == 0 ? 16 : (ms - _last).clamp(0, 40)) / 1000.0;
    _last = ms;
    for (var n = 0; n < 2; n++) {
      _sunk.addAll(stepDisks(disks, w: 1, h: 1, pockets: pockets, dt: dt));
    }
    final timedOut = ms - _shotAt! > 8000;
    if (timedOut) {
      for (final d in disks) {
        d.vx = 0;
        d.vy = 0;
      }
    }
    if (timedOut || disksSettled(disks)) _finishShot();
    notifyListeners();
  }

  void _finishShot() {
    moving = false;
    _shotAt = null;
    final me = turn;
    final myGroup = me == 0 ? 1 : 2;
    var keep = false;
    var foul = false;
    for (final id in _sunk) {
      final d = disks.firstWhere((x) => x.id == id);
      if (d.group == 0) {
        foul = true;
        d.sunk = false;
        d.x = 0.5;
        d.y = me == 0 ? 0.84 : 0.16;
      } else if (d.group == 3) {
        queen = -2;
      } else if (d.group == myGroup) {
        keep = true;
        if (queen == -2) queen = me;
      }
    }
    if (queen == -2 && !keep) {
      final q = disks.firstWhere((d) => d.group == 3);
      q.sunk = false;
      q.x = 0.5;
      q.y = 0.5;
      queen = -1;
    }
    if (foul) {
      final back = disks.where((d) => d.group == myGroup && d.sunk);
      if (back.isNotEmpty) {
        final d = back.first;
        d.sunk = false;
        d.x = 0.5;
        d.y = 0.42;
      }
      keep = false;
      note = 'Striker pocketed. A coin comes back.';
    } else if (keep) {
      note = 'Your coin. Shoot again.';
    } else {
      note = 'Turn passes.';
    }
    if (left(myGroup) == 0 && queen == me) {
      winner = me;
      note = 'Board clear.';
    } else if (!keep || foul) {
      turn = 1 - turn;
    }
    if (winner == null && left(myGroup) == 0 && queen != me) {
      final back = disks.where((d) => d.group == myGroup && d.sunk);
      if (back.isEmpty) return;
      final coin = back.last;
      coin.sunk = false;
      coin.x = 0.5;
      coin.y = 0.58;
      note = 'Cover the queen before your last coin.';
    }
  }
}

final carromInfo = LocalGameInfo(
  id: 'carrom',
  title: 'Carrom',
  emoji: '🎯',
  color: const Color(0xFF8D6E63),
  tagline: 'Pocket your coins. Cover the queen.',
  rules: const [
    'Drag to aim, then release to shoot. The bar sets the power.',
    'White shoots from the bottom, black from the top. Pocket your own coins.',
    'The red queen counts only if you pocket your own coin before the turn ends.',
    'Pocketing the striker returns one of your coins. Clear your coins with the queen covered to win.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<CarromLogic>((g, b, now) {
    if (g.moving || g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.left(1) + g.left(2), now, 400, 900)) return;
    g.shoot(b.seat, (b.rng.nextDouble() - 0.5) * 0.8, 1.4 + b.rng.nextDouble());
  }),
  online: RelaySpec<CarromLogic>(
    create: (n) => CarromLogic(),
    save: (g) => {
      'turn': g.turn,
      'moving': g.moving,
      'queen': g.queen,
      'winner': g.winner,
      'note': g.note,
      'last': g._last,
      'shot': g._shotAt,
      'sunk': g._sunk,
      'disks': [
        for (final d in g.disks) [d.x, d.y, d.vx, d.vy, d.sunk]
      ],
    },
    load: (g, s, me) {
      g.turn = asInt(s['turn']);
      g.moving = s['moving'] == true;
      g.queen = asInt(s['queen']);
      g.winner = nInt(s['winner']);
      g.note = s['note'] as String;
      g._last = asInt(s['last']);
      g._shotAt = nInt(s['shot']);
      g._sunk
        ..clear()
        ..addAll(ints(s['sunk']));
      final raw = s['disks'] as List;
      for (var i = 0; i < raw.length && i < g.disks.length; i++) {
        final m = raw[i] as List;
        g.disks[i]
          ..x = (m[0] as num).toDouble()
          ..y = (m[1] as num).toDouble()
          ..vx = (m[2] as num).toDouble()
          ..vy = (m[3] as num).toDouble()
          ..sunk = m[4] == true;
      }
    },
    apply: (g, from, name, a) {
      if (name == 'shoot' && a.length >= 3 && asInt(a[0]) == from)
        g.shoot(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) =>
        _CarromView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<CarromLogic>(
    create: CarromLogic.new,
    onFinished: onFinished,
    builder: (context, g) => _CarromView(g: g, players: players, me: -1),
  ),
);

class _CarromView extends StatefulWidget {
  final CarromLogic g;
  final List<GpPlayer> players;
  final int me;
  const _CarromView({required this.g, required this.players, required this.me});
  @override
  State<_CarromView> createState() => _CarromViewState();
}

class _CarromViewState extends State<_CarromView> {
  double aim = 0;
  double power = 1.6;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final actor = widget.me < 0 ? g.turn : widget.me;
    final mine = actor == g.turn && !g.moving && !g.finished;
    return Column(children: [
      GameHud(
          players: widget.players,
          turn: g.finished ? null : g.turn,
          scores: [g.left(2), g.left(1)]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(g.note, style: const TextStyle(color: Colors.white70)),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: GestureDetector(
              onPanUpdate: mine
                  ? (d) {
                      setState(
                          () => aim = (aim + d.delta.dx / 80).clamp(-1.1, 1.1));
                    }
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: const Color(0xFFC4A574),
                    borderRadius: BorderRadius.circular(12)),
                child: CustomPaint(
                    painter: _CarromPainter(g, aim),
                    child: const SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          const Text('Power', style: TextStyle(color: Colors.white70)),
          Expanded(
            child: Slider(
              value: power,
              min: 0.6,
              max: 3.2,
              onChanged: mine ? (v) => setState(() => power = v) : null,
            ),
          ),
          KitButton('Shoot',
              onPressed: mine ? () => g.shoot(actor, aim, power) : null),
        ]),
      ),
    ]);
  }
}

class _CarromPainter extends CustomPainter {
  final CarromLogic g;
  final double aim;
  _CarromPainter(this.g, this.aim);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
            const Radius.circular(8)),
        Paint()..color = const Color(0xFFE6D3A3));
    for (final p in CarromLogic.pockets) {
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.r * s,
          Paint()..color = const Color(0xFF1C1A17));
    }
    for (final d in g.disks) {
      if (d.sunk && d.group != 0) continue;
      final c = Offset(d.x * size.width, d.y * size.height);
      final color = switch (d.group) {
        0 => const Color(0xFF1565C0),
        1 => Colors.white,
        2 => const Color(0xFF1C1A17),
        _ => const Color(0xFFE53935)
      };
      canvas.drawCircle(c, d.r * s, Paint()..color = color);
    }
    final striker = g.disks.first;
    if (!g.moving) {
      final from = Offset(
          striker.x * size.width, (g.turn == 0 ? 0.84 : 0.16) * size.height);
      final dir =
          Offset(sin(aim), g.turn == 0 ? -cos(aim).abs() : cos(aim).abs());
      canvas.drawLine(
          from,
          from + dir * 70,
          Paint()
            ..color = const Color(0xFF1565C0)
            ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(_CarromPainter old) => true;
}
