import 'package:flutter/material.dart';

import '../../models/llm_model.dart';
import '../theme/app_theme.dart';
import '../theme/chat_colors.dart';
import 'app_sheet_shell.dart';

extension LlmModelDescription on LlmModel {
  String get uiDescription {
    switch (this) {
      case LlmModel.chatgpt52:
        return '适合日常对话与多场景使用';
      case LlmModel.chatgpt54:
        return '更强推理能力，适合复杂任务';
      case LlmModel.deepseek:
        return '适合中文问答与文本处理';
    }
  }

  String get uiKindTag => isOpenAiFamily ? 'ChatGPT' : 'DeepSeek';
}

enum ModelSelectorAppearance {
  /// 与全局 AppColors 一致（设置页等）
  standard,

  /// 聊天定稿色板
  chatProduct,
}

/// 模型选择底部弹层（聊天顶栏、设置等处复用）
Future<void> showModelSelectorSheet(
  BuildContext context, {
  required LlmModel selected,
  required void Function(LlmModel model) onSelected,
  Map<String, String>? resolvedModelIdByRoute,
  VoidCallback? onOpenSettings,
  String settingsHint = '默认使用的模型可在设置中调整',
  ModelSelectorAppearance appearance = ModelSelectorAppearance.standard,
}) {
  final product = appearance == ModelSelectorAppearance.chatProduct;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return AppSheetShell(
        title: '选择模型',
        subtitle: '不同模型擅长的任务不同，可按需要切换',
        backgroundColor: product ? ChatColors.modelSheetBg : null,
        panelBorderColor: product ? ChatColors.dividerMain : null,
        titleColor: product ? ChatColors.textPrimary : null,
        subtitleColor: product ? ChatColors.textTertiary : null,
        handleColor: product ? ChatColors.dividerMain : null,
        shadowColor: product ? ChatColors.textPrimary.withValues(alpha: 0.06) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...LlmModel.values.map((m) {
              final isOn = m == selected;
              final resolved = resolvedModelIdByRoute?[m.apiValue];
              if (product) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      splashColor: ChatColors.modelHoverBg,
                      highlightColor: ChatColors.modelHoverBg.withValues(alpha: 0.6),
                      onTap: () {
                        onSelected(m);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: isOn ? ChatColors.modelSelectedBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isOn ? ChatColors.modelSelectedBorder : ChatColors.dividerWeak,
                            width: isOn ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              m.isOpenAiFamily ? Icons.bolt_rounded : Icons.psychology_outlined,
                              color: isOn ? ChatColors.accentBlue : ChatColors.textTertiary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        m.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: isOn ? ChatColors.textPrimary : ChatColors.textSecondary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ChatColors.modelTagBg,
                                          borderRadius: BorderRadius.circular(AppRadius.mini),
                                        ),
                                        child: Text(
                                          m.uiKindTag,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: ChatColors.modelTagText,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    resolved != null && resolved.trim().isNotEmpty
                                        ? '${m.uiDescription}\n后端实际模型：$resolved'
                                        : m.uiDescription,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: ChatColors.textTertiary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isOn)
                              const Icon(Icons.check_circle_rounded, color: ChatColors.accentBlue, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Material(
                  color: isOn ? AppColors.surface2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () {
                      onSelected(m);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: isOn ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border,
                          width: isOn ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            m.isOpenAiFamily ? Icons.bolt_rounded : Icons.psychology_outlined,
                            color: isOn ? AppColors.primary : AppColors.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: isOn ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.uiDescription,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          if (isOn) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (onOpenSettings != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onOpenSettings();
                },
                style: TextButton.styleFrom(
                  foregroundColor: product ? ChatColors.accentBlue : null,
                ),
                child: Text(settingsHint),
              )
            else
              const SizedBox(height: AppSpacing.sm),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}
