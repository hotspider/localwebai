import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';
import 'composer_attachment_delete_button.dart';

/// 输入区非图片附件（PDF、文档等）横向列表中的单块预览
class ComposerFileAttachmentPreviewItem extends StatelessWidget {
  const ComposerFileAttachmentPreviewItem({
    required this.filename,
    required this.uploading,
    required this.failed,
    this.onRemove,
    this.onRetry,
    super.key,
  });

  final String filename;
  final bool uploading;
  final bool failed;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final label = filename.trim().isEmpty ? '附件' : filename.trim();

    return SizedBox(
      width: 168,
      height: 52,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            decoration: BoxDecoration(
              color: ChatColors.subBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ChatColors.dividerMain),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 36, 10),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 20, color: ChatColors.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ChatColors.textSecondary,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (uploading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.45),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ChatColors.accentBlue),
                    ),
                  ),
                ),
              ),
            ),
          if (failed)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Material(
                  color: const Color.fromRGBO(254, 226, 226, 0.88),
                  child: InkWell(
                    onTap: onRetry,
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, color: Color(0xFFDC2626), size: 20),
                          SizedBox(width: 6),
                          Text(
                            '重试',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: ComposerAttachmentDeleteButton(onTap: onRemove!),
            ),
        ],
      ),
    );
  }
}
