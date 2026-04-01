import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/format/error_messages.dart';

class HistoryController extends ChangeNotifier {
  HistoryController({required this.apiClient});

  final ApiClient apiClient;

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> sessions = [];

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final resp = await apiClient.getJson('/api/sessions?limit=50&offset=0');
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
      await refresh();
      return true;
    } catch (e) {
      error = describeErrorForUser(e);
      notifyListeners();
      return false;
    }
  }
}

