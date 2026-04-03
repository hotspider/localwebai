import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/secure_store.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.apiClient, required this.secureStore});

  final ApiClient apiClient;
  final SecureStore secureStore;

  bool isReady = false;
  bool isLoggedIn = false;
  Map<String, dynamic>? me;

  Future<void> init() async {
    try {
      final token = await secureStore.readToken();
      isLoggedIn = token != null && token.isNotEmpty;
      if (isLoggedIn) {
        await refreshMe(silent: true);
      }
    } catch (_) {
      isLoggedIn = false;
    } finally {
      isReady = true;
      notifyListeners();
    }
  }

  Future<void> login({required String username, required String password}) async {
    final data = await apiClient.postJson('/api/auth/login', {'username': username, 'password': password});
    final token = data['access_token'] as String;
    await secureStore.writeToken(token);
    isLoggedIn = true;
    me = (data['user'] as Map).cast<String, dynamic>();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await apiClient.postJson('/api/auth/logout', {});
    } catch (_) {}
    await secureStore.clearToken();
    isLoggedIn = false;
    me = null;
    notifyListeners();
  }

  Future<void> refreshMe({bool silent = false}) async {
    try {
      final data = await apiClient.getJson('/api/me');
      me = data;
      notifyListeners();
    } catch (e) {
      if (!silent) rethrow;
    }
  }
}

