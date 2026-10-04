import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/game_audio.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';

/// A target sliding along one of the gallery's lanes. Everything about it follows from
/// (lane, index, turn), so every phone in an online game sees the same gallery.
class GalleryTarget {
  final int lane, index;
  final int kind; // 0 duck 10, 1 rabbit 20, 2 golden star 50, 3 bomb -30
  final double x, y;
  const GalleryTarget(this.lane, this.index, this.kind, this.x, this.y);
  (int, int) get id => (lane, index);
}

/// Shooting Gallery: tap targets as they slide by. 🦆 10, 🐰 20, ⭐ 50, but 💣 costs 30.
/// 6 shots then a reload. Each player gets [turnMs] at the gallery, taking turns.
class GalleryLogic extends LocalGameLogic {
  static const turnMs = 20000, clip = 6, reloadMs = 900, rounds = 2;
  static const laneY = [0.22, 0.47, 0.72];
  static const laneSpeed = [0.16, -0.24, 0.32]; // screen widths per second; negative = right to left
  static const laneGap = [1500, 1150, 1000]; // ms between targets entering
  static const hitR = 0.065;
  final int players;
  final List<int> score;
  int turn = 0, round = 1, turnStart = 0, now = 0;
  int shots = clip, reloadAt = 0;
  final Set<(int, int)> hits = {};
  final List<(double, double, int, int)> marks = []; // x, y, when, points (0 = a miss)
  bool waiting = true, done = false;

  GalleryLogic({this.players = 2}) : score = List.filled(players, 0);

  @override
  bool get finished => done;
  @override
  List<int> get scores => score;

  int get timeLeft => waiting ? turnMs : max(0, turnMs - (now - turnStart));
  bool get reloading => now < reloadAt;

  static int _kind(int lane, int index, int turnNo) {
    final h = ((lane * 7349 + index * 2654435761 + turnNo * 40503) & 0x7fffffff) % 100;
    if (h < 12) return 3;
    if (h < 22) return 2;
    if (h < 50) return 1;
    return 0;
  }

  /// The targets on show right now.
  List<GalleryTarget> get targets {
    if (waiting) return const [];
    final t = now - turnStart, turnNo = round * 10 + turn;
    final out = <GalleryTarget>[];
    for (var l = 0; l < 3; l++) {
      final gap = laneGap[l], v = laneSpeed[l].abs();
      final first = max(0, ((t - 1.3 / v * 1000) / gap).floor());
      for (var k = first; k * gap <= t; k++) {
        final age = (t - k * gap) / 1000;
        var x = -0.1 + age * v;
        if (x > 1.1) continue;
        if (laneSpeed[l] < 0) x = 1 - x;
        if (hits.contains((l, k))) continue;
        out.add(GalleryTarget(l, k, _kind(l, k, turnNo), x, laneY[l] + sin(age * 5 + k) * 0.015));
      }
    }
    return out;
  }

  /// The player at the gallery starts their time.
  void begin(int player) {
    if (forward('begin', [player])) return;
    if (!waiting || done || player != turn) return;
    waiting = false;
    turnStart = now;
    shots = clip;
    hits.clear();
    notifyListeners();
  }

  /// Fires at ([x], [y]) on a 1-wide, 1-tall gallery.
  void shoot(int player, double x, double y) {
    if (forward('shoot', [player, x, y])) return;
    if (waiting || done || player != turn || reloading || timeLeft <= 0) return;
    shots--;
    GameAudio.sfx('shoot');
    if (shots == 0) {
      shots = clip;
      reloadAt = now + reloadMs;
    }
    GalleryTarget? hit;
    for (final tg in targets) {
      if ((tg.x - x).abs() < hitR && (tg.y - y).abs() < hitR * 1.2) hit = tg;
    }
    if (hit != null) {
      hits.add(hit.id);
      final pts = const [10, 20, 50, -30][hit.kind];
      score[turn] = max(0, score[turn] + pts);
      marks.add((hit.x, hit.y, now, pts));
      HapticFeedback.mediumImpact().ignore();
      GameAudio.sfx(hit.kind == 3 ? 'boom' : (hit.kind == 2 ? 'coin' : 'pop'));
    } else {
      marks.add((x, y, now, 0));
      HapticFeedback.lightImpact().ignore();
    }
    notifyListeners();
  }

  @override
  void update(int ms) {
    now = ms;
    marks.removeWhere((m) => ms - m.$3 > 800);
    if (!waiting && !done && timeLeft <= 0) {
      waiting = true;
      turn = (turn + 1) % players;
      if (turn == 0) round++;
      if (round > rounds) done = true;
      hits.clear();
      reloadAt = 0;
    }
    notifyListeners();
  }
}

final galleryInfo = LocalGameInfo(
  id: 'shooting_gallery',
  title: 'Shooting Gallery',
  emoji: '🔫',
  color: const Color(0xFFC62828),
  tagline: 'Pop the ducks, dodge the bombs!',
  rules: const [
    'Tap a target to shoot it: 🦆 10, 🐰 20, ⭐ 50. Shooting a 💣 costs 30!',
    '6 shots, then a short reload. Each player gets 20 seconds at the gallery.',
    'Two turns each, one after another. Most points wins. 1 to 4 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 4,
  bot: botFor<GalleryLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    if (g.waiting) {
      if (b.thinkFirst(('begin', g.round, g.turn), now, 900, 1500)) g.begin(b.seat);
      return;
    }
    if (g.reloading || !b.due(now)) return;
    b.wait(now, 380, 830);
    // Go for the best target that isn't a bomb, with a slightly shaky aim.
    final good = g.targets.where((t) => t.kind != 3 && t.x > 0.05 && t.x < 0.95).toList()..sort((a, c) => c.kind - a.kind);
    if (good.isEmpty) return;
    final t = good.first;
    final lead = GalleryLogic.laneSpeed[t.lane] * 0.05;
    g.shoot(b.seat, t.x + lead + (b.rng.nextDouble() - 0.5) * 0.1, t.y + (b.rng.nextDouble() - 0.5) * 0.08);
  }),
  online: RelaySpec<GalleryLogic>(
    create: (n) => GalleryLogic(players: n),
    save: (g) => {
      'score': g.score,
      'turn': g.turn,
      'round': g.round,
      'start': g.turnStart,
      'now': g.now,
      'shots': g.shots,
      'reload': g.reloadAt,
      'hits': [for (final (l, k) in g.hits) ...[l, k]],
      'marks': [for (final m in g.marks) ...[m.$1, m.$2, m.$3, m.$4]],
      'waiting': g.waiting,
      'done': g.done,
    },
    load: (g, s, me) {
      g.score.setAll(0, ints(s['score']));
      g.turn = asInt(s['turn']);
      g.round = asInt(s['round']);
      g.turnStart = asInt(s['start']);
      g.now = asInt(s['now']);
      g.shots = asInt(s['shots']);
      g.reloadAt = asInt(s['reload']);
      final h = ints(s['hits']);
      g.hits
        ..clear()
        ..addAll([for (var i = 0; i + 1 < h.length; i += 2) (h[i], h[i + 1])]);
      final m = doubles(s['marks']);
      g.marks
        ..clear()
        ..addAll([for (var i = 0; i + 3 < m.length; i += 4) (m[i], m[i + 1], m[i + 2].round(), m[i + 3].round())]);
      g.waiting = s['waiting'] == true;
      g.done = s['done'] == true;
    },
    apply: (g, from, name, a) {
      if (a.isEmpty || asInt(a[0]) != from) return;
      if (name == 'begin') g.begin(from);
      if (name == 'shoot') g.shoot(from, asDouble(a[1]), asDouble(a[2]));
    },
    view: (context, g, players, me) => _GalleryView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<GalleryLogic>(
    create: () => GalleryLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _GalleryView(g: g, players: players, bots: {for (var i = 0; i < players.length; i++) if (BotScope.isBot(context, i)) i}),
  ),
);

class _GalleryView extends StatelessWidget {
  final GalleryLogic g;
  final List<GpPlayer> players;
  final int? me;
  final Set<int> bots;
  const _GalleryView({required this.g, required this.players, this.me, this.bots = const {}});

  bool get _mine => !bots.contains(g.turn) && (me == null || me == g.turn) && !g.finished;

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(children: [
        GameHud(
          players: players,
          scores: g.score,
          turn: g.finished ? null : g.turn,
          trailing: TimerRing(fraction: g.timeLeft / GalleryLogic.turnMs, label: '${(g.timeLeft / 1000).ceil()}', urgent: !g.waiting && g.timeLeft < 5000, size: 44),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth, h = c.maxHeight;
            return Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _mine && !g.waiting ? (d) => g.shoot(g.turn, d.localPosition.dx / w, d.localPosition.dy / h) : null,
                  child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CustomPaint(size: Size(w, h), painter: _GalleryPainter(g))),
                ),
              ),
              if (g.waiting && !g.finished)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: current.color, width: 3)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('ROUND ${g.round}/${GalleryLogic.rounds}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text('${current.whose} TURN', style: TextStyle(color: current.color, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      if (_mine)
                        AppButton('🔫 START', color: current.color, onPressed: () => g.begin(g.turn))
                      else
                        Text('${current.name} is getting ready…', style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: Semantics(
            label: g.reloading ? 'Reloading' : '${g.shots} shots left',
            excludeSemantics: true,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (g.reloading)
                Text('RELOADING…', style: context.tk.styles.title.copyWith(color: Brand.gold, fontSize: 16, letterSpacing: 2))
              else
                for (var i = 0; i < GalleryLogic.clip; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 11,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: i < g.shots ? const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFD99A00)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
                        color: i < g.shots ? null : context.tk.glass,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                      ),
                    ),
                  ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _GalleryPainter extends CustomPainter {
  final GalleryLogic g;
  _GalleryPainter(this.g);

  static final _cache = <String, TextPainter>{};
  static TextPainter _t(String s, double size, [Color color = Colors.white]) => _cache.putIfAbsent('$s$size$color',
      () => TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout());

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Dark red booth with gold trim and three wooden rails.
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A0E0E), Color(0xFF1F0606)]).createShader(Offset.zero & size));
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(Offset((i + 0.5) * w / 10, h * 0.04), 5, Paint()..color = (g.now ~/ 300 + i).isEven ? const Color(0xFFFFEB3B) : const Color(0xFFFF9800));
    }
    final targetSize = min(w * 0.11, h * 0.12);
    for (var l = 0; l < 3; l++) {
      final y = GalleryLogic.laneY[l] * h + targetSize * 0.55;
      canvas.drawRect(Rect.fromLTWH(0, y, w, 8), Paint()..color = const Color(0xFF8D6E63));
      canvas.drawRect(Rect.fromLTWH(0, y + 8, w, 3), Paint()..color = const Color(0xFF4E342E));
      // Water waves under the ducks' rail.
      final wave = Path()..moveTo(0, y + 14);
      for (var x = 0.0; x <= w; x += 12) {
        wave.lineTo(x, y + 14 + sin((x + g.now * 0.08 * (l.isEven ? 1 : -1)) / 14) * 3);
      }
      canvas.drawPath(wave, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x5542A5F5));
    }
    for (final t in g.targets) {
      final p = Offset(t.x * w, t.y * h);
      canvas.drawLine(p + Offset(0, targetSize * 0.3), p + Offset(0, targetSize * 0.6), Paint()
        ..color = const Color(0xFFBCAAA4)
        ..strokeWidth = 3);
      final glyph = _t(const ['🦆', '🐰', '⭐', '💣'][t.kind], targetSize * 0.8);
      canvas.save();
      if (GalleryLogic.laneSpeed[t.lane] < 0 && t.kind < 2) {
        canvas.translate(p.dx, 0);
        canvas.scale(-1, 1);
        canvas.translate(-p.dx, 0);
      }
      glyph.paint(canvas, p - Offset(glyph.width / 2, glyph.height / 2));
      canvas.restore();
    }
    // Hit and miss marks.
    for (final (x, y, at, pts) in g.marks) {
      final u = ((g.now - at) / 800).clamp(0.0, 1.0);
      final p = Offset(x * w, y * h);
      if (pts == 0) {
        canvas.drawCircle(p, 5, Paint()..color = Colors.black.withValues(alpha: 0.7 * (1 - u)));
        continue;
      }
      canvas.drawCircle(p, targetSize * (0.3 + u * 0.6), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = (pts > 0 ? const Color(0xFFFFEB3B) : const Color(0xFFFF5252)).withValues(alpha: 1 - u));
      final label = _t(pts > 0 ? '+$pts' : '$pts', 18, pts > 0 ? const Color(0xFFFFEB3B) : const Color(0xFFFF5252));
      label.paint(canvas, p - Offset(label.width / 2, targetSize * 0.6 + u * 30));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
