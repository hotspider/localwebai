import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/format/error_messages.dart';

class HistoryController extends ChangeNotifier {
  HistoryController({required this.apiClient});

  final ApiClient apiClient;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> sessions = [];

  /// 当前会话列表请求对应的关键词（空 = 最近会话，非空 = 服务端搜索）
  String listSearchQuery = '';

  /// 拉取会话列表。
  /// - [resetToRecent]：清空关键词并加载最近会话（侧栏打开时）。
  /// - [q]：显式设置关键词后拉取（搜索框防抖）；传 `''` 表示仅看最近。
  /// - 两者都不传：按当前 [listSearchQuery] 再拉取（删除会话后刷新等）。
  Future<void> fetchSessionList({bool resetToRecent = false, String? q}) async {
    if (resetToRecent) {
      listSearchQuery = '';
    }
    if (q != null) {
      listSearchQuery = q;
    }

    loading = true;
    error = null;
    notifyListeners();
    try {
      final trimmed = listSearchQuery.trim();
      final path = trimmed.isEmpty
          ? '/api/sessions?limit=50&offset=0'
          : '/api/sessions?limit=50&offset=0&q=${Uri.encodeQueryComponent(trimmed)}';
      final resp = await apiClient.getJson(path);
      sessions = (resp['items'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (e) {
      error = describeErrorForUser(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  /// 返回是否删除成功。
  Future<bool> deleteSession(String sessionId) async {
    try {
      await apiClient.delete('/api/sessions/$sessionId');
      error = null;
      await fetchSessionList();
      return true;
    } catch (e) {
      error = describeErrorForUser(e);
      notifyListeners();
      return false;
    }
  }
}
