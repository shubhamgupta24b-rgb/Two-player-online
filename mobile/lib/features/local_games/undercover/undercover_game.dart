import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../party/party_widgets.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

enum UcPhase { reveal, describe, vote, out, result, done }

/// Undercover: everyone gets the same secret word except one player, who gets a similar
/// one (and doesn't know it). Each round everyone gives a clue, then the group votes
/// someone out. Catch the undercover: +1 for everyone else. Undercover survives to the
/// final two: +3 for them.
class UndercoverLogic extends LocalGameLogic {
  static const pairs = [
    ('Coffee', 'Tea'), ('Cricket', 'Football'), ('Samosa', 'Kachori'), ('Pizza', 'Burger'), ('Cat', 'Dog'), ('Train', 'Bus'), //
    ('Mango', 'Banana'), ('Doctor', 'Nurse'), ('Instagram', 'Snapchat'), ('Netflix', 'YouTube'), ('Beach', 'Swimming Pool'), ('Lion', 'Tiger'), //
    ('Diwali', 'Holi'), ('Biryani', 'Pulao'), ('Guitar', 'Violin'), ('Teacher', 'Principal'), ('Rain', 'Snow'), ('Shirt', 'T-shirt'), //
    ('Pen', 'Pencil'), ('Moon', 'Sun'), ('Hotel', 'Hostel'), ('Phone', 'Tablet'), ('Chess', 'Ludo'), ('Ice cream', 'Kulfi'), //
    ('Bike', 'Scooter'), ('Doctor Strange', 'Iron Man'), ('Shah Rukh Khan', 'Salman Khan'), ('Exam', 'Quiz'), ('Wedding', 'Birthday party'), ('Mountain', 'Hill'), //
    ('Chai', 'Coffee'), ('Laptop', 'Computer'), ('Rose', 'Sunflower'), ('Airport', 'Railway station'), ('Gold', 'Silver'), ('Paneer', 'Tofu'), //
    ('Whatsapp', 'Telegram'), ('Library', 'Bookshop'), ('Elephant', 'Rhino'), ('Pani puri', 'Bhel puri'),
  ];

  final int players;
  final Random _rng;
  late int pair;
  late int undercover;
  late bool swapped; // which word of the pair the town gets
  UcPhase phase = UcPhase.reveal;
  final Set<int> seen = {};
  late final Set<int> alive = {for (var i = 0; i < players; i++) i};
  late final List<int?> votes = List.filled(players, null);
  int round = 1;
  int lastOut = -1; // -1 after a tie
  bool undercoverWins = false;

  UndercoverLogic({this.players = 3, Random? random}) : _rng = random ?? Random() {
    pair = _rng.nextInt(pairs.length);
    undercover = _rng.nextInt(players);
    swapped = _rng.nextBool();
  }

  String get townWord => swapped ? pairs[pair].$2 : pairs[pair].$1;
  String get undercoverWord => swapped ? pairs[pair].$1 : pairs[pair].$2;
  String wordFor(int p) => p == undercover ? undercoverWord : townWord;
  int get revealTurn => [for (var i = 0; i < players; i++) if (!seen.contains(i)) i].firstOrNull ?? 0;
  int get votesIn => [for (final p in alive) if (votes[p] != null) p].length;

  @override
  bool get finished => phase == UcPhase.done;
  @override
  List<int> get scores => [for (var i = 0; i < players; i++) undercoverWins ? (i == undercover ? 3 : 0) : (i == undercover ? 0 : 1)];
  @override
  void update(int elapsedMs) {}

  void seenCard(int p) {
    if (forward('seen', [p])) return;
    if (phase != UcPhase.reveal || p < 0 || p >= players) return;
    seen.add(p);
    if (seen.length == players) phase = UcPhase.describe;
    notifyListeners();
  }

  void startVote() {
    if (forward('startVote', const [])) return;
    if (phase != UcPhase.describe) return;
    votes.fillRange(0, players, null);
    phase = UcPhase.vote;
    notifyListeners();
  }

  void accuse(int target) {
    if (forward('accuse', [target])) return;
    if (phase != UcPhase.vote || !alive.contains(target)) return;
    _out(target);
  }

  void vote(int voter, int target) {
    if (forward('vote', [voter, target])) return;
    if (phase != UcPhase.vote || voter == target || !alive.contains(voter) || !alive.contains(target)) return;
    votes[voter] = target;
    if (votesIn == alive.length) {
      _out(voteWinner([for (final p in alive) votes[p]]));
    } else {
      notifyListeners();
    }
  }

  void _out(int target) {
    lastOut = target;
    if (target >= 0) alive.remove(target);
    if (target == undercover) {
      undercoverWins = false;
      phase = UcPhase.result;
    } else if (alive.length <= 2) {
      undercoverWins = true;
      phase = UcPhase.result;
    } else {
      phase = UcPhase.out;
    }
    notifyListeners();
  }

  void nextRound() {
    if (forward('next', const [])) return;
    if (phase != UcPhase.out) return;
    round++;
    phase = UcPhase.describe;
    notifyListeners();
  }

  void finish() {
    if (forward('finish', const [])) return;
    if (phase != UcPhase.result) return;
    phase = UcPhase.done;
    notifyListeners();
  }
}

final undercoverInfo = LocalGameInfo(
  id: 'undercover',
  title: 'Undercover',
  emoji: '🎭',
  color: const Color(0xFF6C5CE7),
  tagline: 'Same word for all… except one.',
  rules: const [
    'Everyone secretly gets a word. One player (the undercover) gets a slightly different word, and nobody knows who.',
    'Each round, everyone says ONE word or short clue about their word. Not too obvious!',
    'Then vote someone out. Catch the undercover: +1 each. Undercover reaches the final two: +3.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 3,
  maxPlayers: 6,
  online: RelaySpec<UndercoverLogic>(
    create: (n) => UndercoverLogic(players: n),
    save: (g) => {
      'pair': g.pair, 'uc': g.undercover, 'swapped': g.swapped, 'phase': g.phase.index, 'seen': g.seen.toList(), //
      'alive': g.alive.toList(), 'votes': g.votes, 'round': g.round, 'out': g.lastOut, 'ucWins': g.undercoverWins,
    },
    load: (g, s, me) {
      g.pair = asInt(s['pair']);
      g.undercover = asInt(s['uc']);
      g.swapped = s['swapped'] == true;
      g.phase = UcPhase.values[asInt(s['phase'])];
      g.seen
        ..clear()
        ..addAll(ints(s['seen']));
      g.alive
        ..clear()
        ..addAll(ints(s['alive']));
      g.votes.setAll(0, nInts(s['votes']));
      g.round = asInt(s['round']);
      g.lastOut = asInt(s['out']);
      g.undercoverWins = s['ucWins'] == true;
    },
    apply: (g, from, name, a) {
      switch (name) {
        case 'seen' when asInt(a[0]) == from:
          g.seenCard(from);
        case 'startVote':
          g.startVote();
        case 'vote' when asInt(a[0]) == from:
          g.vote(from, asInt(a[1]));
        case 'next':
          g.nextRound();
        case 'finish':
          g.finish();
      }
    },
    view: (context, g, players, me) => _UcView(players: players, g: g, me: me),
  ),
  play: (players, onFinished) => TickingPlay<UndercoverLogic>(
    create: () => UndercoverLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _UcView(players: players, g: g),
  ),
);

class _UcView extends StatefulWidget {
  final List<GpPlayer> players;
  final UndercoverLogic g;
  final int? me;
  const _UcView({required this.players, required this.g, this.me});
  @override
  State<_UcView> createState() => _UcViewState();
}

class _UcViewState extends State<_UcView> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.g, players = widget.players, me = widget.me;
    final out = {for (var i = 0; i < players.length; i++) if (!g.alive.contains(i)) i};
    Widget secret(int p) => PromptCard(header: 'YOUR SECRET WORD', text: g.wordFor(p), emoji: '🤫', footer: 'Someone has a slightly different word. It might be you!');

    switch (g.phase) {
      case UcPhase.reveal:
        if (me != null) {
          final ready = g.seen.contains(me);
          return PartyFrame(
            title: 'YOUR WORD',
            subtitle: ready ? 'Waiting for the others (${g.seen.length}/${players.length})' : 'Remember it, then tap READY',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: Center(child: SingleChildScrollView(child: secret(me)))),
              GpButton(ready ? 'READY ✓' : "I'M READY", onPressed: ready ? null : () => g.seenCard(me)),
            ]),
          );
        }
        final p = g.revealTurn;
        return PartyFrame(
          title: 'SECRET WORDS',
          subtitle: '${g.seen.length} of ${players.length} have looked',
          child: PassAndReveal(
            player: players[p],
            revealed: _shown,
            onReveal: () => setState(() => _shown = true),
            onDone: () {
              setState(() => _shown = false);
              g.seenCard(p);
            },
            secret: secret(p),
          ),
        );
      case UcPhase.describe:
        return PartyFrame(
          title: 'ROUND ${g.round}: GIVE A CLUE',
          subtitle: 'In order, each player says ONE word about their secret word.',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: PlayerPicker(players: players, disabled: out, notes: {for (final i in out) i: 'OUT'}),
                ),
              ),
            ),
            if (me != null) Text('Your word: ${g.wordFor(me)}', textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            GpButton('EVERYONE GAVE A CLUE · VOTE', icon: Icons.how_to_vote_rounded, onPressed: g.startVote),
          ]),
        );
      case UcPhase.vote:
        if (me != null) {
          final canVote = g.alive.contains(me);
          return PartyFrame(
            title: 'WHO IS UNDERCOVER?',
            subtitle: canVote ? 'Your vote · ${g.votesIn}/${g.alive.length} voted' : "You're out: watch the others vote",
            child: Center(
              child: SingleChildScrollView(
                child: PlayerPicker(players: players, disabled: {...out, me}, highlight: g.votes[me], onPick: canVote ? (i) => g.vote(me, i) : null),
              ),
            ),
          );
        }
        return PartyFrame(
          title: 'WHO IS UNDERCOVER?',
          subtitle: 'Agree together, then tap the player to vote out.',
          child: Center(child: SingleChildScrollView(child: PlayerPicker(players: players, disabled: out, onPick: g.accuse))),
        );
      case UcPhase.out:
        return PartyFrame(
          title: 'VOTED OUT',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: g.lastOut < 0
                      ? const PromptCard(header: 'TIE VOTE', text: 'Nobody is out', emoji: '🤝', footer: 'Give another clue and vote again.')
                      : PromptCard(header: '${players[g.lastOut].name.toUpperCase()} IS OUT', text: 'Not undercover!', emoji: '😇', footer: 'The undercover is still among you…', color: players[g.lastOut].color),
                ),
              ),
            ),
            GpButton('NEXT ROUND', icon: Icons.arrow_forward_rounded, onPressed: g.nextRound),
          ]),
        );
      case UcPhase.result:
      case UcPhase.done:
        final uc = players[g.undercover];
        return PartyFrame(
          title: g.undercoverWins ? 'UNDERCOVER WINS' : 'TOWN WINS',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(children: [
                    Text(g.undercoverWins ? '😈 ${uc.name} survived to the end!' : '✅ ${uc.name} was caught!',
                        textAlign: TextAlign.center, style: TextStyle(color: g.undercoverWins ? GpColors.no : GpColors.yes, fontWeight: FontWeight.w900, fontSize: 22)),
                    const SizedBox(height: 14),
                    PromptCard(header: 'UNDERCOVER: ${uc.name.toUpperCase()}', text: '${g.undercoverWord} vs ${g.townWord}', emoji: '🎭', footer: 'Undercover word vs everyone else', color: uc.color),
                  ]),
                ),
              ),
            ),
            GpButton('SEE SCORES', icon: Icons.emoji_events_rounded, onPressed: g.finish),
          ]),
        );
    }
  }
}
