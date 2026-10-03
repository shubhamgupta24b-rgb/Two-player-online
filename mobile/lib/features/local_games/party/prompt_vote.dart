import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import 'party_widgets.dart';

enum VoteMode { mostLikely, wouldRather }

enum PromptPhase { vote, reveal, done }

/// Secret-vote party prompts.
/// Most Likely To: everyone votes for a player; the most-voted get a 👑 point.
/// Would You Rather: everyone picks A or B; everyone on the bigger side scores.
class PromptVoteLogic extends LocalGameLogic {
  final VoteMode mode;
  final int players;
  final int rounds;
  final List<String> prompts; // Would You Rather: "A|B"
  PromptPhase phase = PromptPhase.vote;
  int round = 0;
  late final List<int?> votes = List.filled(players, null);
  late final List<int> score = List.filled(players, 0);
  List<int> lastWinners = []; // players (most likely) or options (would rather) that won the round

  PromptVoteLogic({required this.mode, required this.players, required List<String> prompts, this.rounds = 8, Random? random})
      : prompts = ([...prompts]..shuffle(random ?? Random())).take(rounds).toList();

  String get prompt => prompts[round % prompts.length];
  int get votesIn => votes.where((v) => v != null).length;
  int get voteTurn => [for (var i = 0; i < players; i++) if (votes[i] == null) i].firstOrNull ?? 0;
  List<int> tally(int options) => [for (var o = 0; o < options; o++) votes.where((v) => v == o).length];

  @override
  bool get finished => phase == PromptPhase.done;
  @override
  List<int> get scores => score;
  @override
  void update(int elapsedMs) {}

  void vote(int voter, int choice) {
    if (forward('vote', [voter, choice])) return;
    if (phase != PromptPhase.vote || voter < 0 || voter >= players) return;
    final options = mode == VoteMode.mostLikely ? players : 2;
    if (choice < 0 || choice >= options) return;
    votes[voter] = choice;
    if (votesIn == players) _reveal();
    notifyListeners();
  }

  void _reveal() {
    final t = tally(mode == VoteMode.mostLikely ? players : 2);
    final best = t.reduce(max);
    if (mode == VoteMode.mostLikely) {
      lastWinners = [for (var i = 0; i < players; i++) if (t[i] == best) i];
      for (final w in lastWinners) {
        score[w]++;
      }
    } else {
      lastWinners = t[0] == t[1] ? [] : [t[0] > t[1] ? 0 : 1];
      for (var i = 0; i < players; i++) {
        if (lastWinners.contains(votes[i])) score[i]++;
      }
    }
    phase = PromptPhase.reveal;
  }

  void next() {
    if (forward('next', const [])) return;
    if (phase != PromptPhase.reveal) return;
    round++;
    votes.fillRange(0, players, null);
    phase = round >= rounds ? PromptPhase.done : PromptPhase.vote;
    notifyListeners();
  }
}

RelaySpec<PromptVoteLogic> promptVoteRelay(PromptVoteLogic Function(int players) create, Widget Function(BuildContext, PromptVoteLogic, List<GpPlayer>, int) view) =>
    RelaySpec<PromptVoteLogic>(
      create: create,
      save: (g) => {'phase': g.phase.index, 'round': g.round, 'votes': g.votes, 'score': g.score, 'winners': g.lastWinners, 'prompts': g.prompts},
      load: (g, s, me) {
        g.phase = PromptPhase.values[asInt(s['phase'])];
        g.round = asInt(s['round']);
        g.votes.setAll(0, nInts(s['votes']));
        g.score.setAll(0, ints(s['score']));
        g.lastWinners = ints(s['winners']);
        g.prompts
          ..clear()
          ..addAll((s['prompts'] as List).cast<String>());
      },
      apply: (g, from, name, a) {
        if (name == 'vote' && asInt(a[0]) == from) g.vote(from, asInt(a[1]));
        if (name == 'next') g.next();
      },
      view: view,
    );

class PromptVoteView extends StatefulWidget {
  final List<GpPlayer> players;
  final PromptVoteLogic g;
  final int? me;
  final String title;
  final Color color;
  const PromptVoteView({super.key, required this.players, required this.g, this.me, required this.title, required this.color});
  @override
  State<PromptVoteView> createState() => _PromptVoteViewState();
}

class _PromptVoteViewState extends State<PromptVoteView> {
  bool _shown = false;

  PromptVoteLogic get g => widget.g;
  bool get mostLikely => g.mode == VoteMode.mostLikely;
  List<String> get options => g.prompt.split('|');

  Widget _promptCard() => PromptCard(
        header: 'ROUND ${g.round + 1} OF ${g.rounds}',
        text: mostLikely ? 'Who is most likely to ${g.prompt}?' : 'Would you rather…',
        emoji: mostLikely ? '👉' : '🤔',
        color: widget.color,
      );

  Widget _choices(int voter, {required VoidCallback after}) {
    final players = widget.players;
    if (mostLikely) {
      return PlayerPicker(players: players, highlight: g.votes[voter], onPick: (i) {
        g.vote(voter, i);
        after();
      });
    }
    return Column(children: [
      for (var o = 0; o < 2; o++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GpButton('${o == 0 ? 'A' : 'B'}: ${options[o]}', color: o == 0 ? const Color(0xFF4D96FF) : const Color(0xFFFF6B6B), textColor: Colors.white, onPressed: () {
            g.vote(voter, o);
            after();
          }),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.players, me = widget.me;
    switch (g.phase) {
      case PromptPhase.vote:
        if (me != null) {
          final voted = g.votes[me] != null;
          return PartyFrame(
            title: widget.title,
            subtitle: 'Secret vote · ${g.votesIn}/${players.length} voted',
            child: SingleChildScrollView(
              child: Column(children: [
                _promptCard(),
                const SizedBox(height: 16),
                if (voted) const WaitingNote('Vote in! Waiting for the others…') else _choices(me, after: () {}),
              ]),
            ),
          );
        }
        final p = g.voteTurn;
        return PartyFrame(
          title: widget.title,
          subtitle: 'Secret vote · ${g.votesIn}/${players.length} voted',
          child: PassAndReveal(
            player: players[p],
            revealed: _shown,
            onReveal: () => setState(() => _shown = true),
            onDone: null, // voting is the way on
            doneLabel: 'TAP YOUR CHOICE ABOVE',
            secret: Column(children: [_promptCard(), const SizedBox(height: 16), _choices(p, after: () => setState(() => _shown = false))]),
          ),
        );
      case PromptPhase.reveal:
      case PromptPhase.done:
        final Widget results;
        if (mostLikely) {
          final t = g.tally(players.length);
          results = Column(children: [
            Text(g.lastWinners.map((w) => players[w].name).join(' & '), textAlign: TextAlign.center, style: const TextStyle(color: GpColors.accent, fontWeight: FontWeight.w900, fontSize: 26)),
            const Text('👑 +1 point', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            PlayerPicker(players: players, counts: {for (var i = 0; i < players.length; i++) i: t[i]}, highlight: g.lastWinners.length == 1 ? g.lastWinners.single : null),
          ]);
        } else {
          final t = g.tally(2);
          results = Column(children: [
            for (var o = 0; o < 2; o++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (o == 0 ? const Color(0xFF4D96FF) : const Color(0xFFFF6B6B)).withValues(alpha: g.lastWinners.contains(o) ? 1 : 0.4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  Expanded(child: Text(options[o], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                  Text('${t[o]} 🙋', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
              ),
            Text(g.lastWinners.isEmpty ? 'A perfect split! No points.' : 'The majority scores a point!', style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800)),
          ]);
        }
        return PartyFrame(
          title: widget.title,
          subtitle: 'The votes are in!',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: SingleChildScrollView(child: Column(children: [_promptCard(), const SizedBox(height: 16), results]))),
            GpButton(g.round + 1 >= g.rounds ? 'SEE SCORES' : 'NEXT QUESTION', icon: Icons.arrow_forward_rounded, onPressed: g.next),
          ]),
        );
    }
  }
}
