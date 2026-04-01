import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

class ComposerAddButton extends StatelessWidget {
  const ComposerAddButton({
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onPressed : null,
          splashColor: ChatColors.pressBg,
          highlightColor: ChatColors.pressBg,
          child: const Center(
            child: Icon(Icons.add_rounded, size: 28, color: ChatColors.composerText),
          ),
        ),
      ),
    );
  }
}

