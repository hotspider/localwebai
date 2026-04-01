/// 聊天顶栏、历史列表等处展示的会话标题（避免占位词反复出现）。
String displayChatSessionTitle(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return '未命名对话';
  final lower = t.toLowerCase();
  // 仅在确实是“占位标题”时才降级；不要把真实首条消息（比如 hello）吞掉。
  if (t == '新对话') {
    return '未命名对话';
  }
  return t;
}
