import 'package:flutter/material.dart';

import '../../../models/chat_message.dart';
import '../../../models/attachment.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/chat_colors.dart';

class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({
    required this.message,
    required this.attachments,
    this.onRetry,
    /// 请求体已发出（可开始展示「生成回复」）；为 false 时仅展示「发送中」
    this.showOutboundSendingRow = true,
    this.onOpenAttachment,
    super.key,
  });

  final ChatMessage message;
  final List<dynamic> attachments;
  final VoidCallback? onRetry;
  final bool showOutboundSendingRow;
  final void Function(AttachmentItem item)? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final typed = attachments.whereType<AttachmentItem>().toList();
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ChatColors.userBubbleBg,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.bubbleUser)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (typed.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  for (final a in typed)
                    _UserAttachmentThumb(
                      filename: a.filename,
                      contentType: a.contentType,
                      onTap: onOpenAttachment == null ? null : () => onOpenAttachment!(a),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            SelectableText(
              message.contentText,
              style: const TextStyle(
                color: ChatColors.textPrimary,
                height: 1.55,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (message.sendState == ChatMessageSendState.failed) ...[
              const SizedBox(height: 8),
              _SendStateRow(
                state: message.sendState,
                error: message.sendError,
                onRetry: onRetry,
              ),
            ] else if (message.sendState == ChatMessageSendState.sending && showOutboundSendingRow) ...[
              const SizedBox(height: 8),
              _SendStateRow(
                state: message.sendState,
                error: message.sendError,
                onRetry: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SendStateRow extends StatelessWidget {
  const _SendStateRow({required this.state, required this.error, required this.onRetry});

  final ChatMessageSendState state;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state == ChatMessageSendState.sending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ChatColors.textTertiary)),
          SizedBox(width: 8),
          Text('发送中…', style: TextStyle(fontSize: 12, color: ChatColors.textTertiary, height: 1.1)),
        ],
      );
    }
    final detail = error?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: ChatColors.error),
            const SizedBox(width: 6),
            const Text(
              '发送失败',
              style: TextStyle(fontSize: 12, color: ChatColors.error, height: 1.1, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: ChatColors.error,
              ),
              child: const Text('重试', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        if (detail != null && detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: SelectableText(
                detail,
                style: const TextStyle(fontSize: 11, color: ChatColors.textTertiary, height: 1.35),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserAttachmentThumb extends StatelessWidget {
  const _UserAttachmentThumb({
    required this.filename,
    required this.contentType,
    this.onTap,
  });

  final String filename;
  final String contentType;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isImage = contentType.toLowerCase().startsWith('image/');
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
          size: 18,
          color: ChatColors.textTertiary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            filename.isEmpty ? (isImage ? '图片' : '附件') : filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: ChatColors.textSecondary, height: 1.05, fontWeight: FontWeight.w600),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.open_in_new_rounded, size: 14, color: ChatColors.textMuted.withValues(alpha: 0.85)),
        ],
      ],
    );

    return Material(
      color: ChatColors.subBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ChatColors.dividerMain),
          ),
          child: child,
        ),
      ),
    );
  }
}
