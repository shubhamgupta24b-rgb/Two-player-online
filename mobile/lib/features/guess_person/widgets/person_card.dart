import 'package:flutter/material.dart';
import '../models/person.dart';
import 'gp_theme.dart';
import 'person_portrait.dart';

enum CardMark { none, selected, eliminated, correct, wrong }

class PersonCard extends StatelessWidget {
  final Person person;
  final CardMark mark;
  final VoidCallback? onTap;
  final String? badge; // e.g. "SELECTED" shown on the card, never colour-only
  const PersonCard({super.key, required this.person, this.mark = CardMark.none, this.onTap, this.badge});

  static const _grey = ColorFilter.matrix(<double>[
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final out = mark == CardMark.eliminated;
    final border = switch (mark) {
      CardMark.selected => GpColors.accent,
      CardMark.correct => GpColors.yes,
      CardMark.wrong => GpColors.no,
      _ => Colors.transparent,
    };
    final state = switch (mark) {
      CardMark.eliminated => ', eliminated',
      CardMark.selected => ', selected',
      _ => '',
    };

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: GpColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 3),
        boxShadow: [
          if (mark == CardMark.selected) BoxShadow(color: GpColors.accent.withValues(alpha: 0.6), blurRadius: 14),
          const BoxShadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 4),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Column(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              out ? ColorFiltered(colorFilter: _grey, child: PersonPortrait(person)) : PersonPortrait(person),
              if (out) const CustomPaint(painter: _CrossPainter()),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('#${person.number} ${person.name}',
                style: TextStyle(
                  color: GpColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  decoration: out ? TextDecoration.lineThrough : null,
                )),
          ),
        ),
      ]),
    );

    card = AnimatedOpacity(duration: const Duration(milliseconds: 220), opacity: out ? 0.45 : 1, child: card);
    if (badge != null) {
      card = Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: card),
        Positioned(
          top: -6,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: border == Colors.transparent ? GpColors.accent : border, borderRadius: BorderRadius.circular(8)),
              child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: GpColors.ink)),
            ),
          ),
        ),
      ]);
    }

    return Semantics(
      button: onTap != null,
      label: 'Person ${person.number} ${person.name}$state',
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: mark == CardMark.selected ? 1.05 : 1.0,
        child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.shortestSide * 0.18;
    final p = Paint()
      ..color = GpColors.no
      ..strokeWidth = size.shortestSide * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(pad, pad), Offset(size.width - pad, size.height - pad), p);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(pad, size.height - pad), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
