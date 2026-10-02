import 'package:flutter/material.dart';

class GpColors {
  static const bgTop = Color(0xFF241A5C);
  static const bgBottom = Color(0xFF120D33);
  static const card = Color(0xFFFFF8EC);
  static const ink = Color(0xFF1E1B3A);
  static const accent = Color(0xFFFFC93C);
  static const yes = Color(0xFF2ECC71);
  static const no = Color(0xFFFF5E5B);
  static const muted = Color(0xFFB9B3E0);
  static const panel = Color(0x26FFFFFF);
  static const portraitBgs = [
    Color(0xFFFFD6A5), Color(0xFFCAFFBF), Color(0xFF9BF6FF), Color(0xFFBDB2FF),
    Color(0xFFFFC6FF), Color(0xFFFDFFB6), Color(0xFFA0C4FF), Color(0xFFFFADAD),
  ];
}

/// Full-screen gradient used behind every Guess the Person screen.
class GpBackground extends StatelessWidget {
  final Widget child;
  const GpBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [GpColors.bgTop, GpColors.bgBottom]),
        ),
        child: child,
      );
}

/// Chunky rounded party-game button with a pressed-down shadow.
class GpButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool outlined;
  const GpButton(this.label,
      {super.key, this.onPressed, this.color = GpColors.accent, this.textColor = GpColors.ink, this.icon, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = outlined ? Colors.transparent : (enabled ? color : Colors.white24);
    final fg = outlined ? Colors.white : (enabled ? textColor : Colors.white54);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.7,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: outlined || !enabled ? null : [BoxShadow(color: Color.lerp(color, Colors.black, 0.45)!, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: outlined ? const BorderSide(color: Colors.white54, width: 2) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (icon != null) ...[Icon(icon, color: fg, size: 22), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.8)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Coloured pill showing a player and what they are doing (not colour-only: the name is always shown).
class PlayerTag extends StatelessWidget {
  final String name;
  final Color color;
  final String? role;
  const PlayerTag({super.key, required this.name, required this.color, this.role});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person, size: 18, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(name.toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
          if (role != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text('· $role',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ]),
      );
}
