import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/chat_colors.dart';

MarkdownStyleSheet chatMarkdownStyleSheet() {
  const base = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: ChatColors.textPrimary,
  );
  return MarkdownStyleSheet(
    p: base,
    h1: base.copyWith(fontSize: 22, fontWeight: FontWeight.w600, height: 1.35),
    h2: base.copyWith(fontSize: 19, fontWeight: FontWeight.w600, height: 1.4),
    h3: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.45),
    h4: base.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
    strong: base.copyWith(fontWeight: FontWeight.w600),
    em: base.copyWith(fontStyle: FontStyle.italic),
    code: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: ChatColors.textSecondary,
      fontFamily: 'monospace',
      backgroundColor: ChatColors.subBg,
    ),
    blockquote: base.copyWith(color: ChatColors.textTertiary, fontStyle: FontStyle.italic),
    blockquoteDecoration: BoxDecoration(
      color: ChatColors.subBg,
      borderRadius: BorderRadius.circular(AppRadius.tag),
      border: Border(left: BorderSide(color: ChatColors.dividerMain, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    listBullet: base,
    listIndent: 20,
    blockSpacing: 8,
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: ChatColors.dividerMain, width: 1)),
    ),
    a: base.copyWith(color: ChatColors.accentBlue, decoration: TextDecoration.underline),
    codeblockDecoration: BoxDecoration(
      color: ChatColors.subBg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: ChatColors.dividerMain),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    tableBorder: TableBorder.all(color: ChatColors.dividerMain, width: 1),
    tableHead: base.copyWith(fontWeight: FontWeight.w600, color: ChatColors.textSecondary),
    tableBody: base,
  );
}
