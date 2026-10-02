import 'package:flutter/material.dart';
import '../models/gp_question.dart';
import 'gp_theme.dart';

/// Two rows of question chips that scroll sideways. Asked questions are disabled
/// and marked "✓", so a question can never be asked twice.
class QuestionPanel extends StatelessWidget {
  final List<GpQuestion> questions;
  final bool Function(GpQuestion) wasAsked;
  final void Function(GpQuestion)? onAsk;
  const QuestionPanel({super.key, required this.questions, required this.wasAsked, this.onAsk});

  @override
  Widget build(BuildContext context) {
    final half = (questions.length / 2).ceil();
    Widget row(List<GpQuestion> qs) => Row(children: [for (final q in qs) _chip(q)]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('ASK A QUESTION', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          row(questions.take(half).toList()),
          const SizedBox(height: 6),
          row(questions.skip(half).toList()),
        ]),
      ),
    ]);
  }

  Widget _chip(GpQuestion q) {
    final asked = wasAsked(q);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        enabled: !asked,
        label: asked ? '${q.prompt} Already asked' : q.prompt,
        child: Material(
          color: asked ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: asked || onAsk == null ? null : () => onAsk!(q),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(asked ? '✓ ${q.label}' : q.label,
                  style: TextStyle(color: asked ? Colors.white54 : GpColors.ink, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big YES/NO answer for the last question (text + icon, not colour alone).
class AnswerBanner extends StatelessWidget {
  final AskedQuestion? answer;
  final String emptyHint;
  const AnswerBanner({super.key, required this.answer, required this.emptyHint});

  @override
  Widget build(BuildContext context) {
    final a = answer;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim), child: child),
      ),
      child: a == null
          ? Container(
              key: const ValueKey('hint'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(color: GpColors.panel, borderRadius: BorderRadius.circular(14)),
              child: Text(emptyHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            )
          : Container(
              key: ValueKey(a.question.id),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: (a.answer ? GpColors.yes : GpColors.no).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: a.answer ? GpColors.yes : GpColors.no, width: 2),
              ),
              child: Row(children: [
                Expanded(child: Text(a.question.prompt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
                Icon(a.answer ? Icons.check_circle : Icons.cancel, color: a.answer ? GpColors.yes : GpColors.no),
                const SizedBox(width: 4),
                Text(a.answer ? 'YES' : 'NO', style: TextStyle(color: a.answer ? GpColors.yes : GpColors.no, fontWeight: FontWeight.w900, fontSize: 22)),
              ]),
            ),
    );
  }
}

/// Compact scrolling history: "Glasses → YES".
class QuestionHistory extends StatelessWidget {
  final List<AskedQuestion> history;
  const QuestionHistory(this.history, {super.key});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 30,
      // Newest first, so the latest clue is always visible without scrolling.
      child: ListView(scrollDirection: Axis.horizontal, children: [
        const Center(child: Text('ASKED:', style: TextStyle(color: GpColors.muted, fontWeight: FontWeight.w800, fontSize: 11))),
        for (final h in history.reversed)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: GpColors.panel, borderRadius: BorderRadius.circular(12)),
            child: Text('${h.question.label} → ${h.answer ? 'YES' : 'NO'}',
                style: TextStyle(color: h.answer ? GpColors.yes : GpColors.no, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
      ]),
    );
  }
}
