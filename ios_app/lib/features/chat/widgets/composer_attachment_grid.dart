import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../models/attachment.dart';
import 'composer_file_attachment_preview_item.dart';
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
    this.pendingIdsWithoutMetadata = const [],
    super.key,
  });

  /// draft: {_localId, bytes, status, error, contentType}
  final List<dynamic> drafts;

  /// uploaded: AttachmentItem
  final List<dynamic> uploaded;

  /// 已加入待发送但尚未出现在 [uploaded] / 会话列表中的 id（刷新间隙时仍显示占位）
  final List<String> pendingIdsWithoutMetadata;

  final Uint8List? Function(String attachmentId) bytesForUploadedId;
  final void Function(String localId) onRemoveDraft;
  final void Function(String localId) onRetryDraft;
  final void Function(String attachmentId) onRemoveUploaded;
  final bool disableActions;

  static bool _isImageMime(String? raw) =>
      (raw ?? '').toString().toLowerCase().startsWith('image/');

  @override
  Widget build(BuildContext context) {
    final draftImages = drafts.where((d) => _isImageMime(d.contentType as String?)).toList();
    final draftFiles = drafts.where((d) => !_isImageMime(d.contentType as String?)).toList();
    final uploadedTyped = uploaded.whereType<AttachmentItem>().toList();
    final uploadedImages = uploadedTyped.where((a) => _isImageMime(a.contentType)).toList();
    final uploadedFiles = uploadedTyped.where((a) => !_isImageMime(a.contentType)).toList();

    final imageCount = draftImages.length + uploadedImages.length;
    final fileCount = draftFiles.length + uploadedFiles.length;
    if (imageCount == 0 && fileCount == 0) return const SizedBox.shrink();

    final imageItems = <Widget>[];
    for (final d in draftImages) {
      final status = d.status.toString();
      final uploading = status.contains('uploading');
      final failed = status.contains('failed');
      imageItems.add(
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
      final id = a.id;
      imageItems.add(
        ComposerAttachmentPreviewItem(
          bytes: id.isEmpty ? null : bytesForUploadedId(id),
          uploading: false,
          failed: false,
          onRemove: (disableActions || id.isEmpty) ? null : () => onRemoveUploaded(id),
        ),
      );
    }

    final fileItems = <Widget>[];
    for (final d in draftFiles) {
      final status = d.status.toString();
      final uploading = status.contains('uploading');
      final failed = status.contains('failed');
      final name = (d.filename ?? '').toString();
      fileItems.add(
        ComposerFileAttachmentPreviewItem(
          filename: name,
          uploading: uploading,
          failed: failed,
          onRemove: disableActions ? null : () => onRemoveDraft(d.localId as String),
          onRetry: (!disableActions && failed) ? () => onRetryDraft(d.localId as String) : null,
        ),
      );
    }
    for (final a in uploadedFiles) {
      final id = a.id;
      fileItems.add(
        ComposerFileAttachmentPreviewItem(
          filename: a.filename,
          uploading: false,
          failed: false,
          onRemove: (disableActions || id.isEmpty) ? null : () => onRemoveUploaded(id),
        ),
      );
    }
    for (final id in pendingIdsWithoutMetadata) {
      if (id.isEmpty) continue;
      fileItems.add(
        ComposerFileAttachmentPreviewItem(
          filename: '附件信息同步中…',
          uploading: true,
          failed: false,
          onRemove: disableActions ? null : () => onRemoveUploaded(id),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageItems.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: imageItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => imageItems[i],
            ),
          ),
        if (imageItems.isNotEmpty && fileItems.isNotEmpty) const SizedBox(height: 10),
        if (fileItems.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: fileItems.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => fileItems[i],
            ),
          ),
      ],
    );
  }
}
