import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

class ComposerAttachmentDeleteButton extends StatelessWidget {
  const ComposerAttachmentDeleteButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChatColors.imageRemoveBg,
      shape: const CircleBorder(),
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.10),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(Icons.close_rounded, size: 16, color: ChatColors.composerText),
            ),
          ),
        ),
      ),
    );
  }
}

