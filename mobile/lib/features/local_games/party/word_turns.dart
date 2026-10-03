import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import 'party_widgets.dart';

enum TurnPhase { ready, playing, turnEnd, done }

/// Timed word turns (Dumb Charades, Heads Up): each player in turn gets [turnMs] to get
/// through as many words as possible. GOT IT scores a point for that player; SKIP moves on.
class WordTurnsLogic extends LocalGameLogic {
  final int players;
  final int turnsEach;
  final int turnMs;
  final List<String> deck;
  TurnPhase phase = TurnPhase.ready;
  int turn = 0; // how many turns have been played
  int word = 0; // position in the deck
  int now = 0, deadline = 0;
  late final List<int> score = List.filled(players, 0);
  int gotThisTurn = 0;

  WordTurnsLogic({required this.players, required List<String> words, this.turnsEach = 2, this.turnMs = 60000, Random? random})
      : deck = [...words]..shuffle(random ?? Random());

  int get performer => turn % players;
  int get totalTurns => players * turnsEach;
  String get current => deck[word % deck.length];
  int get msLeft => max(0, deadline - now);

  @override
  bool get finished => phase == TurnPhase.done;
  @override
  List<int> get scores => score;

  @override
  void update(int elapsedMs) {
    now = elapsedMs;
    if (phase == TurnPhase.playing) {
      if (now >= deadline) phase = TurnPhase.turnEnd;
      notifyListeners(); // the clock
    }
  }

  void start() {
    if (forward('start', const [])) return;
    if (phase != TurnPhase.ready) return;
    phase = TurnPhase.playing;
    deadline = now + turnMs;
    gotThisTurn = 0;
    notifyListeners();
  }

  void gotIt() {
    if (forward('got', const [])) return;
    if (phase != TurnPhase.playing) return;
    score[performer]++;
    gotThisTurn++;
    word++;
    notifyListeners();
  }

  void skip() {
    if (forward('skip', const [])) return;
    if (phase != TurnPhase.playing) return;
    word++;
    notifyListeners();
  }

  void next() {
    if (forward('next', const [])) return;
    if (phase != TurnPhase.turnEnd) return;
    turn++;
    word++;
    phase = turn >= totalTurns ? TurnPhase.done : TurnPhase.ready;
    notifyListeners();
  }
}

/// Online support shared by the word-turn games: only the performer runs their turn.
RelaySpec<WordTurnsLogic> wordTurnsRelay({required WordTurnsLogic Function(int players) create, required Widget Function(BuildContext, WordTurnsLogic, List<GpPlayer>, int me) view}) =>
    RelaySpec<WordTurnsLogic>(
      create: create,
      save: (g) => {'phase': g.phase.index, 'turn': g.turn, 'word': g.word, 'left': g.msLeft, 'score': g.score, 'got': g.gotThisTurn, 'deck': g.deck},
      load: (g, s, me) {
        g.phase = TurnPhase.values[asInt(s['phase'])];
        g.turn = asInt(s['turn']);
        g.word = asInt(s['word']);
        g.now = 0;
        g.deadline = asInt(s['left']);
        g.score.setAll(0, ints(s['score']));
        g.gotThisTurn = asInt(s['got']);
        g.deck
          ..clear()
          ..addAll((s['deck'] as List).cast<String>());
      },
      apply: (g, from, name, a) {
        if (name == 'next') return g.next();
        if (from != g.performer) return;
        switch (name) {
          case 'start':
            g.start();
          case 'got':
            g.gotIt();
          case 'skip':
            g.skip();
        }
      },
      view: view,
    );

/// Screen for a word-turn game. [wordFor] decides who sees the word: in Charades only the
/// actor; in Heads Up everyone except the guesser.
class WordTurnsView extends StatelessWidget {
  final List<GpPlayer> players;
  final WordTurnsLogic g;
  final int? me;
  final String title;
  final String readyText; // what the performer does
  final String watchText; // what everyone else does
  final bool performerSeesWord;
  final Color color;
  const WordTurnsView({
    super.key,
    required this.players,
    required this.g,
    this.me,
    required this.title,
    required this.readyText,
    required this.watchText,
    required this.performerSeesWord,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = players[g.performer];
    final isPerformer = me == null || me == g.performer;
    final turnLabel = 'TURN ${min(g.turn + 1, g.totalTurns)} / ${g.totalTurns}';
    switch (g.phase) {
      case TurnPhase.ready:
        return PartyFrame(
          title: title,
          subtitle: turnLabel,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: PromptCard(header: "${p.name.toUpperCase()}'S TURN", text: isPerformer ? readyText : watchText, emoji: '⏱️', footer: '${g.turnMs ~/ 1000} seconds. Get as many as you can!', color: p.color),
                ),
              ),
            ),
            if (isPerformer) GpButton('START', icon: Icons.play_arrow_rounded, color: p.color, textColor: Colors.white, onPressed: g.start) else WaitingNote('Waiting for ${p.name} to start…'),
          ]),
        );
      case TurnPhase.playing:
        final showWord = me == null || (me == g.performer) == performerSeesWord;
        return PartyFrame(
          title: '${p.name.toUpperCase()} · ${g.gotThisTurn} GOT',
          subtitle: turnLabel,
          trailing: TimeChip(g.msLeft),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: showWord
                      ? PromptCard(header: performerSeesWord ? 'ACT THIS OUT' : 'THE WORD IS', text: g.current, color: color)
                      : PromptCard(header: isPerformer ? 'GUESS!' : 'SHOUT YOUR GUESSES!', text: isPerformer ? 'Listen to the clues' : watchText, emoji: '🤔', color: color),
                ),
              ),
            ),
            if (isPerformer)
              Row(children: [
                Expanded(child: GpButton('SKIP', color: Colors.white24, textColor: Colors.white, onPressed: g.skip)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GpButton('GOT IT ✓', color: GpColors.yes, textColor: Colors.white, onPressed: () {
                    HapticFeedback.mediumImpact().ignore();
                    g.gotIt();
                  }),
                ),
              ]),
          ]),
        );
      case TurnPhase.turnEnd:
      case TurnPhase.done:
        return PartyFrame(
          title: "TIME'S UP!",
          subtitle: turnLabel,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(children: [
                    PromptCard(header: p.name.toUpperCase(), text: '${g.gotThisTurn} correct!', emoji: g.gotThisTurn >= 5 ? '🔥' : '👏', color: p.color),
                    const SizedBox(height: 14),
                    PlayerPicker(players: players, notes: {for (var i = 0; i < players.length; i++) i: '${g.score[i]} pts'}),
                  ]),
                ),
              ),
            ),
            GpButton(g.turn + 1 >= g.totalTurns ? 'SEE SCORES' : 'NEXT PLAYER', icon: Icons.arrow_forward_rounded, onPressed: g.next),
          ]),
        );
    }
  }
}
