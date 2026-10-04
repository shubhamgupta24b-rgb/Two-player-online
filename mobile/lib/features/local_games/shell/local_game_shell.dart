import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/records/records.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/ui/app_flavor.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../guess_person/widgets/gp_theme.dart';
import '../../guess_person/widgets/result_view.dart' show Confetti;
import 'game_pause.dart';
import 'game_style.dart';
import 'local_game_info.dart';
import 'turns_play.dart';

export 'game_pause.dart';
export 'game_style.dart';

enum _ShellPhase { intro, countdown, playing, result }

/// Lets a game place its own pause button wherever it fits its layout. [onLeave] opens the
/// pause menu (resume, restart, how to play, sound, quit).
class LeaveGameScope extends InheritedWidget {
  final VoidCallback onLeave;
  const LeaveGameScope({super.key, required this.onLeave, required super.child});
  static VoidCallback? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LeaveGameScope>()?.onLeave;
  @override
  bool updateShouldNotify(LeaveGameScope old) => false;
}

/// The pause button every game shows. Opens the shell's pause menu.
class PauseButton extends StatelessWidget {
  const PauseButton({super.key});
  @override
  Widget build(BuildContext context) {
    final open = LeaveGameScope.of(context);
    if (open == null) return const SizedBox.shrink();
    return AppIconButton(icon: Icons.pause_rounded, tooltip: 'Pause', onPressed: open, size: 40);
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
  final _paused = ValueNotifier(false);
  bool _menuOpen = false;

  /// People take the first seats, computer players the rest. A lone person is "You"
  /// (or the name set in Settings); the colour picked in Settings goes to seat 1.
  List<GpPlayer> _makePlayers(int n) {
    final myName = AppSettings.playerName.value;
    final colours = [for (var i = 0; i < math.max(n, 1); i++) gpPlayerColors[i % gpPlayerColors.length]];
    final mine = PlayerPalette.color(AppSettings.playerColor.value);
    final swap = colours.indexOf(mine);
    if (swap > 0) colours[swap] = colours[0];
    colours[0] = mine;
    if (widget.game.solo) return [GpPlayer(name: myName.isEmpty ? 'You' : myName, color: colours[0])];
    final people = n - botCount;
    return [
      for (var i = 0; i < n; i++)
        GpPlayer(
          name: i == 0 && myName.isNotEmpty
              ? myName
              : (i < people ? (people == 1 ? 'You' : 'Player ${i + 1}') : 'CPU ${i - people + 1}'),
          color: colours[i],
        ),
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

  bool teams = false; // 2 vs 2, for games that have a team version and 4 players

  /// The game being played: its team version when TEAMS is on.
  LocalGameInfo get _game => teams && players.length == 4 && widget.game.teamVariant != null ? widget.game.teamVariant! : widget.game;
  bool get _teamsOn => !identical(_game, widget.game);

  bool takeTurns = true; // full screen, one player at a time (games that offer it)
  int turnMinutes = 1;
  bool get _turnsOn => takeTurns && _game.turns != null && players.length > 1;

  // No 3-2-1 for solo games (you start when you're ready) or take turns (each turn has its START).
  void _start() => _turnsOn || widget.game.solo ? _go() : setState(() => phase = _ShellPhase.countdown);

  void _go() => setState(() {
        matchNo++;
        _paused.value = false;
        // Fresh computer players every match (their memory and timing start over).
        _bots = vsComputer && _game.bot != null ? [for (var i = players.length - botCount; i < players.length; i++) BotSeat(i, null, players.length - botCount == 1)] : const [];
        phase = _ShellPhase.playing;
        GameAudio.music(GameAudio.musicFor(widget.game.id));
      });

  @override
  void dispose() {
    GameAudio.stopMusic();
    _paused.dispose();
    super.dispose();
  }

  Widget _play(LocalGameInfo g) {
    if (_turnsOn) {
      return TurnsPlay(
        spec: g.turns!,
        players: players,
        botSeats: vsComputer ? {for (var i = players.length - botCount; i < players.length; i++) i} : const {},
        durationMs: turnMinutes * 60000,
        onFinished: _finished,
      );
    }
    final game = g.play(players, _finished);
    if (_bots.isEmpty) return game;
    return BotScope(seats: _bots, turn: g.bot!, people: players.length - botCount, child: game);
  }

  void _finished(List<int> scores) {
    if (!mounted) return;
    haptic(HapticWeight.medium);
    GameAudio.stopMusic();
    GameAudio.sfx('win');
    if (_menuOpen) Navigator.of(context).popUntil((r) => r is! PopupRoute);
    setState(() {
      for (var i = 0; i < players.length; i++) {
        players[i].score = scores[i];
      }
      final top = scores.reduce((a, b) => a > b ? a : b);
      final leaders = [for (var i = 0; i < scores.length; i++) if (scores[i] == top) i];
      // One winner, or a whole team (2 vs 2) winning together.
      if (leaders.length == 1 || _teamsOn && leaders.length == 2) {
        for (final i in leaders) {
          wins[i]++;
        }
      }
      phase = _ShellPhase.result;
      best = null;
      newBest = false;
    });
    _record(scores);
  }

  /// My Records on this phone: solo and "you vs the computer" count as yours (with wins);
  /// a game shared by several people records the best score made on this phone.
  /// Solo games show the best score so far and a NEW BEST badge.
  Future<void> _record(List<int> scores) async {
    final top = scores.reduce((a, b) => a > b ? a : b);
    final people = players.length - botCount;
    if (widget.game.solo) {
      final score = scores.single;
      var prev = 0;
      try {
        prev = (await Records.all())[widget.game.id]?.best ?? 0;
      } catch (_) {}
      await Records.add(widget.game.id, score: score);
      if (!mounted) return;
      setState(() {
        newBest = score > prev;
        best = math.max(score, prev);
      });
    } else if (vsComputer && people == 1) {
      final leaders = [for (var i = 0; i < scores.length; i++) if (scores[i] == top) i];
      final won = scores[0] == top && (leaders.length == 1 || _teamsOn && leaders.length == 2);
      Records.add(_game.id, score: scores[0], won: won).ignore();
    } else {
      Records.add(_game.id, score: top).ignore();
    }
  }

  /// The pause menu: the game clock stops while it's open.
  Future<void> _openMenu() async {
    if (_menuOpen) return;
    if (phase != _ShellPhase.playing && phase != _ShellPhase.countdown) {
      Navigator.maybePop(context);
      return;
    }
    _menuOpen = true;
    _paused.value = true;
    haptic(HapticWeight.selection);
    final action = await showAppSheet<_MenuAction>(context, title: '⏸ Paused', builder: (ctx) => _PauseMenu(game: _game));
    _menuOpen = false;
    if (!mounted) return;
    switch (action) {
      case _MenuAction.restart:
        if (await confirmAction(context, title: 'Restart?', message: 'This match starts again from the beginning.', confirm: 'RESTART', emoji: '🔄')) {
          _start();
        }
      case _MenuAction.quit:
        if (await confirmAction(context, title: 'Leave game?', message: 'This match will be lost.', confirm: 'LEAVE', cancel: 'STAY', emoji: '🚪')) {
          if (mounted) Navigator.pop(context);
          return;
        }
      case _MenuAction.resume || null:
        break;
    }
    if (mounted && phase == _ShellPhase.playing) _paused.value = false;
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
          teams: g.teamVariant != null && players.length == 4 ? teams : null,
          onTeams: (on) => setState(() {
            teams = on;
            wins = List.filled(players.length, 0); // a new kind of match: fresh tally
          }),
          turns: g.turns != null && players.length > 1 ? (takeTurns, turnMinutes) : null,
          onTurns: (on, minutes) => setState(() {
            takeTurns = on;
            turnMinutes = minutes;
          }),
        ),
      _ShellPhase.countdown => _Countdown(onDone: _go, color: g.color, mirrored: g.splitScreen && players.length - botCount > 1),
      // A new key per match guarantees fresh game state on Play Again.
      _ShellPhase.playing => KeyedSubtree(key: ValueKey('match$matchNo'), child: GamePause(paused: _paused, child: _play(_game))),
      _ShellPhase.result => g.solo
          ? _SoloResult(game: g, score: players.single.score, best: best, newBest: newBest, onAgain: _start, onExit: () => Navigator.pop(context))
          : _Result(
              game: _game,
              teams: _teamsOn,
              players: players,
              wins: wins,
              onAgain: _start,
              onChangePlayers: () => setState(() => phase = _ShellPhase.intro),
              onExit: () => Navigator.pop(context),
            ),
    };
    return PopScope(
      canPop: phase != _ShellPhase.playing && phase != _ShellPhase.countdown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openMenu();
      },
      child: Scaffold(
        // Each game glows in its own colour (the flat app draws word games on a sky-blue board).
        body: TokenScope(
          flat: flat,
          child: GameTheme(
            color: g.color,
            emoji: g.emoji,
            flat: flat,
            id: g.id,
            child: GameBackground(
              color: g.color,
              flat: flat,
              child: SafeArea(
                child: LeaveGameScope(
                  onLeave: _openMenu,
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.normal),
                    switchInCurve: Motion.standard,
                    child: KeyedSubtree(key: ValueKey('$phase$matchNo'), child: body),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { resume, restart, quit }

class _PauseMenu extends StatefulWidget {
  final LocalGameInfo game;
  const _PauseMenu({required this.game});
  @override
  State<_PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<_PauseMenu> {
  bool _rules = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = widget.game.color;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppButton('RESUME', icon: Icons.play_arrow_rounded, color: c, onPressed: () => Navigator.pop(context, _MenuAction.resume)),
      const SizedBox(height: Space.m),
      Row(children: [
        Expanded(child: AppButton('RESTART', icon: Icons.replay_rounded, variant: ButtonVariant.secondary, compact: true, onPressed: () => Navigator.pop(context, _MenuAction.restart))),
        const SizedBox(width: Space.m),
        Expanded(
          child: AppButton(_rules ? 'HIDE RULES' : 'HOW TO PLAY',
              icon: Icons.menu_book_rounded, variant: ButtonVariant.secondary, compact: true, onPressed: () => setState(() => _rules = !_rules)),
        ),
      ]),
      AnimatedSize(
        duration: Motion.of(context, Motion.normal),
        curve: Motion.standard,
        child: _rules
            ? Padding(
                padding: const EdgeInsets.only(top: Space.l),
                child: _RuleSteps(rules: widget.game.rules, color: c, onCard: true),
              )
            : const SizedBox(width: double.infinity),
      ),
      const SizedBox(height: Space.l),
      Divider(color: t.flat ? t.strokeStrong : t.stroke),
      SettingsPanel(color: c),
      const SizedBox(height: Space.l),
      AppButton('QUIT GAME', icon: Icons.logout_rounded, variant: ButtonVariant.danger, compact: true, onPressed: () => Navigator.pop(context, _MenuAction.quit)),
    ]);
  }
}

/// The rules as short numbered steps.
class _RuleSteps extends StatelessWidget {
  final List<String> rules;
  final Color color;
  final bool onCard;
  const _RuleSteps({required this.rules, required this.color, this.onCard = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final style = onCard ? t.cardStyles.body : t.styles.body;
    return Column(children: [
      for (var i = 0; i < rules.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == rules.length - 1 ? 0 : Space.m),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fillFor(color), shape: BoxShape.circle),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(width: Space.m),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(rules[i], style: style))),
          ]),
        ),
    ]);
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
  final bool? teams; // null: no team version for this game / player count
  final ValueChanged<bool>? onTeams;
  final (bool, int)? turns; // (take turns?, minutes each); null: not offered
  final void Function(bool on, int minutes)? onTurns;
  const _Intro(
      {required this.game,
      required this.onPlay,
      required this.playerCount,
      required this.onPlayerCount,
      this.botCount = 0,
      this.onVsComputer,
      this.onBotCount,
      this.teams,
      this.onTeams,
      this.turns,
      this.onTurns});

  bool get vsComputer => botCount > 0;

  String get _vsText {
    final people = playerCount - botCount;
    if (people == 1) return 'You are Player 1. The computer plays the other $botCount.';
    return '$people people + $botCount computer ${botCount == 1 ? 'player' : 'players'}.';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = game.color;
    final label = Color.lerp(c, Colors.white, 0.6)!;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, 0),
        child: Row(children: [
          AppIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.maybePop(context)),
          const Spacer(),
          AppIconButton(icon: Icons.tune_rounded, tooltip: 'Settings', onPressed: () => showSettingsSheet(context, profile: true)),
        ]),
      ),
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.l, Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _IntroHeader(game: game),
                const SizedBox(height: Space.xl),
                SectionLabel('HOW TO PLAY', color: label),
                AppCard(child: _RuleSteps(rules: game.rules, color: c)),
                if (game.maxPlayers > game.minPlayers) ...[
                  const SizedBox(height: Space.xl),
                  SectionLabel('PLAYERS', color: label),
                  Wrap(alignment: WrapAlignment.center, spacing: Space.s, runSpacing: Space.s, children: [
                    for (var n = game.minPlayers; n <= game.maxPlayers; n++)
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: AppChip(label: '$n', round: true, selected: n == playerCount, color: c, semanticLabel: '$n players', onTap: () => onPlayerCount(n)),
                      ),
                  ]),
                ],
                if (turns != null && onTurns != null) ...[
                  const SizedBox(height: Space.xl),
                  SectionLabel('MODE', color: label),
                  Row(children: [
                    for (final (on, emoji, title, hint) in const [
                      (true, '👤', 'TAKE TURNS', 'Whole screen, one at a time'),
                      (false, '⚔️', 'SPLIT SCREEN', 'Everyone at once'),
                    ]) ...[
                      if (!on) const SizedBox(width: Space.m),
                      Expanded(child: _ModeCard(emoji: emoji, title: title, hint: hint, selected: turns!.$1 == on, color: c, onTap: () => onTurns!(on, turns!.$2))),
                    ],
                  ]),
                  if (turns!.$1) ...[
                    const SizedBox(height: Space.l),
                    SectionLabel('TIME EACH', color: label),
                    Wrap(alignment: WrapAlignment.center, spacing: Space.s, runSpacing: Space.s, children: [
                      for (final m in turnMinuteOptions)
                        AppChip(label: '⏱ $m min', selected: m == turns!.$2, color: c, semanticLabel: '$m minutes each', onTap: () => onTurns!(true, m)),
                    ]),
                  ],
                ],
                if (teams != null && onTeams != null) ...[
                  const SizedBox(height: Space.l),
                  _ToggleCard(
                    title: '🤝 PLAY IN TEAMS (2 vs 2)',
                    subtitle: teams! ? '🅰 Player 1 + Player 3  vs  🅱 Player 2 + Player 4' : 'Partners sit in opposite corners and win together.',
                    value: teams!,
                    color: c,
                    onChanged: onTeams!,
                  ),
                ],
                if (onVsComputer != null) ...[
                  const SizedBox(height: Space.l),
                  _ToggleCard(
                    title: '🤖 PLAY VS COMPUTER',
                    subtitle: vsComputer ? _vsText : 'Not enough friends? Fill the empty seats with bots.',
                    value: vsComputer,
                    color: c,
                    onChanged: onVsComputer!,
                  ),
                ],
                if (vsComputer && playerCount > 2 && onBotCount != null) ...[
                  const SizedBox(height: Space.l),
                  SectionLabel('BOTS  ·  ${playerCount - botCount} ${playerCount - botCount == 1 ? 'PERSON' : 'PEOPLE'} PLAYING', color: label),
                  Wrap(alignment: WrapAlignment.center, spacing: Space.s, runSpacing: Space.s, children: [
                    for (var n = 1; n < playerCount; n++)
                      AppChip(label: '🤖 $n', selected: n == botCount, color: c, semanticLabel: '$n computer players', onTap: () => onBotCount!(n)),
                  ]),
                ],
                if (game.splitScreen && playerCount - botCount > 1 && !game.solo && !(turns?.$1 ?? false)) ...[
                  const SizedBox(height: Space.m),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.screen_rotation_alt_rounded, color: t.onBgMuted, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                          playerCount == 2 ? 'Lay the phone flat · Player 1 bottom, Player 2 top' : 'Lay the phone flat · players sit along both long sides, each at their own zone',
                          textAlign: TextAlign.center,
                          style: t.styles.caption.copyWith(color: t.onBgMuted)),
                    ),
                  ]),
                ],
                const SizedBox(height: Space.xl),
                GpButton('PLAY', icon: Icons.play_arrow_rounded, color: c, textColor: Colors.white, onPressed: onPlay),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// The game's banner: its colour with a drawn pattern, the emoji in a medallion, the name.
class _IntroHeader extends StatelessWidget {
  final LocalGameInfo game;
  const _IntroHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    final c = game.color;
    final players = game.solo ? '🧍 SOLO' : '👥 ${game.minPlayers == game.maxPlayers ? game.maxPlayers : '${game.minPlayers}–${game.maxPlayers}'} PLAYERS';
    return ClipRRect(
      borderRadius: Radii.rXl,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color.lerp(c, Colors.white, 0.08)!, fillFor(c), Color.lerp(c, Colors.black, 0.55)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          borderRadius: Radii.rXl,
        ),
        child: CustomPaint(
          painter: _HeaderArt(c, game.emoji),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.xl, Space.l, Space.l),
            child: Column(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: Motion.reduced(context) ? 1 : 0.7, end: 1),
                duration: Motion.of(context, Motion.slow),
                curve: Curves.easeOutBack,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Container(
                  width: 108,
                  height: 108,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.08)]),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: ExcludeSemantics(child: Text(game.emoji, style: const TextStyle(fontSize: 58))),
                ),
              ),
              const SizedBox(height: Space.m),
              Semantics(
                header: true,
                child: FittedBox(
                  child: Text(game.title.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 4)])),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(game.tagline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black38, blurRadius: 3)])),
              const SizedBox(height: Space.m),
              Wrap(alignment: WrapAlignment.center, spacing: Space.s, runSpacing: 6, children: [
                _Badge(players),
                if (game.bot != null) const _Badge('🤖 VS COMPUTER'),
                if (game.online != null) const _Badge('🌐 ONLINE'),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Diagonal stripes, a soft spotlight and a few faint copies of the game's emoji.
class _HeaderArt extends CustomPainter {
  final Color color;
  final String emoji;
  _HeaderArt(this.color, this.emoji);

  @override
  void paint(Canvas canvas, Size size) {
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var x = -size.height; x < size.width; x += 34) {
      canvas.drawPath(
          Path()
            ..moveTo(x, size.height)
            ..lineTo(x + 16, size.height)
            ..lineTo(x + 16 + size.height, 0)
            ..lineTo(x + size.height, 0)
            ..close(),
          stripe);
    }
    final spot = Offset(size.width / 2, 72);
    canvas.drawCircle(spot, size.width * 0.55, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: spot, radius: size.width * 0.55)));
    for (final (x, y, s, r) in const [(0.1, 0.18, 26.0, -0.3), (0.88, 0.14, 30.0, 0.4), (0.07, 0.72, 22.0, 0.5), (0.92, 0.66, 24.0, -0.4)]) {
      final tp = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: s, color: Colors.white.withValues(alpha: 0.35))), textDirection: TextDirection.ltr)..layout();
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(r);
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.3));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HeaderArt old) => old.color != color || old.emoji != emoji;
}

class _ModeCard extends StatelessWidget {
  final String emoji, title, hint;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ModeCard({required this.emoji, required this.title, required this.hint, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          haptic(HapticWeight.selection);
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: Space.m, horizontal: Space.s),
          decoration: BoxDecoration(
            color: selected ? fillFor(color) : t.glass,
            borderRadius: Radii.rLg,
            border: Border.all(color: selected ? Colors.white : t.stroke, width: 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$emoji $title', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 2),
            Text(hint, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : t.onBgMuted, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

/// An on/off option card (teams, vs computer).
class _ToggleCard extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _ToggleCard({required this.title, required this.subtitle, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: value ? fillFor(color) : t.glass,
      shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: value ? Colors.white : t.stroke, width: value ? 2 : 1)),
      child: SwitchListTile(
        value: value,
        onChanged: (v) {
          haptic(HapticWeight.selection);
          onChanged(v);
        },
        activeThumbColor: Colors.white,
        activeTrackColor: Color.lerp(fillFor(color), Colors.black, 0.35),
        shape: RoundedRectangleBorder(borderRadius: Radii.rLg),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: TextStyle(color: value ? Colors.white : t.onBgMuted, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), borderRadius: Radii.rMd),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5)),
      );
}

class _Countdown extends StatefulWidget {
  final VoidCallback onDone;
  final Color color;
  final bool mirrored; // shown to both ends of the table (split screen)
  const _Countdown({required this.onDone, required this.color, this.mirrored = false});
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  int _lastStep = -1;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final t = context.tk;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final step = (_c.value * 3).floor().clamp(0, 2);
        if (step != _lastStep) {
          _lastStep = step;
          haptic(HapticWeight.selection);
        }
        final u = (_c.value * 3) - step; // 0..1 within this number
        final label = ['3', '2', '1'][step];
        final scale = reduced ? 1.0 : 1.35 - Curves.easeOut.transform(u) * 0.35;
        final number = Semantics(
          liveRegion: true,
          label: label,
          child: SizedBox(
            width: 190,
            height: 190,
            child: CustomPaint(
              painter: _CountdownRing(reduced ? 1 : 1 - u, widget.color, t.stroke),
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: Text(label, style: TextStyle(color: Colors.white, fontSize: 108, fontWeight: FontWeight.w900, height: 1, shadows: [Shadow(color: widget.color, offset: const Offset(0, 6))])),
                ),
              ),
            ),
          ),
        );
        final ready = Text('GET READY!', style: t.styles.title.copyWith(color: t.accent, fontSize: 22, letterSpacing: 2));
        if (!widget.mirrored) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [number, const SizedBox(height: Space.xl), ready]));
        return Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [RotatedBox(quarterTurns: 2, child: number), ready, number]);
      },
    );
  }
}

class _CountdownRing extends CustomPainter {
  final double f;
  final Color color, track;
  _CountdownRing(this.f, this.color, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(8);
    canvas.drawCircle(r.center, r.width / 2, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawArc(r, 0, 2 * math.pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = track);
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * f, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_CountdownRing o) => o.f != f || o.color != color;
}

/// The end-of-game card: a soft panel in the winner's colour with a glowing badge on top.
class _ResultCard extends StatelessWidget {
  final Color color;
  final String badge;
  final List<Widget> children;
  const _ResultCard({required this.color, required this.badge, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
      Container(
        margin: const EdgeInsets.only(top: 48),
        padding: const EdgeInsets.fromLTRB(Space.l, 62, Space.l, Space.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.3), t.glass]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.reduced(context) ? 1 : 0.3, end: 1),
        duration: Motion.of(context, const Duration(milliseconds: 650)),
        curve: Curves.elasticOut,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.25)!, color, Color.lerp(color, Colors.black, 0.3)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 26)],
          ),
          child: ExcludeSemantics(child: Text(badge, style: const TextStyle(fontSize: 50))),
        ),
      ),
    ]);
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
  Widget build(BuildContext context) {
    final t = context.tk;
    return Stack(children: [
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _ResultCard(color: game.color, badge: newBest ? '🏆' : game.emoji, children: [
              Semantics(
                header: true,
                child: Text(newBest ? 'NEW BEST!' : 'GAME OVER', textAlign: TextAlign.center, style: t.styles.display.copyWith(color: newBest ? t.accent : t.onBg)),
              ),
              Text('${game.emoji} ${game.title}', textAlign: TextAlign.center, style: t.styles.bodyStrong.copyWith(color: t.onBgMuted)),
              const SizedBox(height: Space.xl),
              _CountUp(value: score, style: t.styles.scoreLarge.copyWith(color: Color.lerp(game.color, Colors.white, 0.35), fontSize: 76)),
              Text(game.scoreUnit.toUpperCase(), textAlign: TextAlign.center, style: t.styles.label),
              const SizedBox(height: Space.m),
              if (best != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.s),
                    decoration: BoxDecoration(color: newBest ? fillFor(t.accent) : t.glassStrong, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text(newBest ? '🏆 NEW RECORD' : 'BEST: $best',
                        style: TextStyle(color: newBest ? Brand.ink : t.onBg, fontWeight: FontWeight.w900, fontSize: 16, fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ),
              const SizedBox(height: Space.xl),
              GpButton('PLAY AGAIN', icon: Icons.replay_rounded, onPressed: onAgain),
              const SizedBox(height: Space.m),
              GpButton('ALL GAMES', icon: Icons.grid_view_rounded, outlined: true, onPressed: onExit),
            ]),
          ),
        ),
      ),
      if (newBest && !Motion.reduced(context)) const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }
}

/// A number that counts up to [value] (instantly with reduce motion).
class _CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _CountUp({required this.value, required this.style});
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$value',
        excludeSemantics: true,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: Motion.reduced(context) ? value.toDouble() : 0, end: value.toDouble()),
          duration: Motion.of(context, const Duration(milliseconds: 700)),
          curve: Motion.standard,
          builder: (_, v, __) => Text('${v.round()}', textAlign: TextAlign.center, style: style),
        ),
      );
}

class _Result extends StatelessWidget {
  final LocalGameInfo game;
  final List<GpPlayer> players;
  final List<int> wins;
  final VoidCallback onAgain;
  final VoidCallback onChangePlayers;
  final VoidCallback onExit;
  final bool teams;
  const _Result({required this.game, this.teams = false, required this.players, required this.wins, required this.onAgain, required this.onChangePlayers, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final top = players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
    final leaders = players.where((p) => p.score == top).toList();
    final teamWin = teams && leaders.length == 2;
    final draw = leaders.length > 1 && !teamWin;
    final title = draw
        ? 'DRAW!'
        : teamWin
            ? '${leaders[0].name.toUpperCase()} & ${leaders[1].name.toUpperCase()} WIN!'
            : '${leaders.single.name.toUpperCase()} WINS!';
    // Ranked: standard competition ranking (1, 2, 2, 4).
    final order = [for (var i = 0; i < players.length; i++) i]..sort((a, b) => players[b].score.compareTo(players[a].score));
    int rankOf(int i) => 1 + players.where((p) => p.score > players[i].score).length;
    return Stack(children: [
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _ResultCard(color: draw ? game.color : leaders.first.color, badge: draw ? '🤝' : '🏆', children: [
              Semantics(
                header: true,
                liveRegion: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title, textAlign: TextAlign.center, style: t.styles.display.copyWith(color: draw ? t.onBg : Color.lerp(leaders.first.color, Colors.white, 0.25))),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text('${game.emoji} ${game.title}', textAlign: TextAlign.center, style: t.styles.bodyStrong.copyWith(color: t.onBgMuted)),
              const SizedBox(height: Space.xl),
              if (players.length >= 3) ...[_Podium(players: players, order: order, rankOf: rankOf), const SizedBox(height: Space.l)],
              Text('${game.scoreUnit.toUpperCase()}  ·  🏅 MATCHES WON', textAlign: TextAlign.center, style: t.styles.label),
              const SizedBox(height: Space.s),
              _ScoreTable(players: players, order: order, rankOf: rankOf, wins: wins, highlight: draw ? const {} : leaders.toSet()),
              const SizedBox(height: Space.xl),
              GpButton('PLAY AGAIN', icon: Icons.replay_rounded, onPressed: onAgain),
              const SizedBox(height: Space.m),
              Row(children: [
                Expanded(child: AppButton('PLAYERS', icon: Icons.group_rounded, variant: ButtonVariant.secondary, compact: true, onPressed: onChangePlayers)),
                const SizedBox(width: Space.m),
                Expanded(child: AppButton('ALL GAMES', icon: Icons.grid_view_rounded, variant: ButtonVariant.ghost, compact: true, onPressed: onExit)),
              ]),
            ]),
          ),
        ),
      ),
      if (!draw && !Motion.reduced(context)) const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }
}

/// 1st in the middle (tallest), 2nd left, 3rd right.
class _Podium extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int> order;
  final int Function(int) rankOf;
  const _Podium({required this.players, required this.order, required this.rankOf});

  @override
  Widget build(BuildContext context) {
    final podium = order.take(3).toList();
    final slots = [if (podium.length > 1) podium[1], podium[0], if (podium.length > 2) podium[2]];
    return Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var k = 0; k < slots.length; k++)
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: Motion.reduced(context) ? 1 : 0, end: 1),
            duration: Motion.of(context, Duration(milliseconds: 300 + 150 * k)),
            curve: Motion.emphasized,
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 30), child: child)),
            child: _PodiumStep(player: players[slots[k]], rank: rankOf(slots[k]), height: const <double>[0, 96, 72, 56][rankOf(slots[k]).clamp(1, 3)]),
          ),
        ),
    ]);
  }
}

class _PodiumStep extends StatelessWidget {
  final GpPlayer player;
  final int rank;
  final double height;
  const _PodiumStep({required this.player, required this.rank, required this.height});

  @override
  Widget build(BuildContext context) {
    final medal = const ['', '🥇', '🥈', '🥉'][rank.clamp(1, 3)];
    return Semantics(
      label: 'Place $rank, ${player.name}, ${player.score}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PlayerAvatar(name: player.name, color: player.color, size: rank == 1 ? 52 : 42),
          const SizedBox(height: 4),
          Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.tk.onBg, fontWeight: FontWeight.w900, fontSize: 12.5)),
          const SizedBox(height: 4),
          Container(
            height: height,
            width: double.infinity,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [fillFor(player.color), Color.lerp(fillFor(player.color), Colors.black, 0.4)!]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
            ),
            child: Text(medal, style: const TextStyle(fontSize: 26)),
          ),
        ]),
      ),
    );
  }
}

/// Every player, best first: rank, avatar (colour + shape), name, score and matches won.
class _ScoreTable extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int> order;
  final int Function(int) rankOf;
  final List<int> wins;
  final Set<GpPlayer> highlight;
  const _ScoreTable({required this.players, required this.order, required this.rankOf, required this.wins, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(children: [
      for (final i in order)
        Semantics(
          label: '${rankOf(i)}. ${players[i].name}: ${players[i].score}, ${wins[i]} ${wins[i] == 1 ? 'match' : 'matches'} won',
          excludeSemantics: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: Space.s),
            padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
            decoration: BoxDecoration(
              color: highlight.contains(players[i]) ? players[i].color.withValues(alpha: 0.22) : t.glass,
              borderRadius: Radii.rLg,
              border: Border.all(color: highlight.contains(players[i]) ? t.accent : players[i].color.withValues(alpha: 0.6), width: highlight.contains(players[i]) ? 2.5 : 1.5),
            ),
            child: Row(children: [
              SizedBox(width: 26, child: Text('${rankOf(i)}', style: t.styles.score.copyWith(fontSize: 18, color: t.onBgMuted))),
              PlayerAvatar(name: players[i].name, color: players[i].color, size: 34),
              const SizedBox(width: Space.m),
              Expanded(child: Text(players[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.styles.bodyStrong.copyWith(fontWeight: FontWeight.w900))),
              if (wins[i] > 0) ...[Text('🏅${wins[i]}', style: TextStyle(color: t.onBgMuted, fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(width: Space.m)],
              Text('${players[i].score}', style: t.styles.score.copyWith(fontSize: 24)),
            ]),
          ),
        ),
    ]);
  }
}
