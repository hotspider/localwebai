import 'package:flutter/material.dart';

import '../../../models/attachment.dart';
import '../../../models/chat_message.dart';
import '../../../core/theme/chat_colors.dart';
import 'assistant_message_bubble.dart';
import 'generating_state.dart';
import 'user_message_bubble.dart';

/// 消息列表：最大阅读宽度 720，水平 padding 16，消息垂直间距由气泡 margin 控制
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    required this.scrollController,
    required this.messages,
    required this.loading,
    required this.onCopy,
    required this.attachmentsForMessage,
    required this.onRetrySend,
    this.outboundSendingRowFor,
    this.onOpenAttachment,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    super.key,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final bool loading;
  /// 为某条用户消息是否仍显示「发送中」行（请求体未发出完毕时为 true）
  final bool Function(String messageId)? outboundSendingRowFor;
  final void Function(int index) onCopy;
  final List<dynamic> Function(String messageId) attachmentsForMessage;
  final void Function(String messageId) onRetrySend;
  final void Function(AttachmentItem item)? onOpenAttachment;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    final tail = loading && messages.isNotEmpty ? 1 : 0;
    final count = messages.length + tail;

    return ColoredBox(
      color: ChatColors.pageBg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            controller: scrollController,
            keyboardDismissBehavior: keyboardDismissBehavior,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: count,
            itemBuilder: (context, i) {
              if (i < messages.length) {
                final msg = messages[i];
                if (msg.role == 'user') {
                  return UserMessageBubble(
                    message: msg,
                    attachments: attachmentsForMessage(msg.id),
                    onRetry: (msg.sendState == ChatMessageSendState.failed) ? () => onRetrySend(msg.id) : null,
                    showOutboundSendingRow: outboundSendingRowFor?.call(msg.id) ?? true,
                    onOpenAttachment: onOpenAttachment,
                  );
                }
                return AssistantMessageBubble(
                  message: msg,
                  onCopy: () => onCopy(i),
                );
              }
              return const GeneratingState();
            },
          ),
        ),
      ),
    );
  }
}
