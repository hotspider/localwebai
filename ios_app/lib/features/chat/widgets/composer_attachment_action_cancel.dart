import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

class ComposerAttachmentActionCancel extends StatelessWidget {
  const ComposerAttachmentActionCancel({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          highlightColor: ChatColors.pressBg,
          splashColor: ChatColors.pressBg,
          child: const Center(
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

