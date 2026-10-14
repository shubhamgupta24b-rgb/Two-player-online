import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';

/// Tug of War. Each pull moves the rope a fixed step, and pulls faster than the
/// limit are ignored so tapping wildly does not help.
class TugLogic extends LocalGameLogic {
  double rope = 0;
  final List<int> nextPull = [0, 0];
  final List<int> pulls = [0, 0];
  int? winner;
  int now = 0;
  static const limit = 40000;

  @override
  bool get finished => winner != null || now >= limit;
  @override
  List<int> get scores => [for (var i = 0; i < 2; i++) winner == i ? 1 : 0];

  void pull(int player) {
    if (forward('pull', [player])) return;
    if (finished || player < 0 || player > 1 || now < nextPull[player]) return;
    nextPull[player] = now + 170;
    pulls[player]++;
    rope += player == 0 ? -0.07 : 0.07;
    if (rope <= -1) {
      rope = -1;
      winner = 0;
    } else if (rope >= 1) {
      rope = 1;
      winner = 1;
    }
    notifyListeners();
  }

  @override
  void update(int ms) {
    now = ms;
    if (now >= limit && winner == null) {
      if (rope < 0) winner = 0;
      if (rope > 0) winner = 1;
    }
    notifyListeners();
  }
}

final tugOfWarInfo = LocalGameInfo(
  id: 'tug_of_war',
  title: 'Tug of War',
  emoji: '🪢',
  color: const Color(0xFF6D4C41),
  tagline: 'Pull the rope to your side.',
  rules: const [
    'Tap Pull. Each legal pull moves the rope one step toward you.',
    'Pulls closer together than a short gap are ignored, so mashing does not win.',
    'Drag the marker to your end, or be ahead when time runs out.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<TugLogic>((g, b, now) {
    if (g.finished || now < g.nextPull[b.seat]) return;
    g.pull(b.seat);
  }),
  online: RelaySpec<TugLogic>(
    create: (n) => TugLogic(),
    save: (g) => {
      'rope': g.rope,
      'next': g.nextPull,
      'pulls': g.pulls,
      'winner': g.winner,
      'now': g.now
    },
    load: (g, s, me) {
      g.rope = asDouble(s['rope']);
      g.nextPull.setAll(0, ints(s['next']));
      g.pulls.setAll(0, ints(s['pulls']));
      g.winner = nInt(s['winner']);
      g.now = asInt(s['now']);
    },
    apply: (g, from, name, a) {
      if (name == 'pull' && a.isNotEmpty && asInt(a[0]) == from) g.pull(from);
    },
    view: (context, g, players, me) => _TugView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<TugLogic>(
    create: TugLogic.new,
    onFinished: onFinished,
    builder: (context, g) => _TugView(g: g, players: players, me: -1),
  ),
);

class _TugView extends StatelessWidget {
  final TugLogic g;
  final List<GpPlayer> players;
  final int me;
  const _TugView({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) {
    final left = g.finished ? 0 : ((TugLogic.limit - g.now) / 1000).ceil();
    return Column(children: [
      GameHud(
          players: players,
          scores: g.pulls,
          trailing: Text('${left}s',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: const Color(0xFF3E2723),
                borderRadius: BorderRadius.circular(18)),
            child: CustomPaint(
                painter: _TugPainter(g, players.map((p) => p.color).toList()),
                child: const SizedBox.expand()),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(children: [
          for (final seat in (me < 0 ? const [0, 1] : [me]))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: KitButton('${players[seat].name} pull',
                    onPressed: g.finished ? null : () => g.pull(seat)),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _TugPainter extends CustomPainter {
  final TugLogic g;
  final List<Color> colors;
  _TugPainter(this.g, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
        Offset(24, y),
        Offset(size.width - 24, y),
        Paint()
          ..color = const Color(0xFFFFE0B2)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        Offset(size.width / 2, y - 24),
        Offset(size.width / 2, y + 24),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 3);
    final x = size.width / 2 + g.rope * (size.width / 2 - 36);
    canvas.drawCircle(Offset(x, y), 18, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(28, y), 22,
        Paint()..color = colors.isEmpty ? Colors.red : colors[0]);
    canvas.drawCircle(Offset(size.width - 28, y), 22,
        Paint()..color = colors.length < 2 ? Colors.blue : colors[1]);
  }

  @override
  bool shouldRepaint(_TugPainter old) => true;
}
