class AppConstants {
  /// API Base URL:
  /// - 本地开发：默认 iOS 模拟器访问宿主机 `http://127.0.0.1:8000`
  /// - 真机/公网：用 `--dart-define=API_BASE_URL=https://your.domain` 覆盖
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}

