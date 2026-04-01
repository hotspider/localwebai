import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/config/api_endpoint_store.dart';
import 'core/config/current_api_base.dart';
import 'core/storage/secure_store.dart';
import 'features/auth/auth_controller.dart';
import 'features/chat/chat_controller.dart';
import 'features/history/history_controller.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    Phoenix(
      child: const _FamilyAiBootstrap(),
    ),
  );
}

class _FamilyAiBootstrap extends StatefulWidget {
  const _FamilyAiBootstrap();

  @override
  State<_FamilyAiBootstrap> createState() => _FamilyAiBootstrapState();
}

class _FamilyAiBootstrapState extends State<_FamilyAiBootstrap> {
  late final Future<_BootData> _boot = _load();

  Future<_BootData> _load() async {
    final baseUrl = await ApiEndpointStore.readResolvedBaseUrl();
    CurrentApiBase.display = baseUrl;
    final secureStore = SecureStore();
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      secureStore: secureStore,
    );
    return _BootData(
      secureStore: secureStore,
      apiClient: apiClient,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootData>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('启动失败：${snapshot.error}', textAlign: TextAlign.center),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final d = snapshot.data!;
        return MultiProvider(
          providers: [
            Provider.value(value: d.secureStore),
            Provider.value(value: d.apiClient),
            ChangeNotifierProvider(
              create: (_) => AuthController(apiClient: d.apiClient, secureStore: d.secureStore)..init(),
            ),
            ChangeNotifierProvider(create: (_) => ChatController(apiClient: d.apiClient)),
            ChangeNotifierProvider(create: (_) => HistoryController(apiClient: d.apiClient)),
            ChangeNotifierProvider(create: (_) => SettingsController(apiClient: d.apiClient)),
          ],
          child: const FamilyAiApp(),
        );
      },
    );
  }
}

class _BootData {
  _BootData({required this.secureStore, required this.apiClient});

  final SecureStore secureStore;
  final ApiClient apiClient;
}
