import 'package:flutter/material.dart';
import '../../../core/ui/app_flavor.dart';
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
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GameTopBar(title: title, subtitle: subtitle, trailing: trailing),
          const SizedBox(height: 12),
          Expanded(child: child),
        ]),
      );
}

/// Frosted header used by most games: pause, a bold title (and line under it), extras on the right.
class GameTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const GameTopBar({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = GameTheme.colorOf(context);
    if (GameTheme.flatOf(context)) {
      return Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        decoration: flatTile(radius: 22),
        child: Row(children: [
          const PauseButton(),
          const SizedBox(width: 8),
          Container(width: 5, height: 30, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FlatColors.ink, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.6)),
              if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _flatMuted, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        const PauseButton(),
        const SizedBox(width: 8),
        Container(width: 4, height: 30, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.6)),
            if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ]),
    );
  }
}

/// "Pass to NAME" -> tap -> the secret -> "hide" and pass on. Used for every secret card.
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
    if (!revealed && GameTheme.flatOf(context)) return _flatPass();
    if (!revealed) {
      final c = player.color;
      return Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0.04)]),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: c.withValues(alpha: 0.5), width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color.lerp(c, Colors.white, 0.25)!, c, Color.lerp(c, Colors.black, 0.3)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 30)],
                  ),
                  child: Text(player.name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900)),
                ),
                const Positioned(right: -8, bottom: -4, child: Text('📲', style: TextStyle(fontSize: 34))),
              ]),
              const SizedBox(height: 18),
              const Text('PASS THE PHONE TO', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              const SizedBox(height: 4),
              FittedBox(child: Text(player.name.toUpperCase(), style: TextStyle(color: Color.lerp(c, Colors.white, 0.35), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1))),
              const SizedBox(height: 6),
              const Text('Everyone else, look away! 🙈', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              const SizedBox(height: 22),
              GpButton('TAP TO SEE YOUR SECRET', icon: Icons.visibility_rounded, color: c, textColor: Colors.white, onPressed: onReveal),
            ]),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: Center(child: SingleChildScrollView(child: secret))),
      const SizedBox(height: 10),
      GpButton(doneLabel, icon: Icons.visibility_off_rounded, onPressed: onDone),
    ]);
  }

  /// Flat look: a white card like a character tile, the name on a dark strip.
  Widget _flatPass() {
    final c = player.color;
    return Center(
      child: SingleChildScrollView(
        child: Container(
          decoration: flatTile(radius: 28),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 24),
            Center(
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 110,
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: FlatColors.tileShade, width: 5)),
                  child: Text(player.name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w900)),
                ),
                const Positioned(right: -10, bottom: -4, child: Text('📲', style: TextStyle(fontSize: 36))),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('PASS THE PHONE TO', textAlign: TextAlign.center, style: TextStyle(color: _flatMuted, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              color: FlatColors.strip,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: FittedBox(child: Text(player.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1))),
            ),
            const SizedBox(height: 12),
            const Text('Everyone else, look away! 🙈', textAlign: TextAlign.center, style: TextStyle(color: FlatColors.ink, fontWeight: FontWeight.w800, fontSize: 15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: GpButton('TAP TO SEE YOUR SECRET', icon: Icons.visibility_rounded, color: c, textColor: Colors.white, onPressed: onReveal),
            ),
          ]),
        ),
      ),
    );
  }
}

const _flatMuted = Color(0xFF6B7280);

/// A big white card with a coloured header, for words, prompts and secrets.
class PromptCard extends StatelessWidget {
  final String header;
  final String text;
  final String? emoji;
  final String? footer;
  final Color color;
  const PromptCard({super.key, required this.header, required this.text, this.emoji, this.footer, this.color = const Color(0xFF7B4DFF)});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(header + text),
        tween: Tween(begin: 0.8, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: color, width: 4), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 18)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(19))),
              child: Text(header, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(children: [
                if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 56)),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.ink, fontWeight: FontWeight.w900, fontSize: 26, height: 1.15)),
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  Text(footer!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B6785), fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ]),
            ),
          ]),
        ),
      );
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
  Widget build(BuildContext context) => GameTheme.flatOf(context) ? _flat() : Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < players.length; i++)
          Semantics(
            button: onPick != null && !disabled.contains(i),
            label: players[i].name,
            child: GestureDetector(
              onTap: onPick == null || disabled.contains(i) ? null : () => onPick!(i),
              child: Opacity(
                opacity: disabled.contains(i) ? 0.35 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 96,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: highlight == i ? players[i].color : Colors.white10,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: players[i].color, width: 3),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: players[i].color,
                        child: Text(players[i].name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      if ((counts[i] ?? 0) > 0)
                        Positioned(
                          right: -10,
                          top: -6,
                          child: CircleAvatar(radius: 11, backgroundColor: GpColors.no, child: Text('${counts[i]}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(players[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    if (notes[i] != null) Text(notes[i]!, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, fontSize: 10.5)),
                  ]),
                ),
              ),
            ),
          ),
      ]);

  /// Flat look: white player tiles with the name on a dark strip, like character cards.
  Widget _flat() => Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 12, children: [
        for (var i = 0; i < players.length; i++)
          Semantics(
            button: onPick != null && !disabled.contains(i),
            label: players[i].name,
            child: GestureDetector(
              onTap: onPick == null || disabled.contains(i) ? null : () => onPick!(i),
              child: Opacity(
                opacity: disabled.contains(i) ? 0.45 : 1,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: highlight == i ? 1.07 : 1,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 92,
                      decoration: flatTile(radius: 14).copyWith(border: Border.all(color: highlight == i ? players[i].color : Colors.white, width: highlight == i ? 4 : 2)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                          child: Center(
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: players[i].color,
                              child: Text(players[i].name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                            ),
                          ),
                        ),
                        Container(
                          color: FlatColors.strip,
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                          child: Column(children: [
                            Text(players[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                            if (notes[i] != null) Text(notes[i]!, maxLines: 1, style: const TextStyle(color: Color(0xFFFFC93C), fontWeight: FontWeight.w900, fontSize: 10.5)),
                          ]),
                        ),
                      ]),
                    ),
                    if ((counts[i] ?? 0) > 0)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: CircleAvatar(radius: 13, backgroundColor: FlatColors.close, child: Text('${counts[i]}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
                      ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
}

/// Seconds-left chip that turns red near the end.
class TimeChip extends StatelessWidget {
  final int msLeft;
  const TimeChip(this.msLeft, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = (msLeft / 1000).ceil();
    final urgent = s <= 10;
    final flat = GameTheme.flatOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: urgent ? GpColors.no : (flat ? FlatColors.option : Colors.white12), borderRadius: BorderRadius.circular(14)),
      child: Text(s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '${s}s',
          style: TextStyle(color: flat && !urgent ? FlatColors.ink : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }
}

/// Message shown on online phones while another player acts.
class WaitingNote extends StatelessWidget {
  final String text;
  const WaitingNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: GpColors.accent, strokeWidth: 3)),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );
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
