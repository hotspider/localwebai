import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

/// 无消息时的轻量主内容区（不含推荐横滑区；推荐由外层固定在输入框上方）。
class EmptyChatState extends StatelessWidget {
  const EmptyChatState({this.fillHeight = true, super.key});

  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: fillHeight ? BoxConstraints(minHeight: constraints.maxHeight) : const BoxConstraints(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(height: (constraints.maxHeight * 0.18).clamp(40.0, 140.0)),
                  const Text(
                    '开始一段新对话',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ChatColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '你可以提问、写作、整理资料，或处理家庭日常事务。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: ChatColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '你可以直接输入问题，或从下方选择一个示例',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: ChatColors.textMuted.withValues(alpha: 0.92),
                    ),
                  ),
                  SizedBox(height: (constraints.maxHeight * 0.12).clamp(24.0, 80.0)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
