import 'package:flutter/material.dart';

import '../../../core/theme/chat_colors.dart';

class ComposerTextRegion extends StatelessWidget {
  const ComposerTextRegion({
    required this.controller,
    required this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        minLines: 1,
        maxLines: 6,
        textInputAction: TextInputAction.newline,
        cursorColor: ChatColors.composerText,
        style: const TextStyle(
          fontSize: 17,
          height: 1.5,
          color: ChatColors.composerText,
        ),
        decoration: const InputDecoration(
          hintText: '开始发送消息对话',
          hintStyle: TextStyle(fontSize: 17, height: 1.5, color: ChatColors.placeholder),
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

