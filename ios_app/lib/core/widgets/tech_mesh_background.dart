import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 动态网格 + 微光，叠在深色底上增强科技感（纯绘制，性能好）
class TechMeshPainter extends CustomPainter {
  TechMeshPainter({this.gridStep = 28, this.lineOpacity = 0.08});

  final double gridStep;
  final double lineOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: lineOpacity)
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width + gridStep; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height + gridStep; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.85, size.height * 0.15),
        size.shortestSide * 0.55,
        [
          AppColors.cyan.withValues(alpha: 0.12),
          AppColors.blue.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawRect(Offset.zero & size, glow);

    final glow2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.1, size.height * 0.75),
        size.shortestSide * 0.5,
        [
          AppColors.violet.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        [0.0, 1.0],
      );
    canvas.drawRect(Offset.zero & size, glow2);
  }

  @override
  bool shouldRepaint(covariant TechMeshPainter oldDelegate) =>
      oldDelegate.gridStep != gridStep || oldDelegate.lineOpacity != lineOpacity;
}

/// 全屏：网格 + 可选子组件
class TechMeshBackground extends StatelessWidget {
  const TechMeshBackground({super.key, required this.child, this.gridStep = 28});

  final Widget child;
  final double gridStep;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: TechMeshPainter(gridStep: gridStep)),
        child,
      ],
    );
  }
}
