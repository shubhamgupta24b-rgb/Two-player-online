class GpSettings {
  static const roundOptions = [3, 5, 10];
  static const timerOptions = [0, 15, 30, 60];
  static const peopleOptions = [16, 24, 32];

  final int rounds;
  final int timerSeconds; // 0 = no timer
  bool get hasTimer => timerSeconds > 0;
  final int peopleCount; // capped at the dataset size
  final bool autoEliminate;
  final bool sound;

  const GpSettings({
    this.rounds = 5,
    this.timerSeconds = 0,
    this.peopleCount = 32,
    this.autoEliminate = false,
    this.sound = true,
  });

  // A future "Quick Mode" is just another preset, e.g.
  // const GpSettings(rounds: 3, timerSeconds: 15, peopleCount: 12).

  GpSettings copyWith({int? rounds, int? timerSeconds, int? peopleCount, bool? autoEliminate, bool? sound}) => GpSettings(
        rounds: rounds ?? this.rounds,
        timerSeconds: timerSeconds ?? this.timerSeconds,
        peopleCount: peopleCount ?? this.peopleCount,
        autoEliminate: autoEliminate ?? this.autoEliminate,
        sound: sound ?? this.sound,
      );
}
