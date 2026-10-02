import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/gp_settings.dart';
import '../logic/guess_person_controller.dart';
import '../widgets/game_header.dart';
import '../widgets/gp_sound.dart';
import '../widgets/gp_theme.dart';
import '../widgets/pass_device_view.dart';
import '../widgets/person_card.dart';
import '../widgets/person_grid.dart';
import '../widgets/question_panel.dart';
import '../widgets/result_view.dart';
import '../widgets/score_board.dart';

/// Hosts one match. The controller is created here and disposed with the screen,
/// which also cancels its timer.
class GuessPersonGameScreen extends StatelessWidget {
  final GpSettings settings;
  const GuessPersonGameScreen({super.key, this.settings = const GpSettings()});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GuessPersonController(settings: settings, onSfx: playGpSfx)..startGame(),
      child: const _GameView(),
    );
  }
}

class _GameView extends StatelessWidget {
  const _GameView();

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GpColors.bgTop,
        title: const Text('Leave game?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('Scores for this match will be lost.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('LEAVE', style: TextStyle(color: GpColors.no))),
        ],
      ),
    );
    if (leave == true && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuessPersonController>();
    // guessing <-> finalGuess share one view so the board doesn't flash.
    final viewKey = '${c.round}-${c.phase == GpPhase.finalGuess ? GpPhase.guessing : c.phase}';

    Widget body;
    if (!c.hasEnoughPeople) {
      body = _ErrorView(onBack: () => Navigator.pop(context));
    } else {
      body = switch (c.phase) {
        GpPhase.roundSetup => PassDeviceView(
            title: 'ROUND ${c.round}',
            to: c.chooser,
            icon: Icons.visibility_off_rounded,
            message: "${c.chooser.name}'s turn to choose. Choose one person secretly.",
            buttonLabel: 'START CHOOSING',
            onReady: c.beginSelection,
          ),
        GpPhase.selectingPerson => _SelectView(c: c, onClose: () => _confirmLeave(context)),
        GpPhase.confirmSelection => _ConfirmView(c: c),
        GpPhase.passDevice => PassDeviceView(title: '🔒 PERSON SELECTED', to: c.guesser, onReady: c.switchToGuessing),
        GpPhase.guessing || GpPhase.finalGuess => _GuessView(c: c, onClose: () => _confirmLeave(context)),
        GpPhase.result => ResultView(result: c.result!, players: c.players, lastRound: c.isLastRound, onNext: c.nextRound),
        GpPhase.gameOver => _GameOverView(c: c),
      };
    }

    return PopScope(
      canPop: c.phase == GpPhase.gameOver || !c.hasEnoughPeople,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: Scaffold(
        body: GpBackground(
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(key: ValueKey(viewKey), child: body),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectView extends StatelessWidget {
  final GuessPersonController c;
  final VoidCallback onClose;
  const _SelectView({required this.c, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GameHeader(round: c.round, totalRounds: c.totalRounds, playerName: c.chooser.name, playerColor: c.chooser.color, role: 'CHOOSING', onClose: onClose),
        const SizedBox(height: 10),
        const Text('CHOOSE YOUR PERSON', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const Text('"Pick one character secretly."', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
        Expanded(
          child: PersonGrid(
            people: c.people,
            markFor: (p) => p.id == c.selectedId ? CardMark.selected : CardMark.none,
            badgeFor: (p) => p.id == c.selectedId ? 'SELECTED' : null,
            onTap: (p) => c.selectSecretPerson(p.id),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GpButton('RANDOM', icon: Icons.casino_rounded, outlined: true, onPressed: c.selectRandomPerson)),
          const SizedBox(width: 12),
          Expanded(child: GpButton('CONFIRM', icon: Icons.check_rounded, onPressed: c.selectedId == null ? null : c.requestConfirm)),
        ]),
      ]),
    );
  }
}

class _ConfirmView extends StatelessWidget {
  final GuessPersonController c;
  const _ConfirmView({required this.c});

  @override
  Widget build(BuildContext context) {
    final p = c.selectedPerson;
    if (p == null) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: SizedBox(width: 170, height: 215, child: PersonCard(person: p, mark: CardMark.selected))),
            const SizedBox(height: 24),
            const Text('Are you sure?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${c.guesser.name} will try to find #${p.number} ${p.name}.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 28),
            GpButton('CONFIRM PERSON', icon: Icons.lock_rounded, onPressed: c.confirmSecretPerson),
            const SizedBox(height: 12),
            GpButton('CHANGE', icon: Icons.undo_rounded, outlined: true, onPressed: c.changeSelection),
          ]),
        ),
      ),
    );
  }
}

class _GuessView extends StatelessWidget {
  final GuessPersonController c;
  final VoidCallback onClose;
  const _GuessView({required this.c, required this.onClose});

  void _tap(BuildContext context, int id) {
    if (c.phase == GpPhase.guessing) {
      c.eliminatePerson(id);
      return;
    }
    if (c.chooseGuess(id) == GuessPick.eliminated) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('This person has been eliminated.'), duration: Duration(milliseconds: 1400)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalMode = c.phase == GpPhase.finalGuess;
    final pending = c.pendingGuess;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GameHeader(
          round: c.round,
          totalRounds: c.totalRounds,
          playerName: c.guesser.name,
          playerColor: c.guesser.color,
          role: finalMode ? 'FINAL GUESS' : 'FIND THE PERSON',
          trailing: c.settings.hasTimer ? TimerBadge(c.secondsLeft) : null,
          onClose: onClose,
        ),
        const SizedBox(height: 8),
        // Wrap, not Row: on narrow phones the hint drops to its own line instead of squeezing.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: GpColors.panel, borderRadius: BorderRadius.circular(12)),
              child: Text('PEOPLE LEFT: ${c.peopleLeft} / ${c.people.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            Text(finalMode ? 'Tap your final guess' : 'Tap a person to eliminate them', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        if (finalMode)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: GpColors.accent, borderRadius: BorderRadius.circular(14)),
            child: const Text('WHO IS THE PERSON?', textAlign: TextAlign.center, style: TextStyle(color: GpColors.ink, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        Expanded(
          child: PersonGrid(
            people: c.people,
            markFor: (p) => c.eliminated.contains(p.id) ? CardMark.eliminated : (p.id == c.pendingGuessId ? CardMark.selected : CardMark.none),
            badgeFor: (p) => p.id == c.pendingGuessId ? 'GUESS' : null,
            onTap: (p) => _tap(context, p.id),
          ),
        ),
        const SizedBox(height: 10),
        if (!finalMode) ...[
          AnswerBanner(answer: c.lastAnswer, emptyHint: 'Ask a question below, then eliminate people who don\'t match.'),
          const SizedBox(height: 8),
          QuestionPanel(questions: c.questions, wasAsked: c.wasAsked, onAsk: c.askQuestion),
          const SizedBox(height: 6),
          QuestionHistory(c.history),
          const SizedBox(height: 10),
          GpButton('MAKE FINAL GUESS', icon: Icons.ads_click_rounded, onPressed: c.startFinalGuess),
        ] else if (pending == null)
          GpButton('CANCEL', icon: Icons.close_rounded, outlined: true, onPressed: c.cancelFinalGuess)
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: GpColors.panel, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              SizedBox(width: 74, height: 94, child: PersonCard(person: pending)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Is this your final guess?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  GpButton('YES, FINAL GUESS', color: GpColors.yes, textColor: Colors.white, onPressed: c.makeFinalGuess),
                  const SizedBox(height: 8),
                  GpButton('CANCEL', outlined: true, onPressed: c.cancelFinalGuess),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _GameOverView extends StatelessWidget {
  final GuessPersonController c;
  const _GameOverView({required this.c});

  @override
  Widget build(BuildContext context) {
    final leaders = c.leaders;
    final headline = c.isDraw ? '🤝 DRAW!' : '${leaders.first.name.toUpperCase()} WINS!';
    return Stack(children: [
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('🏆', textAlign: TextAlign.center, style: TextStyle(fontSize: 72)),
              const Text('GAME OVER', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(headline, textAlign: TextAlign.center, style: const TextStyle(color: GpColors.accent, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              const Text('FINAL SCORE', textAlign: TextAlign.center, style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              ScoreBoard(players: c.players, large: true, highlight: c.isDraw ? const {} : leaders.toSet()),
              const SizedBox(height: 32),
              GpButton('PLAY AGAIN', icon: Icons.replay_rounded, onPressed: c.resetGame),
              const SizedBox(height: 12),
              GpButton('MAIN MENU', icon: Icons.home_rounded, outlined: true, onPressed: () => Navigator.pop(context)),
            ]),
          ),
        ),
      ),
      if (!c.isDraw) const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onBack;
  const _ErrorView({required this.onBack});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Not enough characters to play.', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 16),
            GpButton('BACK', onPressed: onBack),
          ]),
        ),
      );
}
