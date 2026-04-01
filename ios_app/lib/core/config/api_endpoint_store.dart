import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// 持久化「连哪套后端」：本地 / 公网 / 自定义。
///
/// 若 [AppConstants.apiBaseUrlFromEnvironment] 非空，则始终优先使用该值（忽略此处设置）。
class ApiEndpointStore {
  ApiEndpointStore._();

  static const _kMode = 'api_endpoint_mode';
  static const _kPublicUrl = 'api_endpoint_public_url';
  static const _kCustomUrl = 'api_endpoint_custom_url';

  /// 模拟器连本机后端
  static const defaultLocal = 'http://127.0.0.1:8000';

  /// 首次选「公网」且未保存过时的占位默认（可在 App 设置里改掉）
  static const defaultPublic = 'http://43.160.235.149:8000';

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  /// local | public | custom
  static Future<String> readMode() async {
    final p = await _p();
    return p.getString(_kMode) ?? 'local';
  }

  static Future<String> readPublicUrl() async {
    final p = await _p();
    return (p.getString(_kPublicUrl)?.trim().isNotEmpty == true)
        ? p.getString(_kPublicUrl)!.trim()
        : defaultPublic;
  }

  static Future<String> readCustomUrl() async {
    final p = await _p();
    return (p.getString(_kCustomUrl)?.trim().isNotEmpty == true)
        ? p.getString(_kCustomUrl)!.trim()
        : defaultLocal;
  }

  /// 最终用于 Dio 的 baseUrl（无末尾 `/`）
  static Future<String> readResolvedBaseUrl() async {
    final fromEnv = AppConstants.apiBaseUrlFromEnvironment.trim();
    if (fromEnv.isNotEmpty) {
      return _normalizeBaseUrl(fromEnv);
    }
    final mode = await readMode();
    switch (mode) {
      case 'public':
        return _normalizeBaseUrl(await readPublicUrl());
      case 'custom':
        return _normalizeBaseUrl(await readCustomUrl());
      default:
        return _normalizeBaseUrl(defaultLocal);
    }
  }

  static String _normalizeBaseUrl(String u) {
    var s = u.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static Future<void> save({
    required String mode,
    String? publicUrl,
    String? customUrl,
  }) async {
    final p = await _p();
    await p.setString(_kMode, mode);
    if (publicUrl != null) {
      await p.setString(_kPublicUrl, _normalizeBaseUrl(publicUrl));
    }
    if (customUrl != null) {
      await p.setString(_kCustomUrl, _normalizeBaseUrl(customUrl));
    }
  }

  static bool get isLockedByCompileTimeDefine => AppConstants.apiBaseUrlFromEnvironment.trim().isNotEmpty;
}
