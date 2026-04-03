import 'package:flutter/foundation.dart';

/// 应用请求的 API 根地址（无末尾 `/`）。
///
/// **规则**
/// 1. **仅 Debug**：`http://127.0.0.1:8000`（**仅 iOS 模拟器 / 与后端同机**有意义；**真机 Debug 上 127.0.0.1 是手机自己**，会连不上）。
/// 2. **Profile / Release**：使用 [kProductionShipApiBaseUrl]（真机日常请用 Profile 或 Release 跑，或见下条）。
/// 3. **任意模式覆盖**：`--dart-define=API_BASE_URL=https://你的域名` 优先级最高。
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromEnv.trim().isNotEmpty) {
    return _trimTrailingSlash(fromEnv.trim());
  }
  if (kReleaseMode || kProfileMode) {
    return _trimTrailingSlash(kProductionShipApiBaseUrl);
  }
  return _trimTrailingSlash(kLocalDevApiBaseUrl);
}

/// 本地 Debug 默认（模拟器里访问宿主机 Mac 上的后端；真机请用 Profile/Release 或 dart-define）
const String kLocalDevApiBaseUrl = 'http://127.0.0.1:8000';

/// **正式发布（Release）** 使用的 API 根地址（须与后端 `PUBLIC_BASE_URL` 的协议+主机一致，建议 HTTPS）。
/// 构建时可覆盖：`flutter build ios --release --dart-define=API_BASE_URL=https://你的域名`
const String kProductionShipApiBaseUrl = 'https://app.nasclaw.com';

String _trimTrailingSlash(String u) {
  var s = u.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
