import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';
import 'model_pill_button.dart';

/// 顶栏高度约 60px，轻量；空会话时不强调会话标题。
const double kChatTopBarHeight = 60;

class ChatTopBar extends StatelessWidget {
  const ChatTopBar({
    required this.modelLabel,
    required this.onOpenDrawer,
    required this.onOpenModelSheet,
    required this.onNewSession,
    this.sessionTitle,
    this.showSessionTitle = false,
    super.key,
  });

  final String modelLabel;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenModelSheet;
  final VoidCallback onNewSession;

  /// 有消息时可显示当前会话标题（弱化，不抢模型胶囊）。
  final String? sessionTitle;
  final bool showSessionTitle;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Material(
      color: ChatColors.topBarBg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: kChatTopBarHeight,
          decoration: const BoxDecoration(
            color: ChatColors.topBarBg,
            border: Border(bottom: BorderSide(color: ChatColors.dividerMain, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canPop)
                IconButton(
                  tooltip: '返回上一页',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ChatColors.textSecondary),
                )
              else
                IconButton(
                  tooltip: '打开菜单',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: onOpenDrawer,
                  icon: const Icon(Icons.menu_rounded, size: 22, color: ChatColors.textSecondary),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        ModelPillButton(label: modelLabel, onTap: onOpenModelSheet),
                        if (showSessionTitle && (sessionTitle ?? '').isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              sessionTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: ChatColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '发起新对话',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: onNewSession,
                icon: Icon(Icons.edit_square, size: 22, color: ChatColors.textMuted.withValues(alpha: 0.95)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
