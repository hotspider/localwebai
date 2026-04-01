import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/chat_colors.dart';

/// 回复生成中的克制占位（列表底部）
class GeneratingState extends StatelessWidget {
  const GeneratingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 8,
            child: LinearProgressIndicator(
              value: null,
              minHeight: 3,
              backgroundColor: ChatColors.dividerWeak,
              color: ChatColors.accentBlue.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.stadium),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '正在生成回复…',
            style: TextStyle(fontSize: 13, color: ChatColors.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

