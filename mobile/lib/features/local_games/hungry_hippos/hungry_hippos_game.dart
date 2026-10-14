import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';

class _Marble {
  double x, y, vx, vy;
  bool taken = false;
  _Marble(this.x, this.y, this.vx, this.vy);
}

/// Hungry Hippos: marbles bounce in the middle. Tap your side to snap. The first to 5,
/// or the highest when time runs out, wins.
class HippoLogic extends LocalGameLogic {
  final int players;
  final List<_Marble> marbles;
  final List<int> got;
  final List<int> nextChomp;
  int? winner;
  int now = 0;
  int _last = 0;
  static const limit = 20000;
  static const goal = 5;

  HippoLogic({this.players = 2, Random? random})
      : got = List.filled(players, 0),
        nextChomp = List.filled(players, 0),
        marbles = _deal(random ?? Random());

  static List<_Marble> _deal(Random rng) => [
        for (var i = 0; i < 10; i++)
          _Marble(0.3 + rng.nextDouble() * 0.4, 0.3 + rng.nextDouble() * 0.4,
              (rng.nextDouble() - 0.5) * 0.35, (rng.nextDouble() - 0.5) * 0.35),
      ];

  @override
  bool get finished => winner != null || now >= limit;
  @override
  List<int> get scores => got;

  void chomp(int player) {
    if (forward('chomp', [player])) return;
    if (finished || player < 0 || player >= players || now < nextChomp[player])
      return;
    nextChomp[player] = now + 380;
    final mouth = _mouth(player);
    _Marble? best;
    var bestD = 0.12;
    for (final m in marbles) {
      if (m.taken) continue;
      final d = (m.x - mouth.dx).abs() + (m.y - mouth.dy).abs();
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    if (best != null) {
      best.taken = true;
      got[player]++;
      if (got[player] >= goal && winner == null) winner = player;
    }
    notifyListeners();
  }

  Offset _mouth(int p) => switch (p) {
        0 => const Offset(0.5, 0.86),
        1 => const Offset(0.5, 0.14),
        2 => const Offset(0.14, 0.5),
        _ => const Offset(0.86, 0.5),
      };

  @override
  void update(int ms) {
    final dt = (_last == 0 ? 16 : (ms - _last).clamp(0, 40)) / 1000.0;
    _last = ms;
    now = ms;
    if (winner != null) {
      notifyListeners();
      return;
    }
    if (now < limit) {
      for (final m in marbles) {
        if (m.taken) continue;
        m.x += m.vx * dt;
        m.y += m.vy * dt;
        if (m.x < 0.22 || m.x > 0.78) m.vx = -m.vx;
        if (m.y < 0.22 || m.y > 0.78) m.vy = -m.vy;
        m.x = m.x.clamp(0.22, 0.78);
        m.y = m.y.clamp(0.22, 0.78);
      }
    } else {
      var best = 0;
      for (var i = 1; i < players; i++) {
        if (got[i] > got[best]) best = i;
      }
      if (got.where((n) => n == got[best]).length == 1) winner = best;
    }
    notifyListeners();
  }
}

final hungryHipposInfo = LocalGameInfo(
  id: 'hungry_hippos',
  title: 'Hungry Hippos',
  emoji: '🦛',
  color: const Color(0xFF7CB342),
  tagline: 'Snap the marbles on your side.',
  rules: const [
    'Marbles bounce in the middle. Tap Chomp when one is near your hippo.',
    'You can only snap a few times a second, so timing matters.',
    'First to 5 marbles wins. Otherwise the most marbles when time runs out.',
  ],
  scoreUnit: 'marbles',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 4,
  bot: botFor<HippoLogic>((g, b, now) {
    if (g.finished || now < g.nextChomp[b.seat]) return;
    g.chomp(b.seat);
  }),
  online: RelaySpec<HippoLogic>(
    create: (n) => HippoLogic(players: n),
    save: (g) => {
      'got': g.got,
      'next': g.nextChomp,
      'winner': g.winner,
      'now': g.now,
      'marbles': [
        for (final m in g.marbles) [m.x, m.y, m.vx, m.vy, m.taken]
      ],
    },
    load: (g, s, me) {
      g.got.setAll(0, ints(s['got']));
      g.nextChomp.setAll(0, ints(s['next']));
      g.winner = nInt(s['winner']);
      g.now = asInt(s['now']);
      final raw = s['marbles'] as List;
      for (var i = 0; i < raw.length && i < g.marbles.length; i++) {
        final m = raw[i] as List;
        g.marbles[i]
          ..x = (m[0] as num).toDouble()
          ..y = (m[1] as num).toDouble()
          ..vx = (m[2] as num).toDouble()
          ..vy = (m[3] as num).toDouble()
          ..taken = m[4] == true;
      }
    },
    apply: (g, from, name, a) {
      if (name == 'chomp' && a.isNotEmpty && asInt(a[0]) == from) g.chomp(from);
    },
    view: (context, g, players, me) =>
        _HippoView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<HippoLogic>(
    create: () => HippoLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _HippoView(g: g, players: players, me: -1),
  ),
);

class _HippoView extends StatelessWidget {
  final HippoLogic g;
  final List<GpPlayer> players;
  final int me;
  const _HippoView({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) {
    final left = g.finished ? 0 : ((HippoLogic.limit - g.now) / 1000).ceil();
    return Column(children: [
      GameHud(
          players: players,
          scores: g.got,
          trailing: Text('${left}s',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(18)),
            child: CustomPaint(
                painter: _HippoPainter(g, players.map((p) => p.color).toList()),
                child: const SizedBox.expand()),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(children: [
          for (final seat
              in (me < 0 ? [for (var i = 0; i < players.length; i++) i] : [me]))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: KitButton(players[seat].name,
                    onPressed: g.finished ? null : () => g.chomp(seat)),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _HippoPainter extends CustomPainter {
  final HippoLogic g;
  final List<Color> colors;
  _HippoPainter(this.g, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    Offset at(double x, double y) => Offset(x * size.width, y * size.height);
    for (var i = 0; i < g.players; i++) {
      final mouth = switch (i) {
        0 => const Offset(0.5, 0.9),
        1 => const Offset(0.5, 0.1),
        2 => const Offset(0.1, 0.5),
        _ => const Offset(0.9, 0.5)
      };
      canvas.drawCircle(at(mouth.dx, mouth.dy), 28,
          Paint()..color = colors[i % colors.length]);
      canvas.drawCircle(at(mouth.dx, mouth.dy) + const Offset(8, -4), 4,
          Paint()..color = Colors.white);
    }
    for (final m in g.marbles) {
      if (m.taken) continue;
      canvas.drawCircle(
          at(m.x, m.y), 8, Paint()..color = const Color(0xFFECEFF1));
    }
  }

  @override
  bool shouldRepaint(_HippoPainter old) => true;
}
