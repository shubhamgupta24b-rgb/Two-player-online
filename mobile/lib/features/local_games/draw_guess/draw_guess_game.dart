import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../party/party_widgets.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

enum DrawPhase { ready, drawing, turnEnd, done }

/// Draw & Guess: each player in turn draws a secret word; whoever guesses it first scores
/// a point, and so does the artist. 75 seconds per drawing.
class DrawGuessLogic extends LocalGameLogic {
  static const words = [
    'Sun', 'House', 'Tree', 'Cat', 'Car', 'Fish', 'Pizza', 'Phone', 'Guitar', 'Rainbow', 'Rocket', 'Umbrella', 'Kite', 'Cricket bat', //
    'Ice cream', 'Clock', 'Glasses', 'Train', 'Flower', 'Star', 'Heart', 'Snowman', 'Elephant', 'Ladder', 'Balloon', 'Book', 'Bicycle', //
    'Chair', 'Moon', 'Apple', 'Banana', 'Spider', 'Mountain', 'Boat', 'Crown', 'Fire', 'Key', 'Lamp', 'Snake', 'Shoe', 'Hat', 'Cake', //
    'Camera', 'Bridge', 'Bird', 'Ghost', 'Butterfly', 'Candle', 'Football', 'Robot', 'Laptop', 'Mango', 'Pencil', 'Cloud', 'Tiger', //
    'Rain', 'Sword', 'Castle', 'Dinosaur', 'Trophy',
  ];
  static const turnMs = 75000;
  static const maxPoints = 4000;

  final int players;
  final int turnsEach;
  final List<String> deck;
  DrawPhase phase = DrawPhase.ready;
  int turn = 0;
  int now = 0, deadline = 0;
  final List<List<double>> strokes = []; // each stroke: x0, y0, x1, y1, ... in 0..1
  late final List<int> score = List.filled(players, 0);
  int guessedBy = -1;
  final List<String> wrongGuesses = []; // online: the latest wrong guesses, newest last
  final List<double> _pending = []; // online drawer: points not sent yet
  bool _pendingNew = false;

  DrawGuessLogic({this.players = 2, Random? random})
      : turnsEach = players <= 3 ? 2 : 1,
        deck = [...words]..shuffle(random ?? Random());

  int get drawer => turn % players;
  int get totalTurns => players * turnsEach;
  String get word => deck[turn % deck.length];
  int get msLeft => max(0, deadline - now);
  int get pointCount => strokes.fold(0, (n, s) => n + s.length ~/ 2);

  @override
  bool get finished => phase == DrawPhase.done;
  @override
  List<int> get scores => score;

  @override
  void update(int elapsedMs) {
    now = elapsedMs;
    if (phase == DrawPhase.drawing) {
      if (now >= deadline) phase = DrawPhase.turnEnd;
      notifyListeners();
    }
  }

  void start() {
    if (forward('start', const [])) return;
    if (phase != DrawPhase.ready) return;
    strokes.clear();
    wrongGuesses.clear();
    guessedBy = -1;
    deadline = now + turnMs;
    phase = DrawPhase.drawing;
    notifyListeners();
  }

  /// Adds a point to the drawing ([newStroke] starts a new line).
  void addPoint(double x, double y, {bool newStroke = false}) {
    if (phase != DrawPhase.drawing || pointCount >= maxPoints) return;
    x = x.clamp(0, 1);
    y = y.clamp(0, 1);
    if (newStroke || strokes.isEmpty) strokes.add([]);
    strokes.last.addAll([x, y]);
    if (isGuest) {
      // Online artist on a guest phone: show it straight away, send in small batches.
      if (newStroke) {
        flushInk();
        _pendingNew = true;
      }
      _pending.addAll([x, y]);
      if (_pending.length >= 16) flushInk();
    }
    notifyListeners();
  }

  /// Online: sends the points drawn since the last batch.
  void flushInk() {
    if (_pending.isEmpty) return;
    final encoded = [for (var i = 0; i < _pending.length; i += 2) '${_pending[i].toStringAsFixed(3)},${_pending[i + 1].toStringAsFixed(3)}'].join(';');
    final isNew = _pendingNew;
    _pending.clear();
    _pendingNew = false;
    forward('ink', [isNew, encoded]);
  }

  /// Host: applies a batch of points from the drawer's phone.
  void inkBatch(bool newStroke, String encoded) {
    final pts = [for (final p in encoded.split(';')) ...p.split(',').map(double.parse)];
    for (var i = 0; i + 1 < pts.length; i += 2) {
      addPoint(pts[i], pts[i + 1], newStroke: newStroke && i == 0);
    }
  }

  void clearDrawing() {
    if (forward('clear', const [])) return;
    if (phase != DrawPhase.drawing) return;
    strokes.clear();
    notifyListeners();
  }

  /// One phone: the artist taps who shouted the right answer.
  void correct(int guesser) {
    if (forward('correct', [guesser])) return;
    if (phase != DrawPhase.drawing || guesser == drawer || guesser < 0 || guesser >= players) return;
    score[drawer]++;
    score[guesser]++;
    guessedBy = guesser;
    phase = DrawPhase.turnEnd;
    notifyListeners();
  }

  /// Online: a typed guess; the host checks it.
  void guess(int guesser, String text) {
    if (forward('guess', [guesser, text])) return;
    if (phase != DrawPhase.drawing || guesser == drawer) return;
    String norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (norm(text) == norm(word)) {
      correct(guesser);
    } else {
      wrongGuesses.add(text.length > 24 ? text.substring(0, 24) : text);
      if (wrongGuesses.length > 5) wrongGuesses.removeAt(0);
      notifyListeners();
    }
  }

  void giveUp() {
    if (forward('giveUp', const [])) return;
    if (phase != DrawPhase.drawing) return;
    phase = DrawPhase.turnEnd;
    notifyListeners();
  }

  void next() {
    if (forward('next', const [])) return;
    if (phase != DrawPhase.turnEnd) return;
    turn++;
    phase = turn >= totalTurns ? DrawPhase.done : DrawPhase.ready;
    notifyListeners();
  }
}

String _encode(List<double> s) => [for (var i = 0; i + 1 < s.length; i += 2) '${s[i].toStringAsFixed(3)},${s[i + 1].toStringAsFixed(3)}'].join(';');
List<double> _decode(String s) => s.isEmpty ? [] : [for (final p in s.split(';')) ...p.split(',').map(double.parse)];

final drawGuessInfo = LocalGameInfo(
  id: 'draw_guess',
  title: 'Draw & Guess',
  emoji: '🎨',
  color: const Color(0xFFE84393),
  tagline: 'Draw it. Guess it. No words!',
  rules: const [
    'On your turn, peek at the secret word (hold the 👁 button) and draw it. No letters or numbers!',
    'Everyone else guesses out loud. Tap who got it: you both score a point.',
    'Online, guessers type their answers and the app checks them. 75 seconds per drawing. 2 to 6 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  maxPlayers: 6,
  online: RelaySpec<DrawGuessLogic>(
    create: (n) => DrawGuessLogic(players: n),
    save: (g) => {
      'phase': g.phase.index, 'turn': g.turn, 'left': g.msLeft, 'score': g.score, 'by': g.guessedBy, 'deck': g.deck, //
      'strokes': [for (final s in g.strokes) _encode(s)], 'wrong': g.wrongGuesses,
    },
    load: (g, s, me) {
      final turn = asInt(s['turn']);
      final phase = DrawPhase.values[asInt(s['phase'])];
      final hostStrokes = [for (final e in (s['strokes'] as List).cast<String>()) _decode(e)];
      final hostPoints = hostStrokes.fold<int>(0, (n, st) => n + st.length ~/ 2);
      // The artist's own drawing is ahead of the host's copy: keep it unless the host has caught up.
      final mine = me == turn % g.players && phase == DrawPhase.drawing && turn == g.turn;
      if (!mine || hostPoints >= g.pointCount) {
        g.strokes
          ..clear()
          ..addAll(hostStrokes);
      }
      g.phase = phase;
      g.turn = turn;
      g.now = 0;
      g.deadline = asInt(s['left']);
      g.score.setAll(0, ints(s['score']));
      g.guessedBy = asInt(s['by']);
      g.deck
        ..clear()
        ..addAll((s['deck'] as List).cast<String>());
      g.wrongGuesses
        ..clear()
        ..addAll((s['wrong'] as List).cast<String>());
    },
    apply: (g, from, name, a) {
      switch (name) {
        case 'ink' when from == g.drawer:
          g.inkBatch(a[0] == true, a[1] as String);
        case 'guess':
          g.guess(from, '${a[1]}');
        case 'start' || 'clear' || 'giveUp' when from == g.drawer:
          if (name == 'start') g.start();
          if (name == 'clear') g.clearDrawing();
          if (name == 'giveUp') g.giveUp();
        case 'next':
          g.next();
      }
    },
    view: (context, g, players, me) => _DrawView(players: players, g: g, me: me),
  ),
  play: (players, onFinished) => TickingPlay<DrawGuessLogic>(
    create: () => DrawGuessLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _DrawView(players: players, g: g),
  ),
);

class _DrawView extends StatefulWidget {
  final List<GpPlayer> players;
  final DrawGuessLogic g;
  final int? me;
  const _DrawView({required this.players, required this.g, this.me});
  @override
  State<_DrawView> createState() => _DrawViewState();
}

class _DrawViewState extends State<_DrawView> {
  bool _peek = false;
  final _guess = TextEditingController();

  @override
  void dispose() {
    _guess.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, players = widget.players, me = widget.me;
    final artist = players[g.drawer];
    final isArtist = me == null || me == g.drawer;
    final turnLabel = 'TURN ${min(g.turn + 1, g.totalTurns)} / ${g.totalTurns}';
    switch (g.phase) {
      case DrawPhase.ready:
        return PartyFrame(
          title: '🎨 DRAW & GUESS',
          subtitle: turnLabel,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: PromptCard(
                  header: '${artist.whose} TURN TO DRAW',
                  text: isArtist ? 'Take the phone!' : 'Get ready to guess!',
                  emoji: '✏️',
                  footer: isArtist ? 'Only you may see the word: hold the 👁 button to peek.' : '${artist.name} is about to draw.',
                  color: artist.color,
                ),
              ),
            ),
            if (isArtist) GpButton('START DRAWING', icon: Icons.brush_rounded, color: artist.color, textColor: Colors.white, onPressed: g.start) else const WaitingNote('Waiting for the artist…'),
          ]),
        );
      case DrawPhase.drawing:
        final online = me != null;
        return PartyFrame(
          title: '${artist.name.toUpperCase()} IS DRAWING',
          subtitle: turnLabel,
          trailing: TimeChip(g.msLeft),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (isArtist)
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _peek = true),
                    onTapUp: (_) => setState(() => _peek = false),
                    onTapCancel: () => setState(() => _peek = false),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _peek || online ? Colors.white : Colors.white12, borderRadius: BorderRadius.circular(14)),
                      child: Text(_peek || online ? 'DRAW: ${g.word.toUpperCase()}' : '👁 HOLD TO SEE THE WORD',
                          style: TextStyle(color: _peek || online ? GpColors.ink : Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(tooltip: 'Clear', onPressed: g.clearDrawing, icon: const Icon(Icons.delete_outline_rounded)),
              ]),
            const SizedBox(height: 8),
            Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _Canvas(g: g, canDraw: isArtist)))),
            const SizedBox(height: 8),
            if (!online) ...[
              const Text('WHO GUESSED IT?', textAlign: TextAlign.center, style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < players.length; i++)
                    if (i != g.drawer)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: players[i].color,
                          side: BorderSide.none,
                          label: Text(players[i].name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                          onPressed: () {
                            HapticFeedback.mediumImpact().ignore();
                            g.correct(i);
                          },
                        ),
                      ),
                  TextButton(onPressed: g.giveUp, child: const Text('NOBODY · SKIP', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900))),
                ]),
              ),
            ] else if (isArtist) ...[
              Text(g.wrongGuesses.isEmpty ? 'Guesses will appear here' : 'Guesses: ${g.wrongGuesses.join(', ')}', textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
              TextButton(onPressed: g.giveUp, child: const Text('GIVE UP', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900))),
            ] else ...[
              if (g.wrongGuesses.isNotEmpty) Text('Wrong: ${g.wrongGuesses.join(', ')}', textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _guess,
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(hintText: 'Type your guess', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(16)))),
                    onSubmitted: (t) => _send(me),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: () => _send(me), icon: const Icon(Icons.send_rounded)),
              ]),
            ],
          ]),
        );
      case DrawPhase.turnEnd:
      case DrawPhase.done:
        final by = g.guessedBy;
        return PartyFrame(
          title: by >= 0 ? '🎉 ${players[by].name.toUpperCase()} GOT IT!' : "😅 NOBODY GOT IT",
          subtitle: turnLabel,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _Canvas(g: g, canDraw: false)))),
            const SizedBox(height: 8),
            Text('The word was: ${g.word}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            GpButton(g.turn + 1 >= g.totalTurns ? 'SEE SCORES' : 'NEXT ARTIST', icon: Icons.arrow_forward_rounded, onPressed: g.next),
          ]),
        );
    }
  }

  void _send(int me) {
    final t = _guess.text.trim();
    if (t.isEmpty) return;
    widget.g.guess(me, t);
    _guess.clear();
  }
}

class _Canvas extends StatelessWidget {
  final DrawGuessLogic g;
  final bool canDraw;
  const _Canvas({required this.g, required this.canDraw});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = c.biggest;
        Offset norm(Offset p) => Offset(p.dx / size.width, p.dy / size.height);
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: GestureDetector(
            onPanStart: canDraw ? (d) => g.addPoint(norm(d.localPosition).dx, norm(d.localPosition).dy, newStroke: true) : null,
            onPanUpdate: canDraw ? (d) => g.addPoint(norm(d.localPosition).dx, norm(d.localPosition).dy) : null,
            onPanEnd: canDraw ? (_) => g.flushInk() : null,
            child: CustomPaint(size: size, painter: _InkPainter(g.strokes, g.pointCount)),
          ),
        );
      });
}

class _InkPainter extends CustomPainter {
  final List<List<double>> strokes;
  final int count;
  _InkPainter(this.strokes, this.count);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final pen = Paint()
      ..color = const Color(0xFF1E1B3A)
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s[0] * size.width, s[1] * size.height);
      if (s.length == 2) {
        canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), pen.strokeWidth / 2, Paint()..color = pen.color);
        continue;
      }
      for (var i = 2; i + 1 < s.length; i += 2) {
        path.lineTo(s[i] * size.width, s[i + 1] * size.height);
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}
