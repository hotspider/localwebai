import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/chat_colors.dart';
import '../chat_controller.dart';
import 'composer_attachment_grid.dart';
import 'composer_attachment_sheet.dart';
import 'composer_bottom_row.dart';

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.controller,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final FocusNode _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final v = widget.controller.text.trim().isNotEmpty;
    if (v == _hasText) return;
    setState(() => _hasText = v);
  }

  Future<void> _openAddMenu(BuildContext context) async {
    final chat = context.read<ChatController>();
    await showComposerAttachmentSheet(
      context,
      onCamera: () async => chat.uploadFromCamera(),
      onGallery: () async => chat.uploadFromGallery(),
      onUploadText: () async => chat.pickFileAndUpload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final pendingUploaded = chat.pendingAttachmentIds
        .map((id) => chat.attachments.where((a) => a.id == id).toList().firstOrNull)
        .where((x) => x != null)
        .cast<dynamic>()
        .toList();
    final pendingIdsWithoutMetadata = chat.pendingAttachmentIds
        .where((id) => id.isNotEmpty && chat.attachments.every((a) => a.id != id))
        .toList();

    // 与 pendingAttachmentIds 对齐：避免仅「服务端列表尚未同步」时整块预览区不显示
    final hasSendableAttachment = chat.pendingAttachmentIds.isNotEmpty;
    final hasAnyAttachmentUi = chat.attachmentDrafts.isNotEmpty || chat.pendingAttachmentIds.isNotEmpty;
    final showSend = _hasText || hasSendableAttachment;
    final canSend = showSend && !chat.sending;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: ChatColors.composerContainerBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: ChatColors.composerBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: ChatColors.composerShadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chat.canWebSearch) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.public_rounded, size: 18, color: ChatColors.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '联网搜索（实时 · Brave）',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ChatColors.textSecondary,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: chat.webSearchEnabled,
                  onChanged: chat.sending ? null : context.read<ChatController>().setWebSearchEnabled,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (hasAnyAttachmentUi) ...[
            ComposerAttachmentPreviewGrid(
              drafts: chat.attachmentDrafts,
              uploaded: pendingUploaded,
              bytesForUploadedId: chat.pendingPreviewBytes,
              onRemoveDraft: (id) => context.read<ChatController>().removeDraft(id),
              onRetryDraft: (id) => context.read<ChatController>().retryUploadDraft(id),
              onRemoveUploaded: (id) => context.read<ChatController>().deleteAttachment(id),
              disableActions: chat.sending,
              pendingIdsWithoutMetadata: pendingIdsWithoutMetadata,
            ),
            const SizedBox(height: 12),
          ],
          ComposerBottomRow(
            onOpenAddMenu: () => _openAddMenu(context),
            disableActions: chat.sending,
            showSend: showSend,
            canSend: canSend,
            sending: chat.sending,
            onSend: widget.onSend,
            controller: widget.controller,
            focusNode: _focus,
          ),
        ],
      ),
    );
  }
}

