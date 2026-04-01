import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
