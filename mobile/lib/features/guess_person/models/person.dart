enum Gender { male, female }

/// One character on the board. Pure data: per-round state such as "eliminated"
/// lives in the controller so the same Person can be reused across rounds.
class Person {
  final int id;
  final String name;
  final Gender gender;
  final bool hasGlasses;
  final bool hasBeard;
  final bool hasHat;
  final bool hasLongHair;
  final String hairColor; // black | brown | blonde | red
  final String shirtColor; // red | blue | green | yellow
  final String skinTone; // light | tan | dark
  final String accessory; // none | earrings | necklace | bowtie

  /// Optional image asset. When null (or missing on disk) the portrait is drawn in code.
  final String? image;

  const Person({
    required this.id,
    required this.name,
    required this.gender,
    required this.hasGlasses,
    required this.hasBeard,
    required this.hasHat,
    required this.hasLongHair,
    required this.hairColor,
    required this.shirtColor,
    required this.skinTone,
    this.accessory = 'none',
    this.image,
  });

  bool get hasShortHair => !hasLongHair;
  bool get hasAccessory => accessory != 'none';
  String get number => id.toString().padLeft(2, '0');

  /// Never print attributes: this keeps the secret person out of debug logs.
  @override
  String toString() => 'Person#$number';
}
