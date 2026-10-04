import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';
import '../widgets/dice.dart';
import 'ludo_logic.dart';

export 'ludo_logic.dart';

/// Ludo: everyone for themselves.
final ludoInfo = _ludo(teams: false);

/// Ludo 2 vs 2 (in rooms as its own game; on one phone it's the TEAMS switch on Ludo).
final ludoTeamsInfo = _ludo(teams: true);

LocalGameInfo _ludo({required bool teams}) => LocalGameInfo(
  id: teams ? 'ludo_teams' : 'ludo',
  title: teams ? 'Ludo 2 vs 2' : 'Ludo',
  emoji: teams ? '🤝' : '🎲',
  color: const Color(0xFF1E7BE0),
  tagline: teams ? 'Team up with your partner across the board!' : 'Race all four tokens home!',
  rules: [
    'Roll a 6 to bring a token out of your base. Move round the board and up your coloured path to the centre.',
    'Land on a rival token to send it back to base (not on ★ safe squares).',
    'A 6, a capture or getting a token home gives you another roll. Three 6s in a row lose your turn.',
    if (!teams) 'First to bring all four tokens home wins. 2 to 4 players. With 4 players you can play in teams.',
    if (teams) 'Teams: Player 1 + 3 against Player 2 + 4. Partners never capture each other.',
    if (teams) 'All your tokens home? Your turns now move your partner\'s. Both partners home and the team wins!',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: teams ? 4 : 2,
  maxPlayers: 4,
  teamVariant: teams ? null : ludoTeamsInfo,
  bot: botFor<LudoLogic>((g, b, now) {
    if (g.finished || g.turn != b.seat) return;
    // Slow enough to watch: a roll, a pause, then the token walks (about 0.2 s a square).
    if (!b.thinkFirst((g.rolls, g.phase), now, 1100, 1800)) return;
    if (g.phase == LudoPhase.roll) {
      g.roll();
      return;
    }
    final moves = g.movable;
    if (moves.isEmpty) return;
    final r = g.lastRoll!;
    final me = g.mover; // the bot's tokens, or its partner's once its own are home
    int value(int t) {
      final p = g.tokens[me][t];
      final np = p == -1 ? 0 : p + r;
      final cell = g.trackIndex(me, np);
      var v = np; // further along is better
      if (cell != null && !LudoLogic.safeCells.contains(cell)) {
        for (var o = 0; o < g.players; o++) {
          if (o != me && !g.sameTeam(o, me) && g.tokens[o].any((x) => g.trackIndex(o, x) == cell)) v += 200; // capture!
        }
      }
      if (np == LudoLogic.home) v += 150;
      if (p == -1) v += 100;
      if (cell != null && LudoLogic.safeCells.contains(cell)) v += 40;
      return v + b.rng.nextInt(10);
    }

    g.move(moves.reduce((a, c) => value(a) >= value(c) ? a : c));
  }),
  online: RelaySpec<LudoLogic>(
    create: (n) => LudoLogic(players: n, teams: teams),
    save: (g) => {
      'tokens': [for (final t in g.tokens) ...t],
      'turn': g.turn,
      'phase': g.phase.index,
      'roll': g.lastRoll,
      'rolls': g.rolls,
      'sixes': g.sixesInARow,
      'winner': g.winner,
      'msg': g.message,
    },
    load: (g, s, me) {
      final t = ints(s['tokens']);
      for (var p = 0; p < g.players; p++) {
        g.tokens[p].setAll(0, t.sublist(p * LudoLogic.tokensEach, (p + 1) * LudoLogic.tokensEach));
      }
      g.turn = asInt(s['turn']);
      g.phase = LudoPhase.values[asInt(s['phase'])];
      g.lastRoll = nInt(s['roll']);
      g.rolls = asInt(s['rolls']);
      g.sixesInARow = asInt(s['sixes']);
      g.winner = nInt(s['winner']);
      g.message = s['msg'] as String;
    },
    apply: (g, from, name, a) {
      if (from != g.turn) return;
      if (name == 'roll') g.roll();
      if (name == 'move') g.move(asInt(a[0]));
    },
    view: (context, g, players, me) => _LudoTable(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<LudoLogic>(
    create: () => LudoLogic(players: players.length, teams: teams),
    onFinished: onFinished,
    builder: (context, g) => _LudoTable(players: players, g: g),
  ),
);

class _LudoTable extends StatelessWidget {
  final List<GpPlayer> players;
  final LudoLogic g;
  const _LudoTable({required this.players, required this.g});

  @override
  Widget build(BuildContext context) {
    final current = players[g.turn];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < players.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: i == g.turn ? players[i].color : Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: players[i].color, width: 2)),
                  child: Text('${g.teams ? (i.isEven ? '🅰 ' : '🅱 ') : ''}${players[i].name} · 🏠${g.tokens[i].where((t) => t == LudoLogic.home).length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _Board(players: players, g: g)))),
        const SizedBox(height: 8),
        Text(g.message, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Text(
                g.phase == LudoPhase.move
                    ? '${current.name.toUpperCase()}: MOVE ${g.lastRoll}${g.mover != g.turn ? ' (FOR ${players[g.mover].name.toUpperCase()})' : ''}'
                    : '${current.whose} ROLL',
                overflow: TextOverflow.ellipsis, style: TextStyle(color: current.color, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const SizedBox(width: 14),
          RollingDice(
            value: g.lastRoll ?? 6,
            rollId: g.rolls,
            color: current.color,
            size: 64,
            onTap: g.phase == LudoPhase.roll
                ? () {
                    HapticFeedback.mediumImpact().ignore();
                    g.roll();
                  }
                : null,
          ),
        ]),
      ]),
    );
  }
}

class _Board extends StatefulWidget {
  final List<GpPlayer> players;
  final LudoLogic g;
  const _Board({required this.players, required this.g});

  @override
  State<_Board> createState() => _BoardState();
}

/// Tokens walk to their new square one square at a time, so everyone can follow a move.
/// A captured token goes back to base once the attacker has landed.
class _BoardState extends State<_Board> {
  static const stepMs = 200;
  static const _baseOrigins = [(0, 0), (9, 0), (9, 9), (0, 9)];
  static const _homeOffsets = [Offset(-0.35, 0), Offset(0, -0.35), Offset(0.35, 0), Offset(0, 0.35)];

  LudoLogic get g => widget.g;
  List<GpPlayer> get players => widget.players;
  late List<List<int>> shown = [for (final t in g.tokens) List.of(t)];
  Timer? _timer;

  @override
  void didUpdateWidget(_Board old) {
    super.didUpdateWidget(old);
    if (shown.length != g.tokens.length) shown = [for (final t in g.tokens) List.of(t)];
    _walk();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _settled {
    for (var p = 0; p < g.tokens.length; p++) {
      for (var t = 0; t < LudoLogic.tokensEach; t++) {
        if (shown[p][t] != g.tokens[p][t]) return false;
      }
    }
    return true;
  }

  void _walk() {
    if (_timer != null || _settled) return;
    _timer = Timer.periodic(const Duration(milliseconds: stepMs), (_) {
      if (!mounted) return;
      setState(_step);
      if (_settled) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  /// One step: walking tokens move a square; sent-home tokens wait for the walkers to land.
  void _step() {
    var walking = false;
    for (var p = 0; p < g.tokens.length; p++) {
      for (var t = 0; t < LudoLogic.tokensEach; t++) {
        final want = g.tokens[p][t], now = shown[p][t];
        if (want > now) {
          shown[p][t] = now + 1; // out of base onto the start square, then square by square
          walking = true;
        } else if (want < now && want >= 0) {
          shown[p][t] = want; // (only if the state jumped, e.g. online catching up)
        }
      }
    }
    if (walking) return;
    for (var p = 0; p < g.tokens.length; p++) {
      for (var t = 0; t < LudoLogic.tokensEach; t++) {
        if (g.tokens[p][t] == -1 && shown[p][t] != -1) shown[p][t] = -1; // captured: back to base
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _walk();
    final seatColors = List<Color?>.filled(4, null);
    for (var p = 0; p < players.length; p++) {
      seatColors[g.seats[p]] = players[p].color;
    }
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth / 15;
      // Where each token sits, in cell units (centre).
      final placed = <(int, int, Offset)>[];
      for (var p = 0; p < players.length; p++) {
        final seat = g.seats[p];
        for (var t = 0; t < LudoLogic.tokensEach; t++) {
          final prog = shown[p][t];
          Offset at;
          if (prog == -1) {
            final (bx, by) = _baseOrigins[seat];
            at = Offset(bx + 2.0 + (t % 2) * 2, by + 2.0 + (t ~/ 2) * 2);
          } else if (prog == LudoLogic.home) {
            at = const Offset(7.5, 7.5) + _homeOffsets[seat] * 2.2 + Offset((t - 1.5) * 0.18, (t - 1.5) * 0.18);
          } else {
            final (col, row) = g.squareOf(p, prog)!;
            at = Offset(col + 0.5, row + 0.5);
          }
          placed.add((p, t, at));
        }
      }
      // Spread tokens sharing a square.
      final widgets = <Widget>[], onTop = <Widget>[];
      for (final (p, t, at) in placed) {
        final same = placed.where((o) => (o.$3 - at).distance < 0.01).toList();
        final k = same.indexWhere((o) => o.$1 == p && o.$2 == t);
        final spread = same.length > 1 && shown[p][t] >= 0 ? Offset(cos(k * 2 * pi / same.length), sin(k * 2 * pi / same.length)) * 0.22 : Offset.zero;
        final pos = (at + spread) * s;
        final movable = g.canMove(p, t);
        final moving = shown[p][t] != g.tokens[p][t];
        final size = s * (shown[p][t] == LudoLogic.home ? 0.55 : (moving ? 0.95 : 0.8)); // a walking token is lifted a little
        (movable || moving ? onTop : widgets).add(AnimatedPositioned(
          key: ValueKey('tok$p-$t'),
          duration: const Duration(milliseconds: stepMs - 30),
          curve: Curves.easeOut,
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          width: size,
          height: size,
          child: Semantics(
            button: movable,
            label: '${players[p].name} token ${t + 1}',
            child: GestureDetector(
              onTap: movable
                  ? () {
                      HapticFeedback.selectionClick().ignore();
                      g.move(t);
                    }
                  : null,
              child: _Pawn(color: players[p].color, glow: movable),
            ),
          ),
        ));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _LudoPainter(seatColors))),
          ...widgets,
          ...onTop, // movable tokens above the rest so they're easy to tap
        ]),
      );
    });
  }
}

class _Pawn extends StatelessWidget {
  final Color color;
  final bool glow;
  const _Pawn({required this.color, required this.glow});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(color, Colors.white, 0.5)!, color, Color.lerp(color, Colors.black, 0.3)!]),
          border: Border.all(color: glow ? Colors.white : Colors.black87, width: glow ? 3 : 1.5),
          boxShadow: [
            const BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 2)),
            if (glow) const BoxShadow(color: Color(0xFFFFE066), blurRadius: 10, spreadRadius: 2),
          ],
        ),
      );
}

class _LudoPainter extends CustomPainter {
  final List<Color?> seatColors;
  _LudoPainter(this.seatColors);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 15;
    Color seat(int i) => seatColors[i] ?? const Color(0xFF9A9AB0);
    Rect cell(int c, int r) => Rect.fromLTWH(c * s, r * s, s, s);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black26;

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    // Bases.
    const origins = [(0, 0), (9, 0), (9, 9), (0, 9)];
    for (var i = 0; i < 4; i++) {
      final (bx, by) = origins[i];
      final base = Rect.fromLTWH(bx * s, by * s, 6 * s, 6 * s);
      canvas.drawRect(base, Paint()..color = seat(i));
      final inner = RRect.fromRectAndRadius(base.deflate(s * 0.8), Radius.circular(s * 0.5));
      canvas.drawRRect(inner, Paint()..color = Colors.white);
      for (var t = 0; t < 4; t++) {
        final c = Offset((bx + 2.0 + (t % 2) * 2) * s, (by + 2.0 + (t ~/ 2) * 2) * s);
        canvas.drawCircle(c, s * 0.62, Paint()..color = seat(i).withValues(alpha: 0.35));
        canvas.drawCircle(c, s * 0.62, line);
      }
    }
    // Track.
    for (var i = 0; i < 52; i++) {
      final (c, r) = LudoLogic.track[i];
      final rect = cell(c, r);
      final startSeat = i % 13 == 0 ? i ~/ 13 : null;
      canvas.drawRect(rect, Paint()..color = startSeat != null ? seat(startSeat) : Colors.white);
      canvas.drawRect(rect, line);
      if (LudoLogic.safeCells.contains(i)) _star(canvas, rect.center, s * 0.3, startSeat != null ? Colors.white : const Color(0xFFB0B0C8));
    }
    // Home columns.
    for (var i = 0; i < 4; i++) {
      for (final (c, r) in LudoLogic.homeColumns[i]) {
        canvas.drawRect(cell(c, r), Paint()..color = seat(i));
        canvas.drawRect(cell(c, r), line);
      }
    }
    // Centre: four triangles pointing in.
    final centre = Offset(7.5 * s, 7.5 * s);
    final corners = [Offset(6 * s, 6 * s), Offset(9 * s, 6 * s), Offset(9 * s, 9 * s), Offset(6 * s, 9 * s)];
    // Triangle i sits on the side facing seat i's home column: left, top, right, bottom.
    final sides = [(corners[3], corners[0]), (corners[0], corners[1]), (corners[1], corners[2]), (corners[2], corners[3])];
    for (var i = 0; i < 4; i++) {
      final (a, b) = sides[i];
      canvas.drawPath(Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(centre.dx, centre.dy)
        ..close(), Paint()..color = seat(i));
    }
    canvas.drawCircle(centre, s * 0.45, Paint()..color = Colors.white);
    final tp = TextPainter(text: TextSpan(text: '🏆', style: TextStyle(fontSize: s * 0.55)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
    canvas.drawRect(Offset.zero & size, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black45);
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LudoPainter old) => true;
}
