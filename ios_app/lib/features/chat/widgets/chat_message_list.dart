import 'package:flutter/material.dart';

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
    super.key,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final bool loading;
  final void Function(int index) onCopy;
  final List<dynamic> Function(String messageId) attachmentsForMessage;
  final void Function(String messageId) onRetrySend;

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
