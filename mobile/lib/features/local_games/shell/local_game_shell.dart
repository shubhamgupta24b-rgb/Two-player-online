import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../../guess_person/widgets/result_view.dart' show Confetti;
import '../../guess_person/widgets/score_board.dart';
import 'local_game_info.dart';

enum _ShellPhase { intro, countdown, playing, result }

/// Lets a game place its own pause/leave button wherever it fits its layout.
class LeaveGameScope extends InheritedWidget {
  final VoidCallback onLeave;
  const LeaveGameScope({super.key, required this.onLeave, required super.child});
  static VoidCallback? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LeaveGameScope>()?.onLeave;
  @override
  bool updateShouldNotify(LeaveGameScope old) => false;
}

class PauseButton extends StatelessWidget {
  const PauseButton({super.key});
  @override
  Widget build(BuildContext context) {
    final leave = LeaveGameScope.of(context);
    if (leave == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Leave game',
      onPressed: leave,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white70, size: 30),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}

/// Shared flow for every 1-device game: intro -> 3-2-1 -> play -> result -> play again.
/// Match wins are tallied for as long as the players stay on this screen.
class LocalGameShell extends StatefulWidget {
  final LocalGameInfo game;
  const LocalGameShell({super.key, required this.game});
  @override
  State<LocalGameShell> createState() => _LocalGameShellState();
}

class _LocalGameShellState extends State<LocalGameShell> {
  final players = defaultPlayers();
  final wins = [0, 0];
  var phase = _ShellPhase.intro;
  var matchNo = 0;
  List<int> lastScores = const [0, 0];

  void _start() => setState(() => phase = _ShellPhase.countdown);

  void _go() => setState(() {
        matchNo++;
        phase = _ShellPhase.playing;
      });

  void _finished(List<int> scores) {
    if (!mounted) return;
    HapticFeedback.mediumImpact().ignore();
    setState(() {
      lastScores = scores;
      for (var i = 0; i < players.length; i++) {
        players[i].score = scores[i];
      }
      final top = scores.reduce((a, b) => a > b ? a : b);
      final leaders = [for (var i = 0; i < scores.length; i++) if (scores[i] == top) i];
      if (leaders.length == 1) wins[leaders.single]++;
      phase = _ShellPhase.result;
    });
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GpColors.bgTop,
        title: const Text('Leave game?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('This match will be lost.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('LEAVE', style: TextStyle(color: GpColors.no))),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final Widget body = switch (phase) {
      _ShellPhase.intro => _Intro(game: g, onPlay: _start),
      _ShellPhase.countdown => _Countdown(onDone: _go, color: g.color),
      // A new key per match guarantees fresh game state on Play Again.
      _ShellPhase.playing => KeyedSubtree(key: ValueKey('match$matchNo'), child: g.play(players, _finished)),
      _ShellPhase.result => _Result(game: g, players: players, wins: wins, onAgain: _start, onExit: () => Navigator.pop(context)),
    };
    return PopScope(
      canPop: phase != _ShellPhase.playing && phase != _ShellPhase.countdown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: GpBackground(
          child: SafeArea(
            child: LeaveGameScope(
              onLeave: _confirmLeave,
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey('$phase$matchNo'), child: body)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final LocalGameInfo game;
  final VoidCallback onPlay;
  const _Intro({required this.game, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        top: 4,
        left: 4,
        child: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: game.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: game.color.withValues(alpha: 0.5), blurRadius: 24)]),
                  child: Text(game.emoji, style: const TextStyle(fontSize: 60)),
                ),
              ),
              const SizedBox(height: 18),
              Text(game.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xFF6C5CE7), offset: Offset(0, 3))])),
              const SizedBox(height: 6),
              Text(game.tagline, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: GpColors.panel, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('HOW TO PLAY', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
                  const SizedBox(height: 8),
                  for (final r in game.rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('•  ', style: TextStyle(color: GpColors.accent, fontWeight: FontWeight.w900, fontSize: 16)),
                        Expanded(child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 15))),
                      ]),
                    ),
                ]),
              ),
              if (game.splitScreen) ...[
                const SizedBox(height: 12),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.screen_rotation_alt_rounded, color: Colors.white60, size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text('Lay the phone flat · Player 1 bottom, Player 2 top',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
                  ),
                ]),
              ],
              const SizedBox(height: 24),
              GpButton('PLAY', icon: Icons.play_arrow_rounded, onPressed: onPlay),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _Countdown extends StatefulWidget {
  final VoidCallback onDone;
  final Color color;
  const _Countdown({required this.onDone, required this.color});
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final step = (_c.value * 3).floor().clamp(0, 2);
        final t = (_c.value * 3) - step; // 0..1 within this number
        final label = ['3', '2', '1'][step];
        final text = Text(label, style: TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w900, shadows: [Shadow(color: widget.color, offset: const Offset(0, 6))]));
        // Shown to both ends of the table.
        return Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          RotatedBox(quarterTurns: 2, child: Opacity(opacity: (1 - t).clamp(0.3, 1), child: Transform.scale(scale: 1.4 - t * 0.4, child: text))),
          const Text('GET READY!', style: TextStyle(color: GpColors.accent, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Opacity(opacity: (1 - t).clamp(0.3, 1), child: Transform.scale(scale: 1.4 - t * 0.4, child: text)),
        ]);
      },
    );
  }
}

class _Result extends StatelessWidget {
  final LocalGameInfo game;
  final List<GpPlayer> players;
  final List<int> wins;
  final VoidCallback onAgain;
  final VoidCallback onExit;
  const _Result({required this.game, required this.players, required this.wins, required this.onAgain, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final top = players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
    final leaders = players.where((p) => p.score == top).toList();
    final draw = leaders.length > 1;
    return Stack(children: [
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(draw ? '🤝' : '🏆', textAlign: TextAlign.center, style: const TextStyle(fontSize: 72)),
              Text(draw ? 'DRAW!' : '${leaders.single.name.toUpperCase()} WINS!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: draw ? Colors.white : leaders.single.color, fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${game.emoji} ${game.title}', textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Text(game.scoreUnit.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              ScoreBoard(players: players, large: true, highlight: draw ? const {} : leaders.toSet()),
              const SizedBox(height: 14),
              Text('MATCHES WON  ·  ${players[0].name} ${wins[0]} – ${wins[1]} ${players[1].name}',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              GpButton('PLAY AGAIN', icon: Icons.replay_rounded, onPressed: onAgain),
              const SizedBox(height: 12),
              GpButton('ALL GAMES', icon: Icons.grid_view_rounded, outlined: true, onPressed: onExit),
            ]),
          ),
        ),
      ),
      if (!draw) const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }
}
