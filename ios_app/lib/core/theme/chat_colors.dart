import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 聊天页语义色：首页/侧栏与 ChatGPT 式轻界面用 slate 阶梯；其余仍可对齐 AppColors。
abstract final class ChatColors {
  /// 对话主背景（产品规范 #F8FAFC）
  static const Color pageBg = Color(0xFFF8FAFC);
  /// 底部输入区整体背景（产品规范 #F8FAFC）
  static const Color composerAreaBg = Color(0xFFF8FAFC);
  /// 底部输入区顶部分割线（产品规范 #E2E8F0）
  static const Color composerDivider = Color(0xFFE2E8F0);
  static const Color contentBg = Color(0xFFFFFFFF);
  static const Color subBg = Color(0xFFF1F5F9);
  static const Color inputAreaBg = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  static const Color dividerMain = Color(0xFFE2E8F0);
  static const Color dividerWeak = AppColors.dividerSubtle;

  static const Color inputBorder = Color(0xFFCBD5E1);
  static const Color inputFocusBorder = Color(0xFF3B82F6);

  /// 输入条（ChatGPT 风格）规范色
  static const Color composerBg = Color(0xFFFFFFFF);
  /// 新对话页底部输入框（按参考图）
  static const Color composerContainerBg = Color(0xFFF8F8F8);
  static const Color composerBorder = Color(0xFFECECEC);
  static const Color composerShadow = Color(0x0F0F172A); // rgba(15,23,42,0.06)

  static const Color composerText = Color(0xFF111111);
  static const Color placeholder = Color(0xFF8C8C8C);
  static const Color pressBg = Color(0xFFF1F1F1);

  static const Color sendEnabledBg = Color(0xFF111111);
  static const Color sendPressedBg = Color(0xFF0B0B0B);
  static const Color sendIconOn = Color(0xFFFFFFFF);

  static const Color imageTileBorder = Color(0xFFECECEC);
  static const Color imageTileBg = Color(0xFFFFFFFF);
  static const Color imageRemoveBg = Color(0xEBFFFFFF); // rgba(255,255,255,0.92)

  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentBluePressed = Color(0xFF1D4ED8);
  static const Color accentBlueTint = Color(0xFFDBEAFE);
  static const Color accentBlueText = Color(0xFF1E40AF);

  static const Color userBubbleBg = AppColors.userBubbleBg;
  static const Color userBubbleText = AppColors.textPrimary;
  static const Color aiBubbleBg = AppColors.surface;
  static const Color aiBubbleBorder = AppColors.border;

  static const Color sendBg = Color(0xFF2563EB);
  static const Color stopBg = Color(0xFFEFF6FF);
  static const Color stopBorder = Color(0xFFBFDBFE);
  static const Color stopText = Color(0xFF1D4ED8);

  static const Color modelSheetBg = AppColors.surface;
  static const Color modelHoverBg = Color(0xFFF8FAFC);
  static const Color modelSelectedBg = Color(0xFFDBEAFE);
  static const Color modelSelectedBorder = Color(0xFF93C5FD);
  static const Color modelTagBg = Color(0xFFEFF6FF);
  static const Color modelTagText = Color(0xFF2563EB);

  /// 顶栏浅色底（约 88% 白）
  static const Color topBarBg = Color(0xE0FFFFFF);

  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = AppColors.danger;
  static const Color errorBg = AppColors.errorBg;
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoBg = Color(0xFFE0F2FE);
}
