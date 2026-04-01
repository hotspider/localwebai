import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/format/error_messages.dart';
import '../../models/llm_model.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({required this.apiClient});

  final ApiClient apiClient;

  bool loading = false;
  String? error;
  LlmModel defaultModel = LlmModel.chatgpt52;

  Future<void> load() async {
    final me = await apiClient.getJson('/api/me');
    defaultModel = LlmModel.fromApi(me['default_model'] as String? ?? 'chatgpt-5.2');
    notifyListeners();
  }

  Future<void> setDefaultModel(LlmModel m) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await apiClient.patchJson('/api/me/default-model', {'default_model': m.apiValue});
      defaultModel = m;
    } catch (e) {
      error = describeErrorForUser(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await apiClient.postJson('/api/auth/change-password', {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
    } catch (e) {
      error = describeErrorForUser(e);
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

