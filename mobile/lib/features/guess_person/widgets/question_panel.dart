import 'package:flutter/material.dart';
import '../logic/gp_rules.dart';
import '../models/gp_question.dart';
import 'gp_theme.dart';

/// Category tiles (GENDER, EYE COLOR, HAIR, ...). Tapping one shows its questions;
/// asking returns to the tiles. Asked questions show their YES/NO and can't be re-asked.
class CategoryPanel extends StatefulWidget {
  final List<GpQuestion> questions;
  final bool? Function(GpQuestion) answerFor; // null = not asked yet
  final void Function(GpQuestion)? onAsk;
  const CategoryPanel({super.key, required this.questions, required this.answerFor, this.onAsk});

  @override
  State<CategoryPanel> createState() => _CategoryPanelState();
}

class _CategoryPanelState extends State<CategoryPanel> {
  String? open;

  @override
  Widget build(BuildContext context) {
    final cats = gpCategories.where((c) => widget.questions.any((q) => q.category == c.id)).toList();
    final current = cats.where((c) => c.id == open).firstOrNull;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: current == null ? _tiles(cats) : _options(current),
    );
  }

  Widget _tiles(List<GpCategory> cats) {
    return LayoutBuilder(
      key: const ValueKey('tiles'),
      builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap * 3) / 4;
        return Wrap(alignment: WrapAlignment.center, spacing: gap, runSpacing: gap, children: [
          for (final cat in cats)
            _Tile(
              width: w,
              emoji: cat.emoji,
              label: cat.label,
              asked: widget.questions.where((q) => q.category == cat.id && widget.answerFor(q) != null).length,
              onTap: () => setState(() => open = cat.id),
            ),
        ]);
      },
    );
  }

  Widget _options(GpCategory cat) {
    final qs = widget.questions.where((q) => q.category == cat.id).toList();
    return Container(
      key: ValueKey(cat.id),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(
            tooltip: 'Back to categories',
            onPressed: () => setState(() => open = null),
            icon: const Icon(Icons.arrow_back_rounded, color: GpCoral.tileInk),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Text('${cat.emoji}  ${cat.label}', style: const TextStyle(color: GpCoral.tileInk, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in qs) _option(q),
        ]),
      ]),
    );
  }

  Widget _option(GpQuestion q) {
    final ans = widget.answerFor(q);
    final asked = ans != null;
    final color = !asked ? GpCoral.tileInk : (ans ? GpColors.yes : GpColors.no);
    return Semantics(
      button: !asked,
      label: asked ? '${q.prompt} ${ans ? 'Yes' : 'No'}' : q.prompt,
      child: Material(
        color: asked ? color.withValues(alpha: 0.18) : color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: asked || widget.onAsk == null
              ? null
              : () {
                  widget.onAsk!(q);
                  setState(() => open = null);
                },
          // No alignment here: an aligned Container would stretch to the full row width.
          child: Container(
            constraints: const BoxConstraints(minHeight: 46, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Text(
              asked ? '${q.label} · ${ans ? 'YES' : 'NO'}' : q.label,
              textAlign: TextAlign.center,
              style: TextStyle(color: asked ? Color.lerp(color, Colors.black, 0.35) : Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final double width;
  final String emoji;
  final String label;
  final int asked;
  final VoidCallback onTap;
  const _Tile({required this.width, required this.emoji, required this.label, required this.asked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: width,
        child: Material(
          color: GpCoral.tile,
          borderRadius: BorderRadius.circular(14),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Stack(alignment: Alignment.topCenter, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: const TextStyle(color: GpCoral.tileInk, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ]),
              ),
              if (asked > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: GpCoral.bg, borderRadius: BorderRadius.circular(8)),
                    child: Text('$asked', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ),
            ]),
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
              decoration: BoxDecoration(color: GpCoral.panel, borderRadius: BorderRadius.circular(16)),
              child: Text(emptyHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            )
          : Container(
              key: ValueKey(a.question.id),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: GpCoral.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: a.answer ? GpColors.yes : GpColors.no, width: 3),
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
