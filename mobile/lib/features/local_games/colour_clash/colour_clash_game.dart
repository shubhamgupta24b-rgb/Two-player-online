import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_info.dart';
import '../shell/game_hud.dart';
import '../party/party_widgets.dart' show HoldToReveal;
import '../shell/ticking_play.dart';
import 'colour_clash_logic.dart';

export 'colour_clash_logic.dart';

const clashColors = {
  ClashColor.red: Color(0xFFE53935),
  ClashColor.yellow: Color(0xFFF9C80E),
  ClashColor.green: Color(0xFF2EAA4F),
  ClashColor.blue: Color(0xFF1E7BE0),
  ClashColor.wild: Color(0xFF1C1C24),
};

/// A suit per colour, printed on the cards, so colour is never the only way to tell them apart.
const clashSymbols = {
  ClashColor.red: '♥',
  ClashColor.yellow: '★',
  ClashColor.green: '♣',
  ClashColor.blue: '♦',
  ClashColor.wild: '',
};

final colourClashInfo = LocalGameInfo(
  id: 'colour_clash',
  title: 'Colour Clash',
  emoji: '🃏',
  color: const Color(0xFFE53935),
  tagline: 'Match colours, dodge +4s, call ONE!',
  rules: const [
    'Everyone gets 7 cards. Play a card that matches the top card by colour, number or symbol, or play a Wild.',
    "Can't play? Draw one. Skip ⊘, Reverse ⇄, +2 and Wild +4 work like the classic game.",
    'Down to two cards? Tap ONE! before you play, or pick up 2. First to empty their hand wins!',
    'The phone is passed between turns and your cards stay hidden until you tap SHOW MY CARDS.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  maxPlayers: 6,
  bot: botFor<ColourClashLogic>((g, b, now) {
    // One person against the computer never passes the phone; with several people, only
    // the bots' own turns skip the pass-the-phone screen.
    if (g.phase == ClashPhase.handoff) {
      if (b.loneHuman || g.turn == b.seat) g.reveal();
      return;
    }
    if (g.finished || g.turn != b.seat) return;
    if (!b.thinkFirst((g.discard.length, g.phase, g.drewThisTurn, g.hand.length), now, 700, 1500)) return;
    final hand = g.hand;
    ClashColor favourite() {
      final counts = <ClashColor, int>{};
      for (final c in hand.where((c) => !c.isWild)) {
        counts[c.color] = (counts[c.color] ?? 0) + 1;
      }
      return counts.isEmpty ? b.pick(const [ClashColor.red, ClashColor.yellow, ClashColor.green, ClashColor.blue]) : (counts.entries.toList()..sort((a, c) => c.value - a.value)).first.key;
    }

    if (g.phase == ClashPhase.chooseColor) {
      g.chooseColor(favourite());
      return;
    }
    final options = g.playable.toList();
    if (options.isEmpty) {
      if (!g.drewThisTurn) g.draw();
      return;
    }
    // Remember to call ONE! (usually).
    if (hand.length == 2 && !g.calledOne && b.chance(0.9)) g.callOne();
    final nextHasFew = g.hands[g.nextPlayer()].length <= 2;
    int rank(ClashCard c) => switch (c.kind) {
          ClashKind.wildFour => nextHasFew ? 50 : 1, // save the big ones unless someone is close to winning
          ClashKind.wild => 2,
          ClashKind.drawTwo => nextHasFew ? 40 : 20,
          ClashKind.skip || ClashKind.reverse => 15,
          ClashKind.number => 10 + (c.color == favourite() ? 3 : 0),
        };
    options.sort((a, c) => rank(c) - rank(a));
    final card = options.first;
    g.play(card.id, chosen: card.isWild ? favourite() : null);
  }),
  online: RelaySpec<ColourClashLogic>(
    create: (n) => ColourClashLogic(players: n),
    save: (g) => {
      'hands': [for (final h in g.hands) [for (final c in h) c.id]],
      'pile': g.drawPile.length,
      'top': g.top.id,
      'discard': g.discard.length,
      'color': g.color.index,
      'turn': g.turn,
      'dir': g.direction,
      'phase': g.phase.index,
      'drew': g.drewThisTurn,
      'drawn': g.drawnCard?.id,
      'one': g.calledOne,
      'winner': g.winner,
      'msg': g.message,
    },
    load: (g, s, me) {
      final byId = {for (final c in ColourClashLogic.fullDeck()) c.id: c};
      final hands = (s['hands'] as List).map(ints).toList();
      for (var i = 0; i < g.hands.length; i++) {
        g.hands[i]
          ..clear()
          ..addAll(hands[i].map((id) => byId[id]!));
      }
      // Guests only need to know how many cards are in the piles.
      g.drawPile
        ..clear()
        ..addAll(List.filled(asInt(s['pile']), byId[0]!));
      g.discard
        ..clear()
        ..addAll(List.filled(asInt(s['discard']) - 1, byId[0]!))
        ..add(byId[asInt(s['top'])]!);
      g.color = ClashColor.values[asInt(s['color'])];
      g.turn = asInt(s['turn']);
      g.direction = asInt(s['dir']);
      g.phase = ClashPhase.values[asInt(s['phase'])];
      g.drewThisTurn = s['drew'] == true;
      g.drawnCard = s['drawn'] == null ? null : byId[asInt(s['drawn'])];
      g.calledOne = s['one'] == true;
      g.winner = nInt(s['winner']);
      g.message = s['msg'] as String;
    },
    apply: (g, from, name, a) {
      if (from != g.turn) return;
      switch (name) {
        case 'play':
          g.play(asInt(a[0]), chosen: a[1] == null ? null : ClashColor.values[asInt(a[1])]);
        case 'color':
          g.chooseColor(ClashColor.values[asInt(a[0])]);
        case 'draw':
          g.draw();
        case 'pass':
          g.pass();
        case 'one':
          g.callOne();
      }
    },
    // No passing the phone online: everyone holds their own hand.
    hostAuto: (g) {
      if (g.phase == ClashPhase.handoff) g.reveal();
    },
    view: (context, g, players, me) => _ClashTable(players: players, g: g, me: me),
  ),
  play: (players, onFinished) => TickingPlay<ColourClashLogic>(
    create: () => ColourClashLogic(players: players.length),
    onFinished: onFinished,
    // One person against the computer only ever sees their own hand; with several people the
    // phone is passed and the bots' hands stay face down.
    builder: (context, g) => _ClashTable(
      players: players,
      g: g,
      me: BotScope.humanSeat(context),
      botSeats: {for (var i = 0; i < players.length; i++) if (BotScope.isBot(context, i)) i},
    ),
  ),
);

/// One card, face up or face down, at any size (designed at 70x105).
class ClashCardView extends StatelessWidget {
  final ClashCard? card; // null = face down
  final double width;
  final bool highlight;
  final bool dim;
  const ClashCardView({super.key, required this.card, this.width = 70, this.highlight = false, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final c = card;
    return SizedBox(
      width: width,
      height: width * 1.5,
      child: FittedBox(
        child: Opacity(
          opacity: dim ? 0.55 : 1,
          child: Container(
            width: 70,
            height: 105,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                if (highlight) const BoxShadow(color: Color(0xFFFFE066), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: c == null ? _back() : _face(c),
          ),
        ),
      ),
    );
  }

  Widget _back() => Container(
        decoration: BoxDecoration(color: const Color(0xFF1C1C24), borderRadius: BorderRadius.circular(6)),
        child: Center(
          child: Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 52,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(20)),
              child: const Text('CLASH', style: TextStyle(color: Color(0xFFF9C80E), fontWeight: FontWeight.w900, fontSize: 11, fontStyle: FontStyle.italic)),
            ),
          ),
        ),
      );

  Widget _face(ClashCard c) {
    final bg = clashColors[c.color]!;
    final big = c.kind == ClashKind.number ? 30.0 : (c.label.length > 1 ? 24.0 : 28.0);
    final corner = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(c.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, height: 1)),
      if (!c.isWild) Text(clashSymbols[c.color]!, style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.1)),
    ]);
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Stack(children: [
        Center(
          child: Transform.rotate(
            angle: -0.5,
            child: Container(
              width: 48,
              height: 74,
              decoration: BoxDecoration(color: c.isWild ? null : Colors.white, borderRadius: const BorderRadius.all(Radius.elliptical(48, 74))),
              child: c.isWild ? const CustomPaint(painter: _WildPainter()) : null,
            ),
          ),
        ),
        Center(
          child: Text(c.label,
              style: TextStyle(
                color: c.isWild ? Colors.white : bg,
                fontWeight: FontWeight.w900,
                fontSize: big,
                fontStyle: FontStyle.italic,
                shadows: const [Shadow(color: Colors.black54, offset: Offset(1.5, 1.5))],
              )),
        ),
        Positioned(left: 3, top: 3, child: corner),
        Positioned(right: 3, bottom: 3, child: RotatedBox(quarterTurns: 2, child: corner)),
      ]),
    );
  }
}

/// Four-colour oval for wild cards.
class _WildPainter extends CustomPainter {
  const _WildPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipPath(Path()..addOval(rect));
    final c = rect.center;
    final colors = [ClashColor.red, ClashColor.blue, ClashColor.yellow, ClashColor.green];
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(Rect.fromCenter(center: c, width: size.width * 2, height: size.height * 2), -pi / 2 + i * pi / 2, pi / 2, true, Paint()..color = clashColors[colors[i]]!);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ClashTable extends StatelessWidget {
  final List<GpPlayer> players;
  final ColourClashLogic g;
  final int? me; // online: whose phone this is (only their hand is shown)
  final Set<int> botSeats; // computer players sharing a pass-the-phone game
  const _ClashTable({required this.players, required this.g, this.me, this.botSeats = const {}});

  @override
  Widget build(BuildContext context) {
    final online = me != null;
    final holder = me ?? g.turn; // whose hand is on screen
    // People passing the phone with bots: nobody's cards show while a bot plays.
    final botTurn = !online && botSeats.contains(g.turn);
    final myTurn = holder == g.turn;
    final player = players[holder];
    final hand = g.hands[holder];
    return Stack(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(children: [
          GameHud(players: players, turn: g.turn, extra: (i) => '🂠 ${g.hands[i].length}${g.hands[i].length == 1 ? ' ONE!' : ''}'),
          const SizedBox(height: 6),
          Expanded(child: _Centre(g: g, canAct: myTurn, waitingFor: myTurn ? null : players[g.turn].name)),
          if (botTurn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('🤖 ${players[g.turn].name} is playing…', style: context.tk.styles.title),
            )
          else if (online || g.phase != ClashPhase.handoff) ...[
            Row(children: [
              Expanded(
                child: Text(online ? 'YOUR HAND · ${hand.length} cards' : '${player.whose} HAND · ${hand.length} cards',
                    style: context.tk.styles.label.copyWith(color: Color.lerp(player.color, Colors.white, 0.4))),
              ),
              if (myTurn && hand.length == 2 && g.phase == ClashPhase.play)
                _SmallButton(
                  label: g.calledOne ? 'ONE! ✓' : 'ONE!',
                  color: g.calledOne ? GpColors.yes : const Color(0xFFFF8A3D),
                  onTap: g.calledOne
                      ? null
                      : () {
                          haptic(HapticWeight.medium);
                          GameAudio.sfx('coin');
                          g.callOne();
                        },
                ),
              if (myTurn && g.drewThisTurn && g.phase == ClashPhase.play) ...[
                const SizedBox(width: 6),
                _SmallButton(label: 'PASS', color: Colors.white24, onTap: g.pass),
              ],
            ]),
            const SizedBox(height: 6),
            _Hand(g: g, hand: hand, active: myTurn && g.phase == ClashPhase.play),
          ],
        ]),
      ),
      if (g.phase == ClashPhase.chooseColor && myTurn) _ColorPicker(g: g),
      if (!online && g.phase == ClashPhase.handoff) _Handoff(player: player, g: g),
    ]);
  }
}

class _Centre extends StatelessWidget {
  final ColourClashLogic g;
  final bool canAct;
  final String? waitingFor;
  const _Centre({required this.g, this.canAct = true, this.waitingFor});
  @override
  Widget build(BuildContext context) {
    final col = clashColors[g.color]!;
    final canDraw = canAct && g.phase == ClashPhase.play && !g.drewThisTurn;
    return LayoutBuilder(builder: (context, c) {
      // Card width from the space inside the table (border, labels and message take ~90px).
      final w = min(c.maxWidth * 0.28, (c.maxHeight - 90) * 0.62 / 1.5).clamp(36.0, 130.0);
      // A felt card table under the piles.
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: const RadialGradient(colors: [Color(0xFF1F8A4C), Color(0xFF0F5C30)], radius: 0.9),
          borderRadius: BorderRadius.circular(c.maxHeight * 0.3),
          border: Border.all(color: const Color(0xFF8B5A2B), width: 5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Semantics(
            button: true,
            label: 'Draw a card',
            child: GestureDetector(
              onTap: canDraw
                  ? () {
                      haptic(HapticWeight.selection);
                      g.draw();
                    }
                  : null,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ClashCardView(card: null, width: w * 0.85, highlight: canDraw && g.playable.isEmpty),
                const SizedBox(height: 4),
                Text('DRAW · ${g.drawPile.length}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11)),
              ]),
            ),
          ),
          SizedBox(width: w * 0.35),
          Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: col.withValues(alpha: 0.35), boxShadow: [BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 18)]),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(g.top.id),
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: ClashCardView(card: g.top, width: w),
              ),
            ),
            const SizedBox(height: 4),
            Text('COLOUR: ${g.color.name.toUpperCase()}', style: TextStyle(color: col == clashColors[ClashColor.wild] ? Colors.white : col, fontWeight: FontWeight.w900, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(g.direction == 1 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded, color: Colors.white54, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text([if (waitingFor != null) "$waitingFor's turn", g.message.isEmpty && waitingFor == null ? 'Match the colour, number or symbol' : g.message].where((t) => t.isNotEmpty).join(' · '),
                textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
      ]),
      );
    });
  }
}

class _Hand extends StatelessWidget {
  final ColourClashLogic g;
  final List<ClashCard> hand;
  final bool active;
  const _Hand({required this.g, required this.hand, required this.active});
  @override
  Widget build(BuildContext context) {
    final playable = active ? g.playable.map((c) => c.id).toSet() : const <int>{};
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 12),
        itemCount: hand.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final card = hand[i];
          final ok = active && playable.contains(card.id);
          return Semantics(
            button: ok,
            label: '${card.color.name} ${card.label}',
            child: GestureDetector(
              onTap: ok
                  ? () {
                      haptic(HapticWeight.light);
                      GameAudio.sfx('tap');
                      g.play(card.id);
                    }
                  : null,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                offset: Offset(0, ok ? -0.1 : 0),
                child: ClashCardView(card: card, width: 62, highlight: ok, dim: active && !ok),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _SmallButton({required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => AppButton(label, compact: true, color: color == Colors.white24 ? null : color, variant: color == Colors.white24 ? ButtonVariant.secondary : ButtonVariant.primary, onPressed: onTap);
}

class _ColorPicker extends StatelessWidget {
  final ColourClashLogic g;
  const _ColorPicker({required this.g});
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: context.tk.card, borderRadius: Radii.rXl, boxShadow: context.tk.shadowLg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('PICK A COLOUR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final c in [ClashColor.red, ClashColor.yellow, ClashColor.green, ClashColor.blue])
                    Semantics(
                      button: true,
                      label: c.name,
                      child: GestureDetector(
                        onTap: () {
                          haptic(HapticWeight.selection);
                          g.chooseColor(c);
                        },
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: clashColors[c], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                            child: Text(clashSymbols[c]!, style: const TextStyle(color: Colors.white, fontSize: 28)),
                          ),
                          const SizedBox(height: 4),
                          Text(c.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        ]),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        ),
      );
}

/// Hides the hands while the phone changes hands (the table stays visible above it).
class _Handoff extends StatelessWidget {
  final GpPlayer player;
  final ColourClashLogic g;
  const _Handoff({required this.player, required this.g});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.xl, Space.xl),
        decoration: BoxDecoration(
          color: t.bgBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: player.color, width: 4)),
          boxShadow: t.shadowLg,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PlayerAvatar(name: player.name, color: player.color, size: 44),
            const SizedBox(width: Space.m),
            Flexible(child: Text('📱 Pass to ${player.name}', style: t.styles.title.copyWith(fontSize: 20))),
          ]),
          const SizedBox(height: Space.xs),
          Text('Everyone else, no peeking at the cards!', textAlign: TextAlign.center, style: t.styles.body.copyWith(color: t.onBgMuted)),
          const SizedBox(height: Space.m),
          HoldToReveal(label: 'HOLD TO SEE MY CARDS', color: player.color, onRevealed: g.reveal),
        ]),
      ),
    );
  }
}