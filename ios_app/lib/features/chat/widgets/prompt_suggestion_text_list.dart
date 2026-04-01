import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/chat_colors.dart';
import 'prompt_suggestion_carousel.dart';

/// 纯文字推荐列表（不滑动）：更轻、更快扫读。
class PromptSuggestionTextList extends StatelessWidget {
  const PromptSuggestionTextList({required this.onPick, super.key});

  final void Function(String promptText) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Material(
          color: ChatColors.contentBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: ChatColors.dividerMain),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < kPromptSuggestions.length; i++) ...[
                  _PromptTextRow(
                    title: kPromptSuggestions[i].title,
                    subtitle: kPromptSuggestions[i].subtitle,
                    onTap: () => onPick(kPromptSuggestions[i].promptText),
                  ),
                  if (i != kPromptSuggestions.length - 1)
                    const Divider(height: 1, thickness: 1, color: ChatColors.dividerMain),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptTextRow extends StatelessWidget {
  const _PromptTextRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: ChatColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.15,
                      color: ChatColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: ChatColors.textMuted.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}

