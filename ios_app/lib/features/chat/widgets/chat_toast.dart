import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/chat_colors.dart';

void showChatToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: ChatColors.textOnAccent, fontSize: 14, height: 1.35),
      ),
      backgroundColor: ChatColors.textPrimary.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      duration: const Duration(seconds: 2),
    ),
  );
}
