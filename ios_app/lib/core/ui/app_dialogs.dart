import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  bool isDanger = false,
}) {
  final platform = Theme.of(context).platform;
  final isIOS = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isIOS) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            message,
            style: const TextStyle(color: CupertinoColors.secondaryLabel, height: 1.35),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            isDestructiveAction: isDanger,
            isDefaultAction: !isDanger,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDanger ? AppColors.danger : AppColors.primary,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
