class AppConstants {
  /// 非空时强制使用该地址，且 **设置里的「接口地址」不生效**（用于 CI/正式包）。
  /// 日常调试不要传，在 App **设置 → 接口地址** 切换即可。
  static const String apiBaseUrlFromEnvironment = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
}

