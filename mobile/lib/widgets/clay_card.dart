import 'package:flutter/material.dart';
import '../theme/clay_decoration.dart';

class ClayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  const ClayCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 24, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: ClayDecoration.surface(radius: radius, color: color ?? Colors.white),
      padding: padding,
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}
