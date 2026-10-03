import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/app_flavor.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../../guess_person/widgets/result_view.dart' show Confetti;
import '../../guess_person/widgets/score_board.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_style.dart';
import 'local_game_info.dart';

export 'game_style.dart';

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
    if (GameTheme.flatOf(context)) {
      // Flat look: round white button with a blue icon, like the board game app's ✕.
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Tooltip(
          message: 'Leave game',
          child: Semantics(
            button: true,
            label: 'Leave game',
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(side: BorderSide(color: FlatColors.tileShade, width: 2)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: leave,
                child: const SizedBox(width: 42, height: 42, child: Icon(Icons.pause_rounded, color: FlatColors.sky, size: 28)),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GlassIconButton(icon: Icons.pause_rounded, tooltip: 'Leave game', onPressed: leave),
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
  late var players = _makePlayers(widget.game.minPlayers);
  int? best; // solo games: best score on this phone
  bool newBest = false;
  late var wins = List.filled(players.length, 0);
  var phase = _ShellPhase.intro;
  var matchNo = 0;
  int botCount = 0; // computer players; 0 = everyone is a person
  bool get vsComputer => botCount > 0;
  List<BotSeat> _bots = const [];

  /// People take the first seats, computer players the rest. A lone person is "You".
  List<GpPlayer> _makePlayers(int n) {
    if (widget.game.solo) return [GpPlayer(name: 'You', color: gpPlayerColors[0])];
    final base = defaultPlayers(n);
    if (!vsComputer) return base;
    final people = n - botCount;
    return [
      for (var i = 0; i < n; i++)
        GpPlayer(name: i < people ? (people == 1 ? 'You' : base[i].name) : 'CPU ${i - people + 1}', color: base[i].color),
    ];
  }

  /// Changing the player count (or who's playing) starts a fresh tally.
  void _setPlayerCount(int n) => setState(() {
        if (vsComputer) botCount = botCount.clamp(1, n - 1);
        players = _makePlayers(n);
        wins = List.filled(n, 0);
      });

  /// Switching on fills every other seat with the computer; the BOTS row then gives seats back to people.
  void _setVsComputer(bool on) {
    botCount = on ? players.length - 1 : 0;
    _setPlayerCount(players.length);
  }

  void _setBotCount(int n) {
    botCount = n;
    _setPlayerCount(players.length);
  }

  void _start() => setState(() => phase = _ShellPhase.countdown);

  void _go() => setState(() {
        matchNo++;
        // Fresh computer players every match (their memory and timing start over).
        _bots = vsComputer && widget.game.bot != null ? [for (var i = players.length - botCount; i < players.length; i++) BotSeat(i)] : const [];
        phase = _ShellPhase.playing;
      });

  Widget _play(LocalGameInfo g) {
    final game = g.play(players, _finished);
    if (_bots.isEmpty) return game;
    return BotScope(seats: _bots, turn: g.bot!, child: game);
  }

  void _finished(List<int> scores) {
    if (!mounted) return;
    HapticFeedback.mediumImpact().ignore();
    setState(() {
      for (var i = 0; i < players.length; i++) {
        players[i].score = scores[i];
      }
      final top = scores.reduce((a, b) => a > b ? a : b);
      final leaders = [for (var i = 0; i < scores.length; i++) if (scores[i] == top) i];
      if (leaders.length == 1) wins[leaders.single]++;
      phase = _ShellPhase.result;
    });
    if (widget.game.solo) _saveBest(scores.single);
  }

  /// Solo games keep a best score per game on this phone.
  Future<void> _saveBest(int score) async {
    final key = 'best_${widget.game.id}';
    var prev = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      prev = prefs.getInt(key) ?? 0;
      if (score > prev) await prefs.setInt(key, score);
    } catch (_) {
      // No storage (e.g. tests): just show this game's score.
    }
    if (!mounted) return;
    setState(() {
      newBest = score > prev;
      best = score > prev ? score : prev;
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
    final flat = isFlatGame(g.id) && phase == _ShellPhase.playing; // intro and results keep the dark look
    final Widget body = switch (phase) {
      _ShellPhase.intro => _Intro(
          game: g,
          onPlay: _start,
          playerCount: players.length,
          onPlayerCount: _setPlayerCount,
          botCount: botCount,
          onVsComputer: g.bot == null ? null : _setVsComputer,
          onBotCount: _setBotCount,
        ),
      _ShellPhase.countdown => _Countdown(onDone: _go, color: g.color),
      // A new key per match guarantees fresh game state on Play Again.
      _ShellPhase.playing => KeyedSubtree(key: ValueKey('match$matchNo'), child: _play(g)),
      _ShellPhase.result => g.solo
          ? _SoloResult(game: g, score: players.single.score, best: best, newBest: newBest, onAgain: _start, onExit: () => Navigator.pop(context))
          : _Result(game: g, players: players, wins: wins, onAgain: _start, onExit: () => Navigator.pop(context)),
    };
    return PopScope(
      canPop: phase != _ShellPhase.playing && phase != _ShellPhase.countdown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        // Each game glows in its own colour (the flat app draws word games on a sky-blue board).
        body: GameTheme(
          color: g.color,
          emoji: g.emoji,
          flat: flat,
          child: GameBackground(
            color: g.color,
            flat: flat,
            child: SafeArea(
              child: LeaveGameScope(
                onLeave: _confirmLeave,
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey('$phase$matchNo'), child: body)),
              ),
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
  final int playerCount;
  final ValueChanged<int> onPlayerCount;
  final int botCount;
  final ValueChanged<bool>? onVsComputer; // null: this game has no computer players
  final ValueChanged<int>? onBotCount;
  const _Intro({required this.game, required this.onPlay, required this.playerCount, required this.onPlayerCount, this.botCount = 0, this.onVsComputer, this.onBotCount});

  bool get vsComputer => botCount > 0;

  String get _vsText {
    final people = playerCount - botCount;
    if (people == 1) return 'You are Player 1. The computer plays the other $botCount.';
    return '$people people + $botCount computer ${botCount == 1 ? 'player' : 'players'}.';
  }

  @override
  Widget build(BuildContext context) {
    final c = game.color;
    final dark = Color.lerp(c, Colors.black, 0.45)!;
    Widget sectionLabel(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(t, style: TextStyle(color: Color.lerp(c, Colors.white, 0.55), fontWeight: FontWeight.w900, letterSpacing: 1.6, fontSize: 12)),
        );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(alignment: Alignment.centerLeft, child: GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.maybePop(context))),
            const SizedBox(height: 10),
            // Hero banner in the game's colour.
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c, dark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 28, offset: const Offset(0, 10))],
              ),
              child: Column(children: [
                Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                  ),
                  child: Text(game.emoji, style: const TextStyle(fontSize: 56)),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  child: Text(game.title.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(color: Colors.black38, offset: Offset(0, 3))])),
                ),
                const SizedBox(height: 4),
                Text(game.tagline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                  _Badge(game.solo ? '🧍 SOLO' : '👥 ${game.minPlayers == game.maxPlayers ? game.maxPlayers : '${game.minPlayers}–${game.maxPlayers}'} PLAYERS'),
                  if (game.bot != null) const _Badge('🤖 VS COMPUTER'),
                  if (game.online != null) const _Badge('🌐 ONLINE'),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            sectionLabel('HOW TO PLAY'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: Column(children: [
                for (var i = 0; i < game.rules.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == game.rules.length - 1 ? 0 : 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(game.rules[i], style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3)))),
                    ]),
                  ),
              ]),
            ),
            if (game.maxPlayers > game.minPlayers) ...[
              const SizedBox(height: 18),
              sectionLabel('PLAYERS'),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                for (var n = game.minPlayers; n <= game.maxPlayers; n++)
                  Semantics(
                    button: true,
                    selected: n == playerCount,
                    label: '$n players',
                    child: GestureDetector(
                      onTap: () => onPlayerCount(n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: n == playerCount ? c : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: n == playerCount ? Colors.white : Colors.white24, width: 2),
                          boxShadow: [if (n == playerCount) BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 12)],
                        ),
                        child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                      ),
                    ),
                  ),
              ]),
            ],
            if (onVsComputer != null) ...[
              const SizedBox(height: 14),
              Material(
                color: vsComputer ? c.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                child: SwitchListTile(
                  value: vsComputer,
                  onChanged: onVsComputer,
                  activeThumbColor: Colors.white,
                  activeTrackColor: dark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('🤖 PLAY VS COMPUTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  subtitle: Text(vsComputer ? _vsText : 'Not enough friends? Fill the empty seats with bots.',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
              ),
            ],
            if (vsComputer && playerCount > 2 && onBotCount != null) ...[
              const SizedBox(height: 14),
              sectionLabel('BOTS  ·  ${playerCount - botCount} ${playerCount - botCount == 1 ? 'PERSON' : 'PEOPLE'} PLAYING'),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                for (var n = 1; n < playerCount; n++)
                  Semantics(
                    button: true,
                    selected: n == botCount,
                    label: '$n computer players',
                    child: GestureDetector(
                      onTap: () => onBotCount!(n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: n == botCount ? c : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: n == botCount ? Colors.white : Colors.white24, width: 2),
                        ),
                        child: Text('🤖 $n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      ),
                    ),
                  ),
              ]),
            ],
            if (game.splitScreen && playerCount - botCount > 1 && !game.solo) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.screen_rotation_alt_rounded, color: Colors.white60, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                      playerCount == 2 ? 'Lay the phone flat · Player 1 bottom, Player 2 top' : 'Lay the phone flat · players sit along both long sides, each at their own zone',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ),
              ]),
            ],
            const SizedBox(height: 22),
            GpButton('PLAY', icon: Icons.play_arrow_rounded, color: c, textColor: Colors.white, onPressed: onPlay),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5)),
      );
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

class _SoloResult extends StatelessWidget {
  final LocalGameInfo game;
  final int score;
  final int? best;
  final bool newBest;
  final VoidCallback onAgain;
  final VoidCallback onExit;
  const _SoloResult({required this.game, required this.score, required this.best, required this.newBest, required this.onAgain, required this.onExit});

  @override
  Widget build(BuildContext context) => Stack(children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(newBest ? '🏆' : game.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 72)),
                Text(newBest ? 'NEW BEST!' : 'GAME OVER',
                    textAlign: TextAlign.center, style: TextStyle(color: newBest ? GpColors.accent : Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                Text('${game.emoji} ${game.title}', textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 22),
                Text('$score', textAlign: TextAlign.center, style: TextStyle(color: game.color, fontSize: 72, fontWeight: FontWeight.w900, height: 1)),
                Text(game.scoreUnit.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                if (best != null) Text('BEST: $best', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 28),
                GpButton('PLAY AGAIN', icon: Icons.replay_rounded, onPressed: onAgain),
                const SizedBox(height: 12),
                GpButton('ALL GAMES', icon: Icons.grid_view_rounded, outlined: true, onPressed: onExit),
              ]),
            ),
          ),
        ),
        if (newBest) const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ]);
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
              Text('MATCHES WON  ·  ${[for (var i = 0; i < players.length; i++) '${players[i].name} ${wins[i]}'].join('  ·  ')}',
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
