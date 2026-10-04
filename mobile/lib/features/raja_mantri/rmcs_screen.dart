import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/audio/game_audio.dart';
import '../../core/ui/components.dart';
import '../guess_person/models/gp_player.dart';
import '../guess_person/widgets/gp_theme.dart';
import 'rmcs_game.dart';
import 'rmcs_role.dart';
import 'widgets/role_card.dart';
import 'widgets/rmcs_widgets.dart';

/// Setup: four names, how many rounds, the rules at a glance, then play on one device.
class RmcsMenuScreen extends StatefulWidget {
  const RmcsMenuScreen({super.key});
  @override
  State<RmcsMenuScreen> createState() => _RmcsMenuScreenState();
}

class _RmcsMenuScreenState extends State<RmcsMenuScreen> {
  static const roundChoices = [5, 10, 15, 20, 30];
  final _names = [for (var i = 0; i < 4; i++) TextEditingController()];
  int _rounds = 20;

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    final players = [
      for (var i = 0; i < 4; i++)
        GpPlayer(name: _names[i].text.trim().isEmpty ? 'Player ${i + 1}' : _names[i].text.trim(), color: gpPlayerColors[i]),
    ];
    Navigator.push(context, MaterialPageRoute(builder: (_) => RmcsGameScreen(game: RmcsGame(players: players, totalRounds: _rounds))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RmcsBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            Row(children: [
              AppIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.maybePop(context)),
              const Spacer(),
              AppIconButton(icon: Icons.tune_rounded, tooltip: 'Settings', onPressed: () => showSettingsSheet(context)),
            ]),
            const Text('RAJA MANTRI\nCHOR SIPAHI',
                textAlign: TextAlign.center,
                style: TextStyle(color: RmcsColors.gold, fontSize: 32, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(color: Color(0xFF8A1C3A), offset: Offset(0, 4))])),
            const SizedBox(height: 6),
            Text('4 PLAYERS · $_rounds ROUNDS · ONE PHONE', textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final r in RmcsRole.values)
                  Flexible(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: RoleCard(role: r, faceUp: true))),
              ]),
            ),
            const SizedBox(height: 16),
            _rules(),
            const SizedBox(height: 16),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _names[i],
                  maxLength: 12,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Player ${i + 1}',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: Padding(padding: const EdgeInsets.all(8), child: PlayerAvatar(name: 'Player ${i + 1}', color: gpPlayerColors[i], seat: i, size: 28)),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _roundPicker(),
            const SizedBox(height: 16),
            GpButton('DEAL THE CARDS', icon: Icons.style_rounded, onPressed: _start),
          ]),
        ),
      ),
    );
  }

  Widget _roundPicker() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: RmcsColors.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: RmcsColors.gold.withValues(alpha: 0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ROUNDS', style: TextStyle(color: RmcsColors.gold, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in roundChoices)
              AppChip(label: '$n', selected: n == _rounds, semanticLabel: '$n rounds', onTap: () => setState(() => _rounds = n)),
          ]),
          const SizedBox(height: 8),
          Text(_rounds <= 5 ? 'Quick game · about 5 minutes' : _rounds >= 30 ? 'Marathon · about 30 minutes' : 'About $_rounds minutes', style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );

  Widget _rules() {
    Widget line(String emoji, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: RmcsColors.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: RmcsColors.gold.withValues(alpha: 0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('HOW TO PLAY', style: TextStyle(color: RmcsColors.gold, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        line('🃏', 'Each round the 4 cards are shuffled and dealt. Pass the phone so everyone secretly sees their own card.'),
        line('👑', 'The Raja is revealed (+1000 every round), then the Mantri steps forward.'),
        line('🧠', 'The Mantri has 10 seconds to point at the Chor. Right: Mantri +500. Wrong or too slow: Chor +500.'),
        line('👮', 'The Sipahi always gets +300. Highest total after $_rounds rounds wins!'),
      ]),
    );
  }
}

/// The table: four seats, a headline for what's happening, and the action button.
class RmcsGameScreen extends StatefulWidget {
  final RmcsGame game;
  const RmcsGameScreen({super.key, required this.game});
  @override
  State<RmcsGameScreen> createState() => _RmcsGameScreenState();
}

class _RmcsGameScreenState extends State<RmcsGameScreen> {
  RmcsGame get g => widget.game;
  Timer? _clock;
  Timer? _mantriTimer;
  bool _mantriShown = false;
  RmcsPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    g.addListener(_onChange);
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (g.phase == RmcsPhase.guessing) {
        g.tick();
        if (mounted) setState(() {});
      }
    });
  }

  void _onChange() {
    if (g.phase != _lastPhase) {
      _lastPhase = g.phase;
      if (g.phase == RmcsPhase.rajaReveal) {
        // Raja first, then the Mantri a moment later.
        _mantriShown = false;
        _mantriTimer?.cancel();
        _mantriTimer = Timer(const Duration(milliseconds: 1100), () {
          if (mounted) setState(() => _mantriShown = true);
        });
        haptic(HapticWeight.medium);
      }
      if (g.phase == RmcsPhase.reveal) {
        haptic(HapticWeight.heavy);
        GameAudio.sfx(g.caught ? 'coin' : 'lose');
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    g.removeListener(_onChange);
    _clock?.cancel();
    _mantriTimer?.cancel();
    super.dispose();
  }

  Future<void> _leave() async {
    final ok = await confirmAction(context, title: 'Leave the game?', message: 'Scores for this game will be lost.', confirm: 'LEAVE', cancel: 'STAY', emoji: '🚪');
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: g.phase == RmcsPhase.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: RmcsBackground(
          child: SafeArea(
            child: g.phase == RmcsPhase.finished ? _finished() : _table(),
          ),
        ),
      ),
    );
  }

  Widget _table() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      child: Column(children: [
        Row(children: [
          AppIconButton(icon: Icons.close_rounded, tooltip: 'Leave game', onPressed: _leave),
          Expanded(
            child: Text('ROUND ${g.round} / ${g.totalRounds}', textAlign: TextAlign.center, style: const TextStyle(color: RmcsColors.gold, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
          ),
          AppIconButton(icon: Icons.tune_rounded, tooltip: 'Settings', onPressed: () => showSettingsSheet(context)),
        ]),
        const SizedBox(height: 4),
        _headline(),
        const SizedBox(height: 8),
        Expanded(
          child: g.phase == RmcsPhase.dealing
              ? ShuffleDeal(key: ValueKey('deal${g.round}'), onDone: g.dealt)
              : SeatGrid(seats: [for (var i = 0; i < 4; i++) _seat(i)]),
        ),
        const SizedBox(height: 8),
        _actions(),
      ]),
    );
  }

  String _n(int i) => g.players[i].name;

  Widget _headline() {
    switch (g.phase) {
      case RmcsPhase.dealing:
        return const RmcsHeadline(title: '🃏 Shuffling and dealing…', subtitle: 'Four cards: Raja, Mantri, Sipahi and Chor.');
      case RmcsPhase.peek:
        final who = _n(g.peekIndex);
        return RmcsHeadline(
          title: g.peekShown ? '🤫 Remember your card, $who!' : '📱 Pass the phone to $who',
          subtitle: g.peekShown ? 'Then hide it and pass the phone on.' : 'Everyone else, look away! Tap your card to see it.',
        );
      case RmcsPhase.rajaReveal:
        return RmcsHeadline(
          title: '👑 ${_n(g.raja)} is the RAJA!',
          subtitle: _mantriShown ? '🧠 ${_n(g.mantri)} is the Mantri. Find the Chor: ${_n(g.suspects[0])} or ${_n(g.suspects[1])}?' : 'Bow to the king… +1000 points!',
        );
      case RmcsPhase.guessing:
        return RmcsHeadline(
          title: '🧠 ${_n(g.mantri)}, who is the CHOR?',
          subtitle: 'Tap ${_n(g.suspects[0])} or ${_n(g.suspects[1])}.',
          trailing: CountdownRing(msLeft: g.guessMsLeft, totalMs: g.guessMs, size: 52),
        );
      case RmcsPhase.reveal:
        return ResultBanner(caught: g.caught, timedOut: g.timedOut);
      case RmcsPhase.finished:
        return const SizedBox.shrink();
    }
  }

  Widget _seat(int i) {
    final role = g.roles[i];
    final player = g.players[i];
    var faceUp = false;
    String? badge;
    var badgeColor = RmcsColors.gold;
    var highlight = false;
    VoidCallback? onTap;
    var dim = false;
    var flip = const Duration(milliseconds: 650);

    switch (g.phase) {
      case RmcsPhase.dealing:
        break;
      case RmcsPhase.peek:
        final mine = i == g.peekIndex;
        faceUp = mine && g.peekShown;
        highlight = mine;
        dim = !mine;
        if (mine && !g.peekShown) {
          badge = 'TAP TO REVEAL';
          onTap = g.showPeek;
        }
      case RmcsPhase.rajaReveal:
        faceUp = role == RmcsRole.raja || (role == RmcsRole.mantri && _mantriShown);
        highlight = faceUp;
      case RmcsPhase.guessing:
        faceUp = role == RmcsRole.raja || role == RmcsRole.mantri;
        if (!faceUp) {
          highlight = true;
          badge = 'TAP TO ACCUSE';
          badgeColor = GpColors.no;
          onTap = () {
            haptic(HapticWeight.selection);
            g.accuse(i);
          };
        } else {
          dim = role == RmcsRole.raja;
        }
      case RmcsPhase.reveal:
        faceUp = true;
        // The accused card turns first, the other suspect a beat later.
        if (role == RmcsRole.sipahi || role == RmcsRole.chor) flip = Duration(milliseconds: i == g.accused ? 600 : 1100);
        if (i == g.accused) {
          badge = '👉 ACCUSED';
          badgeColor = Colors.white;
        } else if (role == RmcsRole.chor) {
          badge = 'ESCAPED!';
          badgeColor = GpColors.no;
        }
        if (role == RmcsRole.chor) highlight = true;
        if (i == g.accused && g.caught) badge = '🚨 CAUGHT!';
      case RmcsPhase.finished:
        faceUp = true;
    }
    return RmcsSeat(
      name: player.name,
      color: player.color,
      role: role,
      faceUp: faceUp,
      score: g.scores[i],
      delta: g.phase == RmcsPhase.reveal ? g.lastPoints[i] : null,
      badge: badge,
      badgeColor: badgeColor,
      highlight: highlight,
      dim: dim,
      flipDuration: flip,
      onTap: onTap,
    );
  }

  Widget _actions() {
    switch (g.phase) {
      case RmcsPhase.dealing:
      case RmcsPhase.guessing:
        return const SizedBox(height: 54);
      case RmcsPhase.peek:
        if (!g.peekShown) return const SizedBox(height: 54);
        final last = g.peekIndex == RmcsGame.playerCount - 1;
        return GpButton(last ? 'HIDE CARD · REVEAL THE RAJA' : 'HIDE CARD · PASS TO ${_n(g.peekIndex + 1).toUpperCase()}', icon: Icons.visibility_off_rounded, onPressed: g.passPeek);
      case RmcsPhase.rajaReveal:
        return GpButton(_mantriShown ? 'MANTRI: FIND THE CHOR (10s)' : '…', icon: Icons.timer_rounded, onPressed: _mantriShown ? g.startGuessing : null);
      case RmcsPhase.reveal:
        return GpButton(g.isLastRound ? 'SEE FINAL RESULTS' : 'NEXT ROUND (${g.round + 1}/${g.totalRounds})', icon: Icons.arrow_forward_rounded, onPressed: g.nextRound);
      case RmcsPhase.finished:
        return const SizedBox.shrink();
    }
  }

  Widget _finished() {
    final order = g.standings;
    final best = g.scores[order.first];
    final winners = [for (final i in order) if (g.scores[i] == best) _n(i)];
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 8),
      const Text('🏆', textAlign: TextAlign.center, style: TextStyle(fontSize: 72)),
      Text(winners.length == 1 ? '${winners.first.toUpperCase()} WINS!' : "IT'S A TIE!",
          textAlign: TextAlign.center, style: const TextStyle(color: RmcsColors.gold, fontSize: 30, fontWeight: FontWeight.w900)),
      Text('after ${g.totalRounds} rounds', textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 18),
      for (var rank = 0; rank < order.length; rank++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: rank == 0 ? RmcsColors.gold.withValues(alpha: 0.2) : RmcsColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: rank == 0 ? RmcsColors.gold : Colors.white12, width: 2),
          ),
          child: Row(children: [
            Text(['🥇', '🥈', '🥉', '4️⃣'][rank], style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            PlayerAvatar(name: _n(order[rank]), color: g.players[order[rank]].color, seat: order[rank], size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text(_n(order[rank]), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
            Text('${g.scores[order[rank]]}', style: const TextStyle(color: RmcsColors.gold, fontWeight: FontWeight.w900, fontSize: 20, fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      const SizedBox(height: 12),
      GpButton('PLAY AGAIN', icon: Icons.replay_rounded, onPressed: g.restart),
      const SizedBox(height: 10),
      GpButton('EXIT', outlined: true, onPressed: () => Navigator.pop(context)),
    ]);
  }
}
