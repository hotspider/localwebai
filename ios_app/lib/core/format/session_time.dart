String _two(int n) => n.toString().padLeft(2, '0');

/// 独立历史页等：yyyy-MM-dd HH:mm（与产品示例一致）
String formatSessionListTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final local = dt.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
}

/// 侧栏最近对话：今天 / 昨天 / MM-dd HH:mm（同年省略年份）
String formatDrawerSessionTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final hm = '${_two(dt.hour)}:${_two(dt.minute)}';
  if (d == today) return '今天 $hm';
  if (d == today.subtract(const Duration(days: 1))) return '昨天 $hm';
  if (dt.year == now.year) return '${_two(dt.month)}-${_two(dt.day)} $hm';
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} $hm';
}
