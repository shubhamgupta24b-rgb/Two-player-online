import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';

/// Two bikes on the same track. Steer between three lanes. Hitting a barrier stops you.
/// First to the finish wins. Three tracks add more barriers.
class BikeRaceLogic extends LocalGameLogic {
  final int players;
  int track;
  final List<double> progress;
  final List<int> lane;
  final List<int> stunUntil;
  final List<(double at, int lane)> barriers;
  int? winner;
  int now = 0;
  int _last = 0;
  static const countdown = 2500;

  BikeRaceLogic({this.players = 2, this.track = 1, Random? random})
      : progress = List.filled(players, 0),
        lane = List.filled(players, 1),
        stunUntil = List.filled(players, 0),
        barriers = _barriers(track, random ?? Random(track * 17));

  static List<(double, int)> _barriers(int track, Random rng) {
    final n = 4 + track * 3;
    return [
      for (var i = 0; i < n; i++)
        (0.12 + i * (0.75 / n) + rng.nextDouble() * 0.04, rng.nextInt(3))
    ];
  }

  bool get racing => now >= countdown && winner == null;
  @override
  bool get finished => winner != null;
  @override
  List<int> get scores =>
      [for (var i = 0; i < players; i++) winner == i ? 1 : 0];

  void setTrack(int n) {
    if (now > 0) return;
    track = n.clamp(1, 3);
    barriers
      ..clear()
      ..addAll(_barriers(track, Random(track * 17)));
    notifyListeners();
  }

  void steer(int player, int dir) {
    if (forward('steer', [player, dir])) return;
    if (!racing || player < 0 || player >= players) return;
    lane[player] = (lane[player] + dir).clamp(0, 2);
    notifyListeners();
  }

  @override
  void update(int ms) {
    final dt = _last == 0 ? 16 : (ms - _last).clamp(0, 40);
    _last = ms;
    now = ms;
    if (!racing) {
      notifyListeners();
      return;
    }
    final pace = 0.16 + track * 0.03;
    for (var i = 0; i < players; i++) {
      if (now < stunUntil[i]) continue;
      progress[i] += pace * dt / 1000;
      for (final b in barriers) {
        if (b.$2 == lane[i] && (progress[i] - b.$1).abs() < 0.02) {
          stunUntil[i] = now + 700;
          progress[i] = max(0, progress[i] - 0.03);
        }
      }
      if (progress[i] >= 1 && winner == null) {
        progress[i] = 1;
        winner = i;
      }
    }
    notifyListeners();
  }
}

final bikeRaceInfo = LocalGameInfo(
  id: 'bike_race',
  title: 'Bike Racing',
  emoji: '🏍️',
  color: const Color(0xFF00897B),
  tagline: 'Steer the lanes. Reach the finish first.',
  rules: const [
    'After the countdown the bikes ride forward on their own.',
    'Left and right change lanes. A barrier in your lane stops you.',
    'Three tracks. The first bike to the line wins.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<BikeRaceLogic>((g, b, now) {
    if (!g.racing || g.winner != null) return;
    final ahead = g.barriers.where(
        (o) => o.$1 > g.progress[b.seat] && o.$1 < g.progress[b.seat] + 0.08);
    if (ahead.any((o) => o.$2 == g.lane[b.seat])) {
      final free = [0, 1, 2].where((lane) => ahead.every((o) => o.$2 != lane));
      if (free.isEmpty) return;
      final want = free.first;
      g.steer(b.seat, want < g.lane[b.seat] ? -1 : 1);
    }
  }),
  online: RelaySpec<BikeRaceLogic>(
    create: (n) => BikeRaceLogic(players: n),
    save: (g) => {
      'track': g.track,
      'progress': g.progress,
      'lane': g.lane,
      'stun': g.stunUntil,
      'winner': g.winner,
      'now': g.now,
      'barriers': [
        for (final b in g.barriers) [b.$1, b.$2]
      ],
    },
    load: (g, s, me) {
      g.track = asInt(s['track']);
      g.progress.setAll(0, doubles(s['progress']));
      g.lane.setAll(0, ints(s['lane']));
      g.stunUntil.setAll(0, ints(s['stun']));
      g.winner = nInt(s['winner']);
      g.now = asInt(s['now']);
      g.barriers
        ..clear()
        ..addAll([
          for (final raw in s['barriers'] as List)
            (((raw as List)[0] as num).toDouble(), (raw[1] as num).toInt()),
        ]);
    },
    apply: (g, from, name, a) {
      if (name == 'steer' && a.length >= 2 && asInt(a[0]) == from)
        g.steer(from, asInt(a[1]));
    },
    view: (context, g, players, me) =>
        _BikeView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<BikeRaceLogic>(
    create: () => BikeRaceLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _BikeView(g: g, players: players, me: -1),
  ),
);

class _BikeView extends StatelessWidget {
  final BikeRaceLogic g;
  final List<GpPlayer> players;
  final int me;
  const _BikeView({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) {
    final go = g.now < BikeRaceLogic.countdown;
    return Column(children: [
      GameHud(
        players: players,
        scores: [
          for (var i = 0; i < players.length; i++) (g.progress[i] * 100).floor()
        ],
        trailing: Text(
            go
                ? '${((BikeRaceLogic.countdown - g.now) / 1000).ceil()}'
                : (g.winner == null
                    ? 'Ride'
                    : '${players[g.winner!].name} wins'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      if (g.now == 0)
        Row(children: [
          for (var t = 1; t <= 3; t++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: KitButton('Track $t',
                    style: g.track == t
                        ? KitButtonStyle.soft
                        : KitButtonStyle.ghost,
                    onPressed: () => g.setTrack(t)),
              ),
            ),
        ]),
      const SizedBox(height: 8),
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(16)),
          child: CustomPaint(
              painter: _BikePainter(g, players.map((p) => p.color).toList()),
              child: const SizedBox.expand()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(children: [
          for (final seat
              in (me < 0 ? [for (var i = 0; i < players.length; i++) i] : [me]))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    child: KitButton('Left',
                        onPressed: g.racing ? () => g.steer(seat, -1) : null)),
                const SizedBox(width: 8),
                Text(players[seat].name,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                Expanded(
                    child: KitButton('Right',
                        onPressed: g.racing ? () => g.steer(seat, 1) : null)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _BikePainter extends CustomPainter {
  final BikeRaceLogic g;
  final List<Color> colors;
  _BikePainter(this.g, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final laneW = size.width / 3;
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
          Offset(laneW * i, 0), Offset(laneW * i, size.height), paint);
    }
    canvas.drawRect(
        Rect.fromLTWH(0, 8, size.width, 8), Paint()..color = Colors.white);
    for (final b in g.barriers) {
      final y = (1 - b.$1) * size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(b.$2 * laneW + 10, y - 14, laneW - 20, 22),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFFFC107),
      );
    }
    for (var i = 0; i < g.players; i++) {
      final x = (g.lane[i] + 0.5) * laneW;
      final y = (1 - g.progress[i]) * (size.height - 30) + 10;
      canvas.drawCircle(
          Offset(x, y), 14, Paint()..color = colors[i % colors.length]);
    }
  }

  @override
  bool shouldRepaint(_BikePainter old) => true;
}
