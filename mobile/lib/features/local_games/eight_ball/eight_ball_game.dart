import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/table_physics.dart';
import '../shell/ticking_play.dart';

/// Eight ball. Solids and stripes are assigned by the first numbered ball pocketed.
/// Pocket the 8 after your group is clear to win. Pocket it early, or scratch while
/// pocketing it, and you lose.
class EightLogic extends LocalGameLogic {
  static const pockets = [
    Pocket(0.05, 0.08, 0.045),
    Pocket(0.95, 0.08, 0.045),
    Pocket(0.05, 0.92, 0.045),
    Pocket(0.95, 0.92, 0.045),
    Pocket(0.02, 0.5, 0.04),
    Pocket(0.98, 0.5, 0.04),
  ];
  final List<Disk> disks = [];
  int turn = 0;
  bool moving = false;
  int? groupOf; // player 0's group: 1 solids, 2 stripes
  int? winner;
  String note = 'Break to start.';
  int _last = 0;
  int? _shotAt;
  final List<int> _sunk = [];
  bool _hit = false;

  EightLogic() {
    disks.add(Disk(x: 0.28, y: 0.5, r: 0.028, id: 0, group: 0));
    const order = [1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15];
    var n = 0;
    for (var row = 0; row < 5; row++) {
      for (var k = 0; k <= row; k++) {
        final id = order[n++];
        disks.add(Disk(
          x: 0.62 + row * 0.032,
          y: 0.5 + (k - row / 2) * 0.034,
          r: 0.016,
          id: id,
          group: id == 8 ? 8 : (id < 8 ? 1 : 2),
        ));
      }
    }
  }

  int left(int group) => disks.where((d) => d.group == group && !d.sunk).length;
  @override
  bool get finished => winner != null;
  @override
  List<int> get scores => [winner == 0 ? 1 : 0, winner == 1 ? 1 : 0];

  void shoot(int player, double angle, double power) {
    if (forward('shoot', [player, angle, power])) return;
    if (moving || finished || player != turn) return;
    angle = angle.clamp(-1.2, 1.2);
    power = power.clamp(0.8, 3.4);
    final cue = disks.first;
    if (cue.sunk) {
      cue.sunk = false;
      cue.x = 0.28;
      cue.y = 0.5;
    }
    cue.vx = cos(angle) * power;
    cue.vy = sin(angle) * power;
    moving = true;
    _shotAt = null;
    _hit = false;
    _sunk.clear();
    notifyListeners();
  }

  @override
  void update(int ms) {
    if (!moving) return;
    _shotAt ??= ms;
    final dt = (_last == 0 ? 16 : (ms - _last).clamp(0, 40)) / 1000.0;
    _last = ms;
    final before = [for (final d in disks) (d.vx, d.vy)];
    _sunk.addAll(
        stepDisks(disks, w: 1, h: 1, pockets: pockets, friction: 1.3, dt: dt));
    if (!_hit) {
      final cue = disks.first;
      for (final d in disks.skip(1)) {
        if ((d.x - cue.x).abs() + (d.y - cue.y).abs() < 0.08 &&
            (cue.vx != before[0].$1 || cue.vy != before[0].$2)) {
          _hit = true;
        }
      }
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
    final mine =
        groupOf == null ? null : (me == 0 ? groupOf! : (groupOf == 1 ? 2 : 1));
    var keep = false;
    var foul = disks.first.sunk || !_hit;
    var pottedEight = false;
    for (final id in _sunk.toSet()) {
      final d = disks.firstWhere((x) => x.id == id);
      if (d.group == 0) continue;
      if (d.group == 8) {
        pottedEight = true;
        continue;
      }
      if (groupOf == null) {
        groupOf = me == 0 ? d.group : (d.group == 1 ? 2 : 1);
        keep = true;
      } else if (d.group == mine) {
        keep = true;
      } else {
        foul = true;
      }
    }
    final mineNow =
        groupOf == null ? null : (me == 0 ? groupOf! : (groupOf == 1 ? 2 : 1));
    final cleared = mineNow != null && left(mineNow) == 0;
    if (pottedEight) {
      if (cleared && !foul) {
        winner = me;
        note = 'Eight ball, clean.';
      } else {
        winner = 1 - me;
        note = 'Eight ball too early.';
      }
      return;
    }
    if (disks.first.sunk) {
      disks.first
        ..sunk = false
        ..x = 0.28
        ..y = 0.5
        ..vx = 0
        ..vy = 0;
      note = 'Scratch. Cue ball back.';
      keep = false;
    } else if (keep && !foul) {
      note = 'Still your visit.';
    } else {
      note = foul ? 'Foul. Other player.' : 'Nothing pocketed.';
      keep = false;
    }
    if (!keep) turn = 1 - turn;
  }
}

final eightBallInfo = LocalGameInfo(
  id: 'eight_ball',
  title: 'Eight Ball',
  emoji: '🎱',
  color: const Color(0xFF1B5E20),
  tagline: 'Pocket your group, then the 8.',
  rules: const [
    'Drag to aim and use the slider for power. The cue ball is the white one.',
    'The first numbered ball you pocket assigns solids or stripes.',
    'Pocket one of yours to shoot again. A scratch or the wrong ball is a foul.',
    'Pocket the 8 after your group is clear to win. Pocket it early and you lose.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<EightLogic>((g, b, now) {
    if (g.moving || g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst(g.left(1) + g.left(2) * 10, now, 400, 800)) return;
    g.shoot(b.seat, -0.2 + b.rng.nextDouble() * 0.5, 1.8 + b.rng.nextDouble());
  }),
  online: RelaySpec<EightLogic>(
    create: (n) => EightLogic(),
    save: (g) => {
      'turn': g.turn,
      'moving': g.moving,
      'group': g.groupOf,
      'winner': g.winner,
      'note': g.note,
      'last': g._last,
      'shot': g._shotAt,
      'hit': g._hit,
      'sunk': g._sunk,
      'disks': [
        for (final d in g.disks) [d.x, d.y, d.vx, d.vy, d.sunk]
      ],
    },
    load: (g, s, me) {
      g.turn = asInt(s['turn']);
      g.moving = s['moving'] == true;
      g.groupOf = nInt(s['group']);
      g.winner = nInt(s['winner']);
      g.note = s['note'] as String;
      g._last = asInt(s['last']);
      g._shotAt = nInt(s['shot']);
      g._hit = s['hit'] == true;
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
        _EightView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<EightLogic>(
    create: EightLogic.new,
    onFinished: onFinished,
    builder: (context, g) => _EightView(g: g, players: players, me: -1),
  ),
);

class _EightView extends StatefulWidget {
  final EightLogic g;
  final List<GpPlayer> players;
  final int me;
  const _EightView({required this.g, required this.players, required this.me});
  @override
  State<_EightView> createState() => _EightViewState();
}

class _EightViewState extends State<_EightView> {
  double aim = 0;
  double power = 2.2;
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final actor = widget.me < 0 ? g.turn : widget.me;
    final mine = actor == g.turn && !g.moving && !g.finished;
    final groups = g.groupOf == null
        ? 'Open table'
        : 'You: ${widget.me == 0 ? (g.groupOf == 1 ? 'solids' : 'stripes') : (g.groupOf == 1 ? 'stripes' : 'solids')}';
    return Column(children: [
      GameHud(
          players: widget.players,
          turn: g.finished ? null : g.turn,
          scores: [
            g.left(g.groupOf == 1 ? 2 : 1),
            g.left(g.groupOf == 1 ? 1 : 2)
          ]),
      Text('$groups · ${g.note}',
          style: const TextStyle(color: Colors.white70)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: 2,
            child: GestureDetector(
              onPanUpdate: mine
                  ? (d) => setState(
                      () => aim = (aim + d.delta.dx / 90).clamp(-1.2, 1.2))
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(12)),
                child: CustomPaint(
                    painter: _EightPainter(g, aim),
                    child: const SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(children: [
          Expanded(
              child: Slider(
                  value: power,
                  min: 0.8,
                  max: 3.4,
                  onChanged: mine ? (v) => setState(() => power = v) : null)),
          KitButton('Shoot',
              onPressed: mine ? () => g.shoot(actor, aim, power) : null),
        ]),
      ),
    ]);
  }
}

class _EightPainter extends CustomPainter {
  final EightLogic g;
  final double aim;
  _EightPainter(this.g, this.aim);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in EightLogic.pockets) {
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), 8,
          Paint()..color = const Color(0xFF101410));
    }
    for (final d in g.disks) {
      if (d.sunk) continue;
      final c = Offset(d.x * size.width, d.y * size.height);
      final color = switch (d.group) {
        0 => Colors.white,
        1 => const Color(0xFFFDD835),
        8 => const Color(0xFF111111),
        _ => const Color(0xFF1565C0)
      };
      canvas.drawCircle(c, d.group == 0 ? 7 : 6, Paint()..color = color);
      if (d.group == 2) {
        canvas.drawLine(
            c - const Offset(4, 0),
            c + const Offset(4, 0),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 2);
      }
    }
    final cue = g.disks.first;
    if (!g.moving && !cue.sunk) {
      final from = Offset(cue.x * size.width, cue.y * size.height);
      canvas.drawLine(
          from,
          from + Offset(cos(aim), sin(aim)) * 48,
          Paint()
            ..color = Colors.white70
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_EightPainter old) => true;
}
