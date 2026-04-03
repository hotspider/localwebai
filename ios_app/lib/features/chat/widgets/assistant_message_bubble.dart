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
                if (message.realtimeMeta != null) ...[
                  _RealtimeMetaBanner(meta: message.realtimeMeta!),
                  const SizedBox(height: 8),
                ],
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
                              '${s['title'] ?? ''}\n${s['url'] ?? ''}',
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

class _RealtimeMetaBanner extends StatelessWidget {
  const _RealtimeMetaBanner({required this.meta});

  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final status = meta['status']?.toString() ?? '';
    final msg = meta['message']?.toString() ?? '';
    final q = meta['queried_at']?.toString();
    String? queriedLocal;
    if (q != null && q.isNotEmpty) {
      final dt = DateTime.tryParse(q);
      if (dt != null) {
        queriedLocal = dt.toLocal().toString().split('.').first;
      }
    }

    if (status == 'ok') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ChatColors.subBg,
          borderRadius: BorderRadius.circular(AppRadius.panelInset),
          border: Border.all(color: ChatColors.accentBlue.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, size: 16, color: ChatColors.accentBlue),
                const SizedBox(width: 6),
                Text(
                  '已联网查询（Brave）',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: ChatColors.accentBlue,
                  ),
                ),
              ],
            ),
            if (queriedLocal != null) ...[
              const SizedBox(height: 4),
              Text(
                '查询时间：$queriedLocal',
                style: const TextStyle(fontSize: 11, color: ChatColors.textTertiary, height: 1.3),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ChatColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.panelInset),
        border: Border.all(color: ChatColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: ChatColors.error),
              const SizedBox(width: 6),
              Text(
                '实时查询未完成（$status）',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: ChatColors.error,
                ),
              ),
            ],
          ),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              msg,
              style: const TextStyle(fontSize: 11, color: ChatColors.textSecondary, height: 1.35),
            ),
          ],
          if (queriedLocal != null) ...[
            const SizedBox(height: 4),
            Text(
              '请求时间：$queriedLocal',
              style: const TextStyle(fontSize: 11, color: ChatColors.textTertiary, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}
