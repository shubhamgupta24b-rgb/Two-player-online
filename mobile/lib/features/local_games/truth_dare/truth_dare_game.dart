import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;
import '../shell/ticking_play.dart';

enum TodPhase { spin, spinning, choose, prompt, finished }

/// Spin the bottle, then Truth or Dare. Doing it scores a point; skipping scores nothing.
/// Each player gets [spinsEach] spins on average; most points wins.
class TruthDareLogic extends LocalGameLogic {
  static const truths = [
    'What is the most embarrassing thing in your phone gallery?',
    'Who in this room would you call at 3 a.m. in an emergency?',
    'What is a habit you hide from everyone?',
    'What was your most awkward moment in class?',
    'What is the last lie you told?',
    'Which app do you spend the most time on, honestly?',
    'What is your most irrational fear?',
    'Who was your first crush?',
    'What is the weirdest food combo you secretly love?',
    'What is something you pretend to understand but don’t?',
    'If you could swap lives with someone here for a day, who and why?',
    'What is the silliest reason you have cried?',
    'What is the worst gift you ever received?',
    'What is your guilty-pleasure song?',
    'Have you ever blamed someone else for something you did?',
    'What is the most childish thing you still do?',
    'What is one thing you would change about yourself?',
    'Which teacher did you like the most, and why?',
    'What is the longest you have gone without a shower?',
    'What is the funniest nickname you have had?',
    'What is a secret talent nobody here knows about?',
    'What was your most cringe social media post?',
    'Who here do you think would survive a zombie apocalypse?',
    'What is the most money you have wasted on something useless?',
    'What is a rumour you once believed?',
  ];
  static const dares = [
    'Do your best impression of someone in this room.',
    'Talk in an accent for the next two rounds.',
    'Do 15 jumping jacks right now.',
    'Sing the chorus of the last song you listened to.',
    'Let the group choose a funny pose for you to hold for 20 seconds.',
    'Speak without closing your mouth for 30 seconds.',
    'Do a dramatic movie-trailer voice describing your day.',
    'Show the last photo you took (only if it’s OK to share!).',
    'Dance for 20 seconds with no music.',
    'Balance a spoon (or pen) on your nose for 10 seconds.',
    'Say the alphabet backwards as fast as you can.',
    'Act like a cat until your next turn.',
    'Compliment every player in a different way.',
    'Try to lick your elbow.',
    'Do your best robot dance.',
    'Tell a joke. If nobody laughs, do 5 push-ups.',
    'Make up a 4-line rap about the person on your left.',
    'Walk like a model across the room.',
    'Hold a plank for 30 seconds.',
    'Say "I love Party Games" in three different voices.',
    'Let someone draw a tiny smiley on your hand.',
    'Pretend to be a news reporter for 30 seconds.',
    'Speak only in questions until your next turn.',
    'Do your best evil laugh.',
    'Imitate a famous celebrity until someone guesses who.',
  ];

  final int players;
  final int totalSpins;
  final Random _random;
  final List<int> points;
  late final List<String> _truthDeck = [...truths]..shuffle(_random);
  late final List<String> _dareDeck = [...dares]..shuffle(_random);
  TodPhase phase = TodPhase.spin;
  int spins = 0;
  int? chosen;
  bool truth = true;
  String prompt = '';

  TruthDareLogic({this.players = 2, int spinsEach = 3, Random? random})
      : totalSpins = players * spinsEach,
        _random = random ?? Random(),
        points = List.filled(players, 0);

  @override
  bool get finished => phase == TodPhase.finished;
  @override
  List<int> get scores => points;
  @override
  void update(int elapsedMs) {}

  /// Starts a spin; returns the player it will land on (or [target], for tests).
  int? spin([int? target]) {
    if (forward('spin', const [])) return null;
    if (phase != TodPhase.spin) return null;
    chosen = target ?? _random.nextInt(players);
    phase = TodPhase.spinning;
    notifyListeners();
    return chosen;
  }

  /// The bottle has stopped.
  void landed() {
    if (forward('landed', const [])) return;
    if (phase != TodPhase.spinning) return;
    phase = TodPhase.choose;
    notifyListeners();
  }

  void choose({required bool truth}) {
    if (forward('choose', [truth])) return;
    if (phase != TodPhase.choose) return;
    this.truth = truth;
    final deck = truth ? _truthDeck : _dareDeck;
    prompt = deck.removeLast();
    deck.insert(0, prompt); // recycle at the bottom
    phase = TodPhase.prompt;
    notifyListeners();
  }

  void complete({required bool done}) {
    if (forward('complete', [done])) return;
    if (phase != TodPhase.prompt) return;
    if (done) points[chosen!]++;
    spins++;
    phase = spins >= totalSpins ? TodPhase.finished : TodPhase.spin;
    notifyListeners();
  }
}

final truthDareInfo = LocalGameInfo(
  id: 'truth_dare',
  title: 'Truth or Dare',
  emoji: '🍾',
  color: const Color(0xFFFF4FA3),
  tagline: 'Spin the bottle. No chickening out!',
  rules: const [
    'Sit in a circle around the phone and tap SPIN.',
    'Whoever the bottle points to picks TRUTH or DARE.',
    'Do it for +1 point, or skip for nothing. Most points after everyone has had 3 spins wins!',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  maxPlayers: 6,
  online: RelaySpec<TruthDareLogic>(
    create: (n) => TruthDareLogic(players: n),
    save: (g) => {'phase': g.phase.index, 'spins': g.spins, 'chosen': g.chosen, 'truth': g.truth, 'prompt': g.prompt, 'points': g.points},
    load: (g, s, me) {
      g.phase = TodPhase.values[asInt(s['phase'])];
      g.spins = asInt(s['spins']);
      g.chosen = nInt(s['chosen']);
      g.truth = s['truth'] == true;
      g.prompt = s['prompt'] as String;
      g.points.setAll(0, ints(s['points']));
    },
    apply: (g, from, name, a) {
      switch (name) {
        case 'spin':
          g.spin(); // anyone can spin
        case 'landed':
          g.landed();
        case 'choose' when from == g.chosen:
          g.choose(truth: a[0] == true);
        case 'complete' when from == g.chosen:
          g.complete(done: a[0] == true);
      }
    },
    view: (context, g, players, me) => _TodTable(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<TruthDareLogic>(
    create: () => TruthDareLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _TodTable(players: players, g: g),
  ),
);

class _TodTable extends StatefulWidget {
  final List<GpPlayer> players;
  final TruthDareLogic g;
  const _TodTable({required this.players, required this.g});
  @override
  State<_TodTable> createState() => _TodTableState();
}

class _TodTableState extends State<_TodTable> {
  double _angle = 0; // bottle angle where it rests now

  double _angleFor(int i) => -pi / 2 + i * 2 * pi / widget.players.length;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final players = widget.players;
    final target = g.chosen == null ? _angle : _angleFor(g.chosen!) + pi / 2;
    // Always spin forwards several full turns to the target.
    var end = target;
    if (g.phase == TodPhase.spinning) {
      end = target + 2 * pi * 4;
      while (end - _angle < 2 * pi * 4) {
        end += 2 * pi;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 6),
          Expanded(child: Text('SPIN ${min(g.spins + 1, g.totalSpins)} / ${g.totalSpins}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF4FA3), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5))),
          const SizedBox(width: 44),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final r = min(c.maxWidth, c.maxHeight) / 2 - 40;
            final centre = Offset(c.maxWidth / 2, c.maxHeight / 2);
            return Stack(children: [
              Positioned(
                left: centre.dx - r - 20,
                top: centre.dy - r - 20,
                width: 2 * r + 40,
                height: 2 * r + 40,
                child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05), border: Border.all(color: Colors.white12, width: 2))),
              ),
              for (var i = 0; i < players.length; i++)
                Positioned(
                  left: centre.dx + cos(_angleFor(i)) * r - 46,
                  top: centre.dy + sin(_angleFor(i)) * r - 22,
                  width: 92,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: g.chosen == i && g.phase != TodPhase.spinning && g.phase != TodPhase.spin ? 1.2 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: players[i].color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [if (g.chosen == i && g.phase != TodPhase.spinning) BoxShadow(color: players[i].color, blurRadius: 16, spreadRadius: 2)],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(players[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        Text('⭐ ${g.points[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                      ]),
                    ),
                  ),
                ),
              Positioned(
                left: centre.dx - r * 0.55,
                top: centre.dy - r * 0.55,
                width: r * 1.1,
                height: r * 1.1,
                child: Semantics(
                  button: g.phase == TodPhase.spin,
                  label: 'Spin the bottle',
                  child: GestureDetector(
                    onTap: g.phase == TodPhase.spin
                        ? () {
                            HapticFeedback.mediumImpact().ignore();
                            g.spin();
                          }
                        : null,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: _angle, end: end),
                      duration: g.phase == TodPhase.spinning ? const Duration(milliseconds: 2600) : Duration.zero,
                      curve: Curves.easeOutCubic,
                      onEnd: () {
                        if (g.phase == TodPhase.spinning) {
                          _angle = target % (2 * pi);
                          HapticFeedback.heavyImpact().ignore();
                          g.landed();
                        }
                      },
                      builder: (_, a, __) => Transform.rotate(angle: a, child: const CustomPaint(painter: _BottlePainter())),
                    ),
                  ),
                ),
              ),
            ]);
          }),
        ),
        _bottom(g, players),
      ]),
    );
  }

  Widget _bottom(TruthDareLogic g, List<GpPlayer> players) {
    switch (g.phase) {
      case TodPhase.spin:
        return GpButton('SPIN THE BOTTLE', icon: Icons.refresh_rounded, color: const Color(0xFFFF4FA3), textColor: Colors.white, onPressed: g.spin);
      case TodPhase.spinning:
        return const SizedBox(height: 54, child: Center(child: Text('Spinning…', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, fontSize: 16))));
      case TodPhase.choose:
        final p = players[g.chosen!];
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${p.name.toUpperCase()}, PICK ONE!', style: TextStyle(color: p.color, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GpButton('TRUTH', color: const Color(0xFF4D96FF), textColor: Colors.white, onPressed: () => g.choose(truth: true))),
            const SizedBox(width: 12),
            Expanded(child: GpButton('DARE', color: const Color(0xFFFF5E5B), textColor: Colors.white, onPressed: () => g.choose(truth: false))),
          ]),
        ]);
      case TodPhase.prompt:
        final color = g.truth ? const Color(0xFF4D96FF) : const Color(0xFFFF5E5B);
        return TweenAnimationBuilder<double>(
          key: ValueKey(g.prompt),
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: color, width: 4)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(g.truth ? 'TRUTH' : 'DARE', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3)),
              const SizedBox(height: 8),
              Text(g.prompt, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: GpButton('SKIP', color: Colors.black26, textColor: GpColors.ink, onPressed: () => g.complete(done: false))),
                const SizedBox(width: 10),
                Expanded(child: GpButton('DONE +1', color: GpColors.yes, textColor: Colors.white, onPressed: () => g.complete(done: true))),
              ]),
            ]),
          ),
        );
      case TodPhase.finished:
        return const SizedBox(height: 54);
    }
  }
}

/// A green glass bottle pointing up (neck at the top).
class _BottlePainter extends CustomPainter {
  const _BottlePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final bodyW = w * 0.3, neckW = w * 0.11;
    final path = Path()
      ..moveTo(cx - neckW / 2, h * 0.06)
      ..lineTo(cx + neckW / 2, h * 0.06)
      ..lineTo(cx + neckW / 2, h * 0.3)
      ..quadraticBezierTo(cx + bodyW / 2, h * 0.36, cx + bodyW / 2, h * 0.48)
      ..lineTo(cx + bodyW / 2, h * 0.9)
      ..quadraticBezierTo(cx + bodyW / 2, h * 0.95, cx + bodyW / 2 - 6, h * 0.95)
      ..lineTo(cx - bodyW / 2 + 6, h * 0.95)
      ..quadraticBezierTo(cx - bodyW / 2, h * 0.95, cx - bodyW / 2, h * 0.9)
      ..lineTo(cx - bodyW / 2, h * 0.48)
      ..quadraticBezierTo(cx - bodyW / 2, h * 0.36, cx - neckW / 2, h * 0.3)
      ..close();
    canvas.drawPath(path.shift(const Offset(3, 5)), Paint()..color = Colors.black38);
    canvas.drawPath(path, Paint()..shader = const LinearGradient(colors: [Color(0xFF1B7F3A), Color(0xFF39C46A), Color(0xFF1B7F3A)]).createShader(Rect.fromLTWH(cx - bodyW / 2, 0, bodyW, h)));
    // Label and cap.
    canvas.drawRect(Rect.fromLTWH(cx - bodyW / 2, h * 0.58, bodyW, h * 0.18), Paint()..color = const Color(0xFFFFD43B));
    canvas.drawRect(Rect.fromLTWH(cx - neckW / 2 - 1, h * 0.03, neckW + 2, h * 0.05), Paint()..color = const Color(0xFFFF4FA3));
    // Shine.
    canvas.drawLine(Offset(cx - bodyW * 0.28, h * 0.5), Offset(cx - bodyW * 0.28, h * 0.86), Paint()
      ..strokeWidth = bodyW * 0.1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.45));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF0D3D1C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
