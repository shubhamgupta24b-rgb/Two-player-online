import 'package:flutter/services.dart';
import '../logic/guess_person_controller.dart';

/// The app has no audio package, so feedback uses the platform click sound and
/// haptics. Every call is fire-and-forget and failures are swallowed.
void playGpSfx(GpSfx s) {
  switch (s) {
    case GpSfx.select:
    case GpSfx.question:
      SystemSound.play(SystemSoundType.click).ignore();
    case GpSfx.eliminate:
      HapticFeedback.selectionClick().ignore();
    case GpSfx.timerWarning:
      HapticFeedback.lightImpact().ignore();
    case GpSfx.correct:
    case GpSfx.gameOver:
      SystemSound.play(SystemSoundType.click).ignore();
      HapticFeedback.mediumImpact().ignore();
    case GpSfx.wrong:
      HapticFeedback.heavyImpact().ignore();
  }
}
