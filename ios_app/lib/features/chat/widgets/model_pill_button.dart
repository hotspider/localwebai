import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

/// ChatGPT 式模型胶囊：40px 高、20px 圆角，仅展示模型名。
class ModelPillButton extends StatelessWidget {
  const ModelPillButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more_rounded, size: 18, color: ChatColors.modelTagText.withValues(alpha: 0.9)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
