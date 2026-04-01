import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 统一底部弹层：把手、圆角、安全区（可选覆盖色，供聊天等产品页使用）
class AppSheetShell extends StatelessWidget {
  const AppSheetShell({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.backgroundColor,
    this.panelBorderColor,
    this.titleColor,
    this.subtitleColor,
    this.handleColor,
    this.shadowColor,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Color? backgroundColor;
  final Color? panelBorderColor;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? handleColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final bg = backgroundColor ?? AppColors.surface;
    final border = panelBorderColor ?? AppColors.border;
    final tCol = titleColor ?? AppColors.textPrimary;
    final sCol = subtitleColor ?? AppColors.textMuted;
    final hCol = handleColor ?? AppColors.border;
    final sh = shadowColor ?? AppColors.textPrimary.withValues(alpha: 0.06);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: border),
          boxShadow: AppShadow.sheetFloating(color: sh),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hCol,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: tCol,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: sCol, height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
