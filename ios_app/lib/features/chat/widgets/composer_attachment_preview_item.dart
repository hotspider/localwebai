import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';
import 'composer_attachment_delete_button.dart';
import 'composer_attachment_preview_states.dart';

class ComposerAttachmentPreviewItem extends StatelessWidget {
  const ComposerAttachmentPreviewItem({
    required this.bytes,
    required this.onRemove,
    this.uploading = false,
    this.failed = false,
    this.onRetry,
    super.key,
  });

  final Uint8List? bytes;
  final VoidCallback? onRemove;
  final bool uploading;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            decoration: BoxDecoration(
              color: ChatColors.imageTileBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: bytes == null
                  ? const Center(child: Icon(Icons.image_outlined, color: ChatColors.placeholder, size: 26))
                  : Image.memory(bytes!, fit: BoxFit.cover),
            ),
          ),
          if (uploading) const Positioned.fill(child: ComposerAttachmentUploadingState()),
          if (failed) Positioned.fill(child: ComposerAttachmentFailedState(onRetry: onRetry)),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: ComposerAttachmentDeleteButton(onTap: onRemove!),
            ),
        ],
      ),
    );
  }
}

