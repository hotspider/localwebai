import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 设置页等分组列表的外层容器
class AppGroupedSurface extends StatelessWidget {
  const AppGroupedSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
