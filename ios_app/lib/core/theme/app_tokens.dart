import 'package:flutter/material.dart';

/// 浅色产品级设计 token：间距与圆角
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 22;

  /// 胶囊条、全圆角进度条等
  static const double stadium = 9999;

  /// 聊天用户消息气泡
  static const double bubbleUser = 18;

  /// 极小圆角（种类角标等）
  static const double mini = 4;

  /// 小标签（如模型角标）
  static const double tag = 6;

  /// 气泡内嵌面板（引用来源等）
  static const double panelInset = 10;
}

/// 字号阶梯（与 Theme / 聊天组件对齐，新代码优先引用此处）
abstract final class AppType {
  static const double screenTitle = 22;
  static const double navTitle = 17;
  static const double body = 16;
  static const double subtitle = 14;
  static const double label = 13;
  static const double caption = 12;
  static const double micro = 11;
}

/// 底部弹层等轻阴影（颜色为语义黑 + 低透明度）
abstract final class AppShadow {
  static Color sheetAmbient([double opacity = 0.06]) =>
      AppColors.textPrimary.withValues(alpha: opacity);

  static List<BoxShadow> sheetFloating({Color? color, double blur = 24, double dy = 8}) {
    final c = color ?? sheetAmbient();
    return [
      BoxShadow(color: c, blurRadius: blur, offset: Offset(0, dy)),
    ];
  }
}

/// 浅色语义色。保留 `bgDeep` / `cyan` 等旧名以减少调用处改动，语义已对齐新体系。
abstract final class AppColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF5F5F7);

  static const Color bgDeep = background;
  static const Color bgElevated = Color(0xFFECECF1);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF4F4F6);

  static const Color border = Color(0xFFE5E5EA);
  static const Color borderGlow = Color(0xFFD1D1D6);

  static const Color primary = Color(0xFF2563EB);
  static const Color cyan = primary;
  static const Color blue = Color(0xFF3B82F6);
  static const Color violet = Color(0xFF7C3AED);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  /// 辅助说明、图标默认态（介于 secondary / muted 之间）
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF9CA3AF);

  /// 弱分割线、轨道底（聊天进度条等）
  static const Color dividerSubtle = Color(0xFFEDF2F7);
  /// 表单描边（聊天输入框未聚焦）
  static const Color outlineMuted = Color(0xFFCBD5E1);

  static const Color danger = Color(0xFFDC2626);

  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color errorText = Color(0xFFB91C1C);

  static const Color userBubbleBg = Color(0xFFEFF6FF);
  static const Color userBubbleFg = Color(0xFF1E3A8A);
  static const Color assistantBubbleBg = Color(0xFFF9FAFB);
  static const Color assistantAccentBar = primary;
}
