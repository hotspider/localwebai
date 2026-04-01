import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

class MessageActions extends StatelessWidget {
  const MessageActions({required this.onCopy, super.key});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onCopy,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.only(left: 0, top: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: ChatColors.textTertiary,
      ),
      icon: Icon(Icons.copy_all_rounded, size: 16, color: ChatColors.textTertiary),
      label: const Text('复制内容', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}
