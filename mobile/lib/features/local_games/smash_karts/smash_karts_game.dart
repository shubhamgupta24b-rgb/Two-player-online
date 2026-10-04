import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';
import 'smash_karts_logic.dart';

export 'smash_karts_logic.dart';

final LocalGameInfo smashKartsInfo = LocalGameInfo(
  id: 'smash_karts',
  title: 'Smash Karts',
  emoji: '🏎️',
  color: const Color(0xFFFF5722),
  tagline: 'Grab a box, blast your friends!',
  rules: const [
    'Drag the joystick to drive. Drive over a 🎁 box to get a power-up.',
    '🚀 Rocket flies straight ahead · 💣 Mine drops behind you · ⚡ Boost for speed. Tap FIRE to use it.',
    'Every hit is a point. A hit kart spins out, then has a shield for a moment.',
    'Most hits in 2 minutes wins! On one phone each player drives from their own edge. 2 to 4 players.',
  ],
  scoreUnit: 'hits',
  splitScreen: true,
  maxPlayers: 4,
  bot: botFor<SmashKartsLogic>((g, b, now) {
    if (!b.due(now)) return;
    smashKartsBot(g, b.seat, b.rng, nowMs: now, memory: b.memory);
    b.wait(now, 90, 160); // a human-ish reaction time
  }),
  online: RelaySpec<SmashKartsLogic>(
    create: (n) => SmashKartsLogic(players: n),
    continuous: const {'steer'},
    save: (g) => {
      't': g.elapsedMs,
      'k': [
        for (final k in g.karts) ...[(k.x * 1000).round(), (k.y * 1000).round(), (k.angle * 100).round(), k.weapon.index, k.stunnedUntil, k.shieldUntil, k.boostUntil],
      ],
      'h': g.hits,
      'r': [for (final r in g.rockets) ...[(r.x * 1000).round(), (r.y * 1000).round(), (r.angle * 100).round(), r.owner]],
      'm': [for (final m in g.mines) ...[(m.x * 1000).round(), (m.y * 1000).round(), m.owner, m.bornMs]],
      'b': [for (final b in g.boxes) b.readyAt],
      'x': [for (final b in g.blasts) ...[(b.$1 * 1000).round(), (b.$2 * 1000).round(), b.$3]],
      'e': g.lastEvent,
    },
    load: (g, s, me) {
      g.elapsedMs = asInt(s['t']);
      final k = ints(s['k']);
      for (var i = 0; i < g.karts.length; i++) {
        final o = i * 7, kart = g.karts[i];
        kart
          ..x = k[o] / 1000
          ..y = k[o + 1] / 1000
          ..angle = k[o + 2] / 100
          ..weapon = Weapon.values[k[o + 3]]
          ..stunnedUntil = k[o + 4]
          ..shieldUntil = k[o + 5]
          ..boostUntil = k[o + 6];
      }
      g.hits.setAll(0, ints(s['h']));
      final r = ints(s['r']);
      g.rockets
        ..clear()
        ..addAll([for (var i = 0; i + 3 < r.length; i += 4) Rocket(r[i] / 1000, r[i + 1] / 1000, r[i + 2] / 100, r[i + 3], g.elapsedMs)]);
      final m = ints(s['m']);
      g.mines
        ..clear()
        ..addAll([for (var i = 0; i + 3 < m.length; i += 4) Mine(m[i] / 1000, m[i + 1] / 1000, m[i + 2], m[i + 3])]);
      final b = ints(s['b']);
      for (var i = 0; i < g.boxes.length && i < b.length; i++) {
        g.boxes[i].readyAt = b[i];
      }
      final x = ints(s['x']);
      g.blasts
        ..clear()
        ..addAll([for (var i = 0; i + 2 < x.length; i += 3) (x[i] / 1000, x[i + 1] / 1000, x[i + 2])]);
      final e = s['e'] as List;
      for (var i = 0; i < g.lastEvent.length && i < e.length; i++) {
        g.lastEvent[i] = e[i] as String?;
      }
    },
    apply: (g, from, name, a) {
      if (a.isEmpty || asInt(a[0]) != from) return;
      if (name == 'steer' && a.length >= 3) g.steer(from, asDouble(a[1]), asDouble(a[2]));
      if (name == 'fire') g.fire(from);
    },
    view: (context, g, players, me) => Column(children: [
      Expanded(child: _ArenaPanel(g: g, players: players)),
      SizedBox(height: 150, child: _Controls(g: g, player: players[me], index: me)),
    ]),
  ),
  play: (players, onFinished) => TickingPlay<SmashKartsLogic>(
    create: () => SmashKartsLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) {
      // People drive from the phone's edges: Player 1 and 3 at the bottom, 2 and 4 at the top.
      final people = [for (var i = 0; i < players.length; i++) if (!BotScope.isBot(context, i)) i];
      final bottom = people.where((i) => i.isEven).toList(), top = people.where((i) => i.isOdd).toList();
      Widget bar(List<int> seats) => Row(children: [
            for (final i in seats) Expanded(child: _Controls(g: g, player: players[i], index: i)),
          ]);
      return Column(children: [
        if (top.isNotEmpty) SizedBox(height: 130, child: RotatedBox(quarterTurns: 2, child: bar(top))),
        Expanded(child: _ArenaPanel(g: g, players: players)),
        if (bottom.isNotEmpty) SizedBox(height: 130, child: bar(bottom)),
      ]);
    },
  ),
);

/// The arena with everyone's hits and the clock above it.
class _ArenaPanel extends StatelessWidget {
  final SmashKartsLogic g;
  final List<GpPlayer> players;
  const _ArenaPanel({required this.g, required this.players});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Column(children: [
          Row(children: [
            const PauseButton(),
            const SizedBox(width: 4),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (var i = 0; i < players.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: players[i].color, borderRadius: BorderRadius.circular(10)),
                    child: Text('${players[i].name} ${g.hits[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
              ]),
            ),
            Text('⏱ ${g.secondsLeft ~/ 60}:${(g.secondsLeft % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: g.secondsLeft <= 10 ? const Color(0xFFFF5E5B) : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final w = min(c.maxWidth, c.maxHeight / SmashKartsLogic.height);
              return Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CustomPaint(size: Size(w, w * SmashKartsLogic.height), painter: _ArenaPainter(g, [for (final p in players) p.color])),
                ),
              );
            }),
          ),
        ]),
      );
}

/// One driver's joystick (left) and fire button (right).
class _Controls extends StatefulWidget {
  final SmashKartsLogic g;
  final GpPlayer player;
  final int index;
  const _Controls({required this.g, required this.player, required this.index});
  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  Offset knob = Offset.zero; // -1..1 in both directions

  void _stick(Offset local, double radius) {
    final v = (local - Offset(radius, radius)) / radius;
    final d = v.distance;
    setState(() => knob = d > 1 ? v / d : v);
    // The stick is drawn the way this player sees it; RotatedBox already turns the touch for us,
    // but a rotated player's "up" is the arena's "down": add the half turn back.
    final turned = context.findAncestorWidgetOfExactType<RotatedBox>()?.quarterTurns == 2;
    final angle = atan2(knob.dy, knob.dx) + (turned ? pi : 0);
    widget.g.steer(widget.index, angle, knob.distance);
  }

  void _release() {
    setState(() => knob = Offset.zero);
    widget.g.steer(widget.index, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, i = widget.index, c = widget.player.color;
    final weapon = g.karts[i].weapon;
    final event = g.lastEvent[i];
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(18), border: Border.all(color: c, width: 2)),
      child: LayoutBuilder(builder: (context, box) {
        final r = min(box.maxHeight, box.maxWidth * 0.45) / 2;
        return Row(children: [
          GestureDetector(
            onPanStart: (d) => _stick(d.localPosition, r),
            onPanUpdate: (d) => _stick(d.localPosition, r),
            onPanEnd: (_) => _release(),
            onPanCancel: _release,
            child: SizedBox(
              width: r * 2,
              height: r * 2,
              child: CustomPaint(painter: _StickPainter(knob, c)),
            ),
          ),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(widget.player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              if (event != null) Text(event, style: TextStyle(color: event.startsWith('+') ? const Color(0xFFFFE066) : const Color(0xFFFF8A80), fontWeight: FontWeight.w900, fontSize: 11)),
            ]),
          ),
          Semantics(
            button: true,
            label: 'Fire',
            child: GestureDetector(
              onTapDown: (_) {
                if (weapon == Weapon.none) return;
                HapticFeedback.mediumImpact().ignore();
                g.fire(i);
              },
              child: Container(
                width: r * 1.6,
                height: r * 1.6,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: weapon == Weapon.none ? Colors.white10 : c,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [if (weapon != Weapon.none) BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 14)],
                ),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(weapon == Weapon.none ? 'FIRE' : weaponEmoji[weapon]!,
                        style: TextStyle(color: Colors.white.withValues(alpha: weapon == Weapon.none ? 0.4 : 1), fontWeight: FontWeight.w900, fontSize: 22)),
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _StickPainter extends CustomPainter {
  final Offset knob;
  final Color color;
  _StickPainter(this.knob, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2, c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white38);
    canvas.drawCircle(c + knob * r * 0.6, r * 0.38, Paint()..color = color);
    canvas.drawCircle(c + knob * r * 0.6, r * 0.38, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white);
  }

  @override
  bool shouldRepaint(_StickPainter old) => old.knob != knob;
}

class _ArenaPainter extends CustomPainter {
  final SmashKartsLogic g;
  final List<Color> colors;
  _ArenaPainter(this.g, this.colors);

  static final _emoji = <String, TextPainter>{};
  static void _text(Canvas canvas, String s, Offset at, double size) {
    final tp = _emoji.putIfAbsent('$s@${size.round()}', () => TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout());
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset o(double x, double y) => Offset(x * s, y * s);
    // Asphalt with lane markings.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF3B3F46));
    final line = Paint()
      ..color = Colors.white12
      ..strokeWidth = 2;
    for (var y = 0.0; y < SmashKartsLogic.height; y += 0.1) {
      canvas.drawLine(o(0.5, y), o(0.5, y + 0.05), line);
    }
    canvas.drawCircle(o(0.5, 0.75), 0.22 * s, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white10);
    // Fence.
    canvas.drawRect(Offset.zero & size, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFFFFB300));
    // Crates.
    for (final (l, t, r, b) in SmashKartsLogic.obstacles) {
      final rect = Rect.fromLTRB(l * s, t * s, r * s, b * s);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = const Color(0xFF8D6E63));
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(3)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF5D4037));
    }
    // Mystery boxes (bobbing).
    for (final b in g.boxes) {
      if (!g.boxReady(b)) continue;
      final bob = sin(g.elapsedMs / 250 + b.x * 10) * 0.006;
      _text(canvas, '🎁', o(b.x, b.y + bob), 0.06 * s);
    }
    // Mines.
    for (final m in g.mines) {
      final armed = g.elapsedMs - m.bornMs >= SmashKartsLogic.mineArmMs;
      canvas.drawCircle(o(m.x, m.y), 0.018 * s, Paint()..color = armed && (g.elapsedMs ~/ 300).isEven ? const Color(0xFFFF1744) : const Color(0xFF212121));
      canvas.drawCircle(o(m.x, m.y), 0.018 * s, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors[m.owner % colors.length]);
    }
    // Rockets with a smoke trail.
    for (final r in g.rockets) {
      final back = o(r.x - cos(r.angle) * 0.05, r.y - sin(r.angle) * 0.05);
      canvas.drawLine(back, o(r.x, r.y), Paint()
        ..strokeWidth = 0.012 * s
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), const Color(0xFFFFA726)]).createShader(Rect.fromPoints(back, o(r.x, r.y))));
      canvas.drawCircle(o(r.x, r.y), 0.012 * s, Paint()..color = const Color(0xFFFF5722));
    }
    // Karts.
    for (var i = 0; i < g.karts.length; i++) {
      final k = g.karts[i];
      final col = colors[i % colors.length];
      canvas.save();
      canvas.translate(k.x * s, k.y * s);
      if (g.shielded(i) && !g.stunned(i)) {
        canvas.drawCircle(Offset.zero, SmashKartsLogic.kartR * 1.7 * s, Paint()..color = const Color(0x444FC3F7));
      }
      if (g.boosted(i)) {
        canvas.drawCircle(Offset(-cos(k.angle), -sin(k.angle)) * SmashKartsLogic.kartR * 1.6 * s, SmashKartsLogic.kartR * 0.6 * s, Paint()..color = const Color(0xAAFFEB3B));
      }
      canvas.rotate(k.angle);
      final l = SmashKartsLogic.kartR * 2.2 * s, w = SmashKartsLogic.kartR * 1.5 * s;
      final wheel = Paint()..color = Colors.black;
      for (final dx in [-l * 0.32, l * 0.32]) {
        for (final dy in [-w * 0.55, w * 0.55]) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(dx, dy), width: l * 0.28, height: w * 0.25), const Radius.circular(2)), wheel);
        }
      }
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: l, height: w), Radius.circular(w * 0.3)), Paint()..color = col);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(l * 0.36, 0), width: l * 0.2, height: w * 0.8), Radius.circular(w * 0.2)),
          Paint()..color = Color.lerp(col, Colors.black, 0.3)!);
      canvas.drawCircle(Offset(-l * 0.08, 0), w * 0.3, Paint()..color = Colors.white);
      canvas.restore();
      if (k.weapon != Weapon.none) _text(canvas, weaponEmoji[k.weapon]!, o(k.x, k.y - SmashKartsLogic.kartR * 2), 0.035 * s);
      if (g.stunned(i)) _text(canvas, '💫', o(k.x, k.y - SmashKartsLogic.kartR * 2), 0.04 * s);
    }
    // Explosions.
    for (final (x, y, ms) in g.blasts) {
      final t = ((g.elapsedMs - ms) / 700).clamp(0.0, 1.0);
      canvas.drawCircle(o(x, y), (0.03 + t * 0.07) * s, Paint()..color = Color.lerp(const Color(0xFFFFEB3B), const Color(0xFFFF5722), t)!.withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
