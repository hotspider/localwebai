import 'package:flutter/material.dart';

import '../chat/chat_home_page.dart';

/// 主界面：单页聊天 + 侧栏历史（Open WebUI 风格），设置从侧栏或顶栏进入。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatHomePage();
  }
}

