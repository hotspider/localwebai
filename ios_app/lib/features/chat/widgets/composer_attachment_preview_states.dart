import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

class ComposerAttachmentUploadingState extends StatelessWidget {
  const ComposerAttachmentUploadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: ChatColors.accentBlue),
        ),
      ),
    );
  }
}

class ComposerAttachmentFailedState extends StatelessWidget {
  const ComposerAttachmentFailedState({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(254, 226, 226, 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, color: Color(0xFFDC2626), size: 26),
            const SizedBox(height: 6),
            const Text(
              '上传失败，请重试',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626), height: 1.1),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('重试', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

