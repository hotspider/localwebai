import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../models/chat_message.dart';
import '../../../models/llm_model.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/chat_colors.dart';
import '../chat_markdown_style.dart';

class AssistantMessageBubble extends StatelessWidget {
  const AssistantMessageBubble({
    required this.message,
    required this.onCopy,
    super.key,
  });

  final ChatMessage message;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final modelLabel = LlmModel.fromApi(message.model).label;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ChatColors.aiBubbleBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: ChatColors.aiBubbleBorder),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ChatColors.modelTagBg,
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                      ),
                      child: Text(
                        modelLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: ChatColors.modelTagText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '复制',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      icon: Icon(Icons.copy_all_rounded, size: 18, color: ChatColors.textMuted.withValues(alpha: 0.9)),
                      onPressed: onCopy,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                MarkdownBody(
                  data: message.contentText,
                  selectable: true,
                  styleSheet: chatMarkdownStyleSheet(),
                  shrinkWrap: true,
                ),
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ChatColors.subBg,
                      borderRadius: BorderRadius.circular(AppRadius.panelInset),
                      border: Border.all(color: ChatColors.dividerMain),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '引用来源',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: ChatColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final s in message.sources)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${s['title'] ?? ''} ${s['url'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: ChatColors.textTertiary, height: 1.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
