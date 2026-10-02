import 'package:flutter/material.dart';
import '../models/person.dart';
import 'person_card.dart';

/// Responsive grid: 4 columns on phones, 5-6 on tablets. Card height is derived from
/// the space available so the whole board fits without scrolling when possible.
class PersonGrid extends StatelessWidget {
  final List<Person> people;
  final CardMark Function(Person) markFor;
  final void Function(Person)? onTap;
  final String? Function(Person)? badgeFor;
  const PersonGrid({super.key, required this.people, required this.markFor, this.onTap, this.badgeFor});

  static const _gap = 6.0;

  /// Picks the column count (4-8) that gives the biggest cards for this many people
  /// in this space, preferring cards about 1.2x taller than wide.
  static int columnsFor(int count, double width, double height) {
    var best = 4;
    var bestSize = 0.0;
    for (var cols = 4; cols <= 8; cols++) {
      final rows = (count / cols).ceil();
      final cellW = (width - _gap * (cols - 1)) / cols;
      final cellH = height.isFinite ? (height - _gap * (rows - 1)) / rows : cellW * 1.2;
      final size = cellW < cellH / 1.2 ? cellW : cellH / 1.2;
      if (size > bestSize + 0.5) {
        best = cols;
        bestSize = size;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const Center(child: Text('No characters available', style: TextStyle(color: Colors.white70)));
    }
    return LayoutBuilder(builder: (context, c) {
      const gap = _gap;
      final h = c.maxHeight - 8; // top padding
      final cols = columnsFor(people.length, c.maxWidth, h);
      final rows = (people.length / cols).ceil();
      final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
      final cellH = c.maxHeight.isFinite ? (h - gap * (rows - 1)) / rows : cellW * 1.2;
      // Too short a cell makes portraits unreadable: clamp, and let the grid scroll instead.
      final ratio = (cellW / cellH).clamp(0.6, 1.0);
      return GridView.builder(
        padding: const EdgeInsets.only(top: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: gap, mainAxisSpacing: gap, childAspectRatio: ratio),
        itemCount: people.length,
        itemBuilder: (_, i) {
          final p = people[i];
          return PersonCard(
            key: ValueKey(p.id),
            person: p,
            mark: markFor(p),
            badge: badgeFor?.call(p),
            onTap: onTap == null ? null : () => onTap!(p),
          );
        },
      );
    });
  }
}
