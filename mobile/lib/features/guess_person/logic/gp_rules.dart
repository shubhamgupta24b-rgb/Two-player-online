import '../models/gp_question.dart';
import '../models/person.dart';

enum RoundOutcome { correct, wrong, timeUp }

/// Scoring is kept out of the UI and controller so it can change in one place.
int pointsFor(RoundOutcome o) => o == RoundOutcome.correct ? 1 : 0;

const _hairOrder = ['black', 'brown', 'blonde', 'red'];
const _shirtOrder = ['red', 'blue', 'green', 'yellow'];
const _accessoryOrder = ['earrings', 'necklace', 'bowtie'];

List<String> _distinct(Iterable<String> values, List<String> order) {
  final list = values.toSet().toList();
  int rank(String v) => order.contains(v) ? order.indexOf(v) : order.length;
  list.sort((a, b) => rank(a).compareTo(rank(b)));
  return list;
}

/// Builds the question list from the people actually on the board. Questions that
/// cannot split the board (everyone yes, or everyone no) are dropped.
List<GpQuestion> buildQuestions(List<Person> people) {
  final all = <GpQuestion>[
    GpQuestion('glasses', 'GLASSES', 'Does the person have glasses?', (p) => p.hasGlasses),
    GpQuestion('beard', 'BEARD', 'Does the person have a beard?', (p) => p.hasBeard),
    GpQuestion('hat', 'HAT', 'Is the person wearing a hat?', (p) => p.hasHat),
    GpQuestion('long_hair', 'LONG HAIR', 'Does the person have long hair?', (p) => p.hasLongHair),
    GpQuestion('male', 'MALE', 'Is the person male?', (p) => p.gender == Gender.male),
    GpQuestion('female', 'FEMALE', 'Is the person female?', (p) => p.gender == Gender.female),
    for (final c in _distinct(people.map((p) => p.shirtColor), _shirtOrder))
      GpQuestion('shirt_$c', '${c.toUpperCase()} SHIRT', 'Is the person wearing $c?', (p) => p.shirtColor == c),
    for (final c in _distinct(people.map((p) => p.hairColor), _hairOrder))
      GpQuestion('hair_$c', '${c.toUpperCase()} HAIR', 'Does the person have $c hair?', (p) => p.hairColor == c),
    GpQuestion('accessory', 'ACCESSORY', 'Is the person wearing an accessory?', (p) => p.hasAccessory),
    for (final a in _distinct(people.where((p) => p.hasAccessory).map((p) => p.accessory), _accessoryOrder))
      GpQuestion('acc_$a', a.toUpperCase(), 'Is the person wearing ${a == 'earrings' ? 'earrings' : 'a $a'}?', (p) => p.accessory == a),
  ];
  return all.where((q) {
    final yes = people.where(q.test).length;
    return yes > 0 && yes < people.length;
  }).toList();
}
