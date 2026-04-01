import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/chat_colors.dart';

/// 单条推荐：展示标题 + 副文案，点击发送 [promptText]。
class PromptSuggestionEntry {
  const PromptSuggestionEntry({
    required this.title,
    required this.subtitle,
    required this.promptText,
  });

  final String title;
  final String subtitle;
  final String promptText;
}

/// 家庭场景任务型推荐（横向轻卡片，非九宫格）。
const kPromptSuggestions = <PromptSuggestionEntry>[
  PromptSuggestionEntry(
    title: '帮我安排今天的日程',
    subtitle: '把待办排得更清楚',
    promptText: '帮我安排今天的日程，把待办排得更清楚。',
  ),
  PromptSuggestionEntry(
    title: '列一个家庭购物清单',
    subtitle: '按日用品和食材整理',
    promptText: '列一个家庭购物清单，按日用品和食材整理。',
  ),
  PromptSuggestionEntry(
    title: '推荐今晚吃什么',
    subtitle: '按家里现有食材来搭配',
    promptText: '根据家里现有食材，推荐今晚吃什么并简单说明搭配。',
  ),
  PromptSuggestionEntry(
    title: '整理一份待办事项',
    subtitle: '适合家庭和日常安排',
    promptText: '帮我整理一份待办事项，适合家庭和日常安排。',
  ),
  PromptSuggestionEntry(
    title: '帮孩子出几道练习题',
    subtitle: '按年级和题型生成',
    promptText: '帮孩子出几道练习题，请按年级和题型生成。',
  ),
  PromptSuggestionEntry(
    title: '写一段通知或消息',
    subtitle: '适合家长群、老师或亲友',
    promptText: '帮我写一段通知或消息，适合家长群、老师或亲友。',
  ),
];

class PromptSuggestionCarousel extends StatelessWidget {
  const PromptSuggestionCarousel({required this.onPick, super.key});

  final void Function(String promptText) onPick;

  static const double _cardHeight = 92;
  static const double _cardWidth = 268;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kPromptSuggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = kPromptSuggestions[i];
          return SizedBox(
            width: _cardWidth,
            height: _cardHeight,
            child: _PromptSuggestionCard(
              title: e.title,
              subtitle: e.subtitle,
              onTap: () => onPick(e.promptText),
            ),
          );
        },
      ),
    );
  }
}

class _PromptSuggestionCard extends StatelessWidget {
  const _PromptSuggestionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChatColors.contentBg,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: ChatColors.dividerMain),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: ChatColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  color: ChatColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
