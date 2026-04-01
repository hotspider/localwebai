import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/shell/app_shell.dart';

/// 用于登录态切换后仍能弹出轻提示（如退出登录）。
final GlobalKey<ScaffoldMessengerState> appRootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class FamilyAiApp extends StatelessWidget {
  const FamilyAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    // 登录态 / 就绪态变化时重建 Navigator，否则只改 home 仍会留在聊天、设置等子路由栈顶
    return MaterialApp(
      key: ValueKey<String>('${auth.isReady}_${auth.isLoggedIn}'),
      scaffoldMessengerKey: appRootMessengerKey,
      title: '家庭 AI 助手',
      theme: buildFamilyAiTheme(),
      home: auth.isReady
          ? (auth.isLoggedIn ? const AppShell() : const LoginPage())
          : const _BootScaffold(),
    );
  }
}

class _BootScaffold extends StatelessWidget {
  const _BootScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.hub_rounded, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '正在初始化…',
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.95), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
