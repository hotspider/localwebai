import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

class ComposerSendButton extends StatefulWidget {
  const ComposerSendButton({
    required this.enabled,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  State<ComposerSendButton> createState() => _ComposerSendButtonState();
}

class _ComposerSendButtonState extends State<ComposerSendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.loading;
    final bg = _pressed ? ChatColors.sendPressedBg : ChatColors.sendEnabledBg;
    final iconColor = ChatColors.sendIconOn;

    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? widget.onPressed : null,
          onHighlightChanged: (v) {
            if (!enabled) return;
            setState(() => _pressed = v);
          },
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.arrow_upward_rounded, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }
}

