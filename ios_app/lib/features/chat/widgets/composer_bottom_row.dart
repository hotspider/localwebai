import 'package:flutter/material.dart';

import 'composer_add_button.dart';
import 'composer_send_button.dart';
import 'composer_text_region.dart';

class ComposerBottomRow extends StatelessWidget {
  const ComposerBottomRow({
    required this.onOpenAddMenu,
    required this.disableActions,
    required this.showSend,
    required this.canSend,
    required this.sending,
    required this.onSend,
    required this.controller,
    required this.focusNode,
    super.key,
  });

  final VoidCallback onOpenAddMenu;
  final bool disableActions;
  final bool showSend;
  final bool canSend;
  final bool sending;
  final VoidCallback onSend;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ComposerAddButton(
          enabled: !disableActions,
          onPressed: disableActions ? null : onOpenAddMenu,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ComposerTextRegion(controller: controller, focusNode: focusNode),
        ),
        if (showSend) ...[
          const SizedBox(width: 12),
          ComposerSendButton(
            enabled: canSend,
            loading: sending,
            onPressed: canSend ? onSend : null,
          ),
        ],
      ],
    );
  }
}

