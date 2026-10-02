import 'dart:math';
import 'package:flutter/material.dart';

/// A tappable die. Each new [rollId] plays a short tumble before settling on [value].
class RollingDice extends StatelessWidget {
  final int value; // 1-6
  final int rollId;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  const RollingDice({super.key, required this.value, required this.rollId, required this.color, this.size = 64, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap != null ? 'Roll the dice' : 'Dice shows $value',
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(rollId),
          tween: Tween(begin: rollId == 0 ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOut,
          builder: (context, t, _) {
            // While tumbling, flash random-looking faces; settle on the real one.
            final face = t < 1 ? ((rollId * 7 + (t * 12).floor() * 5) % 6) + 1 : value;
            return Transform.rotate(
              angle: (1 - t) * pi * 2.5,
              child: Transform.scale(scale: 1 + sin(t * pi) * 0.15, child: DiceFace(value: face, size: size, glow: onTap != null ? color : null)),
            );
          },
        ),
      ),
    );
  }
}

class DiceFace extends StatelessWidget {
  final int value;
  final double size;
  final Color? glow;
  const DiceFace({super.key, required this.value, this.size = 64, this.glow});

  static const _pips = {
    1: [(0.5, 0.5)],
    2: [(0.27, 0.27), (0.73, 0.73)],
    3: [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)],
    4: [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)],
    5: [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)],
    6: [(0.27, 0.25), (0.73, 0.25), (0.27, 0.5), (0.73, 0.5), (0.27, 0.75), (0.73, 0.75)],
  };

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFE2E4F0)]),
          borderRadius: BorderRadius.circular(size * 0.2),
          boxShadow: [
            const BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
            if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.8), blurRadius: 14, spreadRadius: 1),
          ],
        ),
        child: Stack(children: [
          for (final (x, y) in _pips[value.clamp(1, 6)]!)
            Positioned(
              left: size * x - size * 0.09,
              top: size * y - size * 0.09,
              child: Container(width: size * 0.18, height: size * 0.18, decoration: BoxDecoration(shape: BoxShape.circle, color: value == 1 ? const Color(0xFFE53935) : const Color(0xFF1E1B3A))),
            ),
        ]),
      );
}
