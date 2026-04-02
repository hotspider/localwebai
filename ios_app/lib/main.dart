import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/config/app_api_host.dart';
import 'core/config/current_api_base.dart';
import 'core/storage/secure_store.dart';
import 'features/auth/auth_controller.dart';
import 'features/chat/chat_controller.dart';
import 'features/history/history_controller.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = resolveApiBaseUrl();
  CurrentApiBase.display = baseUrl;

  final secureStore = SecureStore();
  final apiClient = ApiClient(
    baseUrl: baseUrl,
    secureStore: secureStore,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: secureStore),
        Provider.value(value: apiClient),
        ChangeNotifierProvider(
          create: (_) => AuthController(apiClient: apiClient, secureStore: secureStore)..init(),
        ),
        ChangeNotifierProvider(create: (_) => ChatController(apiClient: apiClient)),
        ChangeNotifierProvider(create: (_) => HistoryController(apiClient: apiClient)),
        ChangeNotifierProvider(create: (_) => SettingsController(apiClient: apiClient)),
      ],
      child: const FamilyAiApp(),
    ),
  );
}
