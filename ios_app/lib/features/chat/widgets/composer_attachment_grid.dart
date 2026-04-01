import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'composer_attachment_preview_item.dart';

class ComposerAttachmentPreviewGrid extends StatelessWidget {
  const ComposerAttachmentPreviewGrid({
    required this.drafts,
    required this.uploaded,
    required this.bytesForUploadedId,
    required this.onRemoveDraft,
    required this.onRetryDraft,
    required this.onRemoveUploaded,
    required this.disableActions,
    super.key,
  });

  /// draft: {_localId, bytes, status, error, contentType}
  final List<dynamic> drafts;

  /// uploaded: AttachmentItem
  final List<dynamic> uploaded;

  final Uint8List? Function(String attachmentId) bytesForUploadedId;
  final void Function(String localId) onRemoveDraft;
  final void Function(String localId) onRetryDraft;
  final void Function(String attachmentId) onRemoveUploaded;
  final bool disableActions;

  @override
  Widget build(BuildContext context) {
    final draftImages = drafts.where((d) => (d.contentType ?? '').toString().toLowerCase().startsWith('image/')).toList();
    final uploadedImages =
        uploaded.where((a) => (a.contentType ?? '').toString().toLowerCase().startsWith('image/')).toList();

    final total = draftImages.length + uploadedImages.length;
    if (total == 0) return const SizedBox.shrink();

    final items = <Widget>[];

    for (final d in draftImages) {
      final status = d.status.toString();
      final uploading = status.contains('uploading');
      final failed = status.contains('failed');
      items.add(
        ComposerAttachmentPreviewItem(
          bytes: d.bytes as Uint8List?,
          uploading: uploading,
          failed: failed,
          onRemove: disableActions ? null : () => onRemoveDraft(d.localId as String),
          onRetry: (!disableActions && failed) ? () => onRetryDraft(d.localId as String) : null,
        ),
      );
    }

    for (final a in uploadedImages) {
      final id = (a.id ?? '').toString();
      items.add(
        ComposerAttachmentPreviewItem(
          bytes: id.isEmpty ? null : bytesForUploadedId(id),
          uploading: false,
          failed: false,
          onRemove: (disableActions || id.isEmpty) ? null : () => onRemoveUploaded(id),
        ),
      );
    }

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, i) => const SizedBox(width: 10),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}
