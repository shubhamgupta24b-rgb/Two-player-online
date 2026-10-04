import 'package:flutter/material.dart';
import '../../../core/ui/app_flavor.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../shell/local_game_shell.dart' show PauseButton, GameTheme;

/// Common layout for the party games: a top bar (pause, title, optional timer) and a body.
class PartyFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const PartyFrame({super.key, required this.title, this.subtitle, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.m, 6, Space.m, Space.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GameTopBar(title: title, subtitle: subtitle, trailing: trailing),
          const SizedBox(height: Space.m),
          Expanded(child: child),
        ]),
      );
}

/// The header most games use: pause, a bold title (and a line under it), extras on the right.
class GameTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const GameTopBar({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = GameTheme.colorOf(context);
    final ink = t.flat ? t.text : t.onBg;
    final muted = t.flat ? t.textMuted : t.onBgMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, Space.m, 2),
      decoration: t.flat
          ? flatTile(radius: Radii.xl)
          : BoxDecoration(color: t.glass, borderRadius: Radii.rXl, border: Border.all(color: t.stroke)),
      child: Row(children: [
        const PauseButton(),
        const SizedBox(width: Space.xs),
        Container(width: 4, height: 30, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: Space.s),
        Expanded(
          child: Semantics(
            header: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.styles.title.copyWith(color: ink, fontSize: 17)),
              if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.styles.caption.copyWith(color: muted)),
            ]),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ]),
    );
  }
}

/// "Pass to NAME" -> hold to see -> the secret -> "hide" and pass on. Used for every secret card.
/// Seeing the secret needs a press-and-hold, so a stray tap never shows it to the table.
class PassAndReveal extends StatelessWidget {
  final GpPlayer player;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback? onDone; // null: not yet (e.g. a choice must be made first)
  final Widget secret;
  final String doneLabel;
  const PassAndReveal({super.key, required this.player, required this.revealed, required this.onReveal, required this.onDone, required this.secret, this.doneLabel = 'GOT IT · HIDE & PASS'});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (!revealed) {
      final c = player.color;
      return Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.xl),
              decoration: t.flat
                  ? flatTile(radius: 28)
                  : BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: 0.28), t.glass]),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: c.withValues(alpha: 0.55), width: 2),
                    ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(clipBehavior: Clip.none, children: [
                  PlayerAvatar(name: player.name, color: c, size: 104),
                  const Positioned(right: -12, bottom: -4, child: ExcludeSemantics(child: Text('📲', style: TextStyle(fontSize: 34)))),
                ]),
                const SizedBox(height: Space.l),
                Text('PASS THE PHONE TO', style: (t.flat ? t.cardStyles : t.styles).label),
                const SizedBox(height: Space.xs),
                Semantics(
                  liveRegion: true,
                  child: FittedBox(
                    child: Text(player.name.toUpperCase(),
                        style: (t.flat ? t.cardStyles : t.styles).display.copyWith(color: t.flat ? fillFor(c) : Color.lerp(c, Colors.white, 0.35), fontSize: 32)),
                  ),
                ),
                const SizedBox(height: Space.s),
                Text('Everyone else, look away! 🙈', textAlign: TextAlign.center, style: (t.flat ? t.cardStyles : t.styles).bodyStrong),
                const SizedBox(height: Space.xl),
                HoldToReveal(label: 'HOLD TO SEE YOUR SECRET', color: c, onRevealed: onReveal),
              ]),
            ),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: Center(child: SingleChildScrollView(child: secret))),
      const SizedBox(height: Space.s),
      GpButton(doneLabel, icon: Icons.visibility_off_rounded, onPressed: onDone),
    ]);
  }
}

/// Covers a private screen (a card, a fleet) until the player whose turn it is holds the
/// button: the same hand-off as [PassAndReveal], over a whole game screen.
class PassCover extends StatelessWidget {
  final GpPlayer player;
  final VoidCallback onReveal;
  final String holdLabel;
  final String note;
  const PassCover({super.key, required this.player, required this.onReveal, this.holdLabel = 'HOLD TO SEE YOUR CARDS', this.note = 'Everyone else, look away! 🙈'});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Positioned.fill(
      child: ColoredBox(
        color: t.bgBottom, // fully opaque: nothing of the last player's screen shows through
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Align(alignment: Alignment.centerLeft, child: PauseButton()),
                  Stack(clipBehavior: Clip.none, children: [
                    PlayerAvatar(name: player.name, color: player.color, size: 96),
                    const Positioned(right: -12, bottom: -4, child: ExcludeSemantics(child: Text('📲', style: TextStyle(fontSize: 32)))),
                  ]),
                  const SizedBox(height: Space.l),
                  Text('PASS THE PHONE TO', style: t.styles.label),
                  const SizedBox(height: Space.xs),
                  Semantics(
                    liveRegion: true,
                    child: FittedBox(child: Text(player.name.toUpperCase(), style: t.styles.display.copyWith(color: Color.lerp(player.color, Colors.white, 0.35), fontSize: 32))),
                  ),
                  const SizedBox(height: Space.s),
                  Text(note, textAlign: TextAlign.center, style: t.styles.bodyStrong),
                  const SizedBox(height: Space.xl),
                  HoldToReveal(label: holdLabel, color: player.color, onRevealed: onReveal),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/// A button you hold down: it fills up, and when full [onRevealed] runs. Letting go early
/// empties it again. Screen readers get a plain "activate" instead.
class HoldToReveal extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onRevealed;
  final Duration hold;
  const HoldToReveal({super.key, required this.label, required this.color, required this.onRevealed, this.hold = const Duration(milliseconds: 650)});
  @override
  State<HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<HoldToReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.hold)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        haptic(HapticWeight.medium);
        widget.onRevealed();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    haptic(HapticWeight.selection);
    _c.forward();
  }

  void _cancel() {
    if (_c.status != AnimationStatus.completed) _c.animateBack(0, duration: Motion.fast);
  }

  @override
  Widget build(BuildContext context) {
    final fill = fillFor(widget.color);
    return Semantics(
      button: true,
      label: widget.label.replaceFirst('HOLD TO', 'TAP TO'),
      hint: 'Shows your secret',
      onTap: widget.onRevealed,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Color.lerp(fill, Colors.black, 0.42)!, offset: Offset(0, _c.value > 0 ? 1 : 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: ColoredBox(color: Color.lerp(fill, Colors.black, 0.3)!)),
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _c.value, child: ColoredBox(color: fill))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.touch_app_rounded, color: Colors.white),
                    const SizedBox(width: Space.s),
                    Flexible(child: Text(widget.label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5, letterSpacing: 0.6))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one card style for words, prompts, roles and secrets: white, coloured header band.
class PromptCard extends StatelessWidget {
  final String header;
  final String text;
  final String? emoji;
  final String? footer;
  final Color color;
  const PromptCard({super.key, required this.header, required this.text, this.emoji, this.footer, this.color = const Color(0xFF7B4DFF)});

  @override
  Widget build(BuildContext context) {
    final band = fillFor(color);
    return TweenAnimationBuilder<double>(
      key: ValueKey(header + text),
      tween: Tween(begin: Motion.reduced(context) ? 1 : 0.85, end: 1),
      duration: Motion.of(context, Motion.slow),
      curve: Curves.easeOutBack,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Semantics(
        label: '$header: $text${footer != null ? '. $footer' : ''}',
        excludeSemantics: true,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: Radii.rXl,
            border: Border.all(color: band, width: 4),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 18), BoxShadow(color: Color.lerp(band, Colors.black, 0.4)!, offset: const Offset(0, 5))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: Space.s),
              decoration: BoxDecoration(color: band, borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl - 5))),
              child: Text(header, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.l),
              child: Column(children: [
                if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 56)),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w900, fontSize: 26, height: 1.15)),
                if (footer != null) ...[
                  const SizedBox(height: Space.s),
                  Text(footer!, textAlign: TextAlign.center, style: const TextStyle(color: FlatPalette.inkMuted, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Players as tappable chips, e.g. for voting. [disabled] players can't be picked;
/// [counts] shows a number badge per player (votes); [highlight] rings a player.
class PlayerPicker extends StatelessWidget {
  final List<GpPlayer> players;
  final Set<int> disabled;
  final Map<int, int> counts;
  final int? highlight;
  final void Function(int index)? onPick;
  final Map<int, String> notes; // small text under a name, e.g. "OUT"
  const PlayerPicker({super.key, required this.players, this.disabled = const {}, this.counts = const {}, this.highlight, this.onPick, this.notes = const {}});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Wrap(alignment: WrapAlignment.center, spacing: Space.s, runSpacing: Space.m, children: [
      for (var i = 0; i < players.length; i++)
        Semantics(
          button: onPick != null && !disabled.contains(i),
          enabled: !disabled.contains(i),
          selected: highlight == i,
          label: '${players[i].name}${notes[i] != null ? ', ${notes[i]}' : ''}${(counts[i] ?? 0) > 0 ? ', ${counts[i]} votes' : ''}',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onPick == null || disabled.contains(i)
                ? null
                : () {
                    haptic(HapticWeight.selection);
                    onPick!(i);
                  },
            child: Opacity(
              opacity: disabled.contains(i) ? 0.4 : 1,
              child: AnimatedScale(
                duration: Motion.of(context, Motion.fast),
                scale: highlight == i ? 1.06 : 1,
                child: Stack(clipBehavior: Clip.none, children: [
                  AnimatedContainer(
                    duration: Motion.of(context, Motion.normal),
                    width: 96,
                    constraints: const BoxConstraints(minHeight: 96),
                    padding: const EdgeInsets.fromLTRB(6, Space.m, 6, Space.s),
                    decoration: t.flat
                        ? flatTile(radius: Radii.lg).copyWith(border: Border.all(color: highlight == i ? fillFor(players[i].color) : FlatPalette.tileShade, width: highlight == i ? 4 : 2))
                        : BoxDecoration(
                            color: highlight == i ? fillFor(players[i].color) : t.glass,
                            borderRadius: Radii.rLg,
                            border: Border.all(color: players[i].color, width: 3),
                          ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      PlayerAvatar(name: players[i].name, color: players[i].color, size: 42),
                      const SizedBox(height: 6),
                      Text(players[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.flat ? t.text : (highlight == i ? Colors.white : t.onBg), fontWeight: FontWeight.w900, fontSize: 13)),
                      if (notes[i] != null)
                        Text(notes[i]!, maxLines: 1, style: TextStyle(color: t.flat ? t.textMuted : (highlight == i ? Colors.white : t.onBgMuted), fontWeight: FontWeight.w900, fontSize: 11)),
                    ]),
                  ),
                  if ((counts[i] ?? 0) > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: fillFor(t.danger), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: Text('${counts[i]}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Seconds-left chip that turns red near the end.
class TimeChip extends StatelessWidget {
  final int msLeft;
  const TimeChip(this.msLeft, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = (msLeft / 1000).ceil();
    final urgent = s <= 10;
    final text = s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '${s}s';
    return Semantics(
      label: '$s seconds left',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 5),
        decoration: BoxDecoration(color: urgent ? fillFor(t.danger) : (t.flat ? FlatPalette.option : t.glassStrong), borderRadius: Radii.rMd),
        child: Text(text, style: t.styles.score.copyWith(fontSize: 16, color: urgent ? Colors.white : (t.flat ? t.text : t.onBg))),
      ),
    );
  }
}

/// Message shown on online phones while another player acts.
class WaitingNote extends StatelessWidget {
  final String text;
  const WaitingNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: t.accent, strokeWidth: 3)),
          const SizedBox(height: Space.m),
          Text(text, textAlign: TextAlign.center, style: (t.flat ? t.cardStyles : t.styles).bodyStrong.copyWith(fontSize: 16, color: t.flat ? t.onBg : null)),
        ]),
      ),
    );
  }
}

/// The player with the most votes, or -1 for no votes or a tie.
int voteWinner(List<int?> votes) {
  final tally = <int, int>{};
  for (final v in votes) {
    if (v != null) tally[v] = (tally[v] ?? 0) + 1;
  }
  if (tally.isEmpty) return -1;
  final best = tally.values.reduce((a, b) => a > b ? a : b);
  final top = tally.entries.where((e) => e.value == best).map((e) => e.key).toList();
  return top.length == 1 ? top.single : -1; // tie: nobody
}
