import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PastelBackground extends StatelessWidget {
  final Widget child;
  const PastelBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ClayColors.backgroundTop, ClayColors.backgroundMid, ClayColors.backgroundBottom],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: -40, left: -25, child: _Blob(size: 140, color: Color(0x55FFC5DE))),
          const Positioned(top: 120, right: -20, child: _Blob(size: 108, color: Color(0x55BFD8FF))),
          const Positioned(bottom: 90, left: -28, child: _Blob(size: 124, color: Color(0x55D8CCFF))),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
