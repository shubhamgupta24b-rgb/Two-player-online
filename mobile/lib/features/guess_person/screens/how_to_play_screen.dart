import 'package:flutter/material.dart';
import '../widgets/gp_theme.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _steps = [
    (Icons.touch_app_rounded, 'One player secretly chooses a person.'),
    (Icons.swap_horiz_rounded, 'Pass the device to the other player.'),
    (Icons.quiz_rounded, 'Ask questions and use the YES / NO clues to eliminate people.'),
    (Icons.ads_click_rounded, 'Select your final guess (before the timer runs out, if one is set).'),
    (Icons.star_rounded, 'Correct guesses earn 1 point. Roles switch every round.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CoralBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('HOW TO PLAY', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  for (var i = 0; i < _steps.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: GpCoral.panel, borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: GpColors.accent,
                          child: Text('${i + 1}', style: const TextStyle(color: GpColors.ink, fontWeight: FontWeight.w900, fontSize: 18)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('STEP ${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(_steps[i].$2, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        Icon(_steps[i].$1, color: Colors.white70),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  GpButton('GOT IT', icon: Icons.check_rounded, onPressed: () => Navigator.pop(context)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
