import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ClayButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const ClayButton(this.label, {super.key, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: ClayColors.primary,
        disabledBackgroundColor: ClayColors.primary.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
      label: Text(label, style: ClayTypography.button),
    );
  }
}
