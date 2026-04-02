import 'package:flutter/foundation.dart';

/// 应用请求的 API 根地址（无末尾 `/`）。
///
/// **规则**
/// 1. **本地开发**（Debug / Profile）：固定 `http://127.0.0.1:8000`，联调本机 `uvicorn`。
/// 2. **正式发布**（Release）：使用 [kProductionShipApiBaseUrl]。上架或交付安装包前，请改成你的外网根地址（建议 HTTPS）。
/// 3. **可选覆盖**（任意模式）：构建时传入  
///    `--dart-define=API_BASE_URL=https://你的域名`  
///    将**优先于**上面 1、2 条（适合 CI 不写死代码）。
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromEnv.trim().isNotEmpty) {
    return _trimTrailingSlash(fromEnv.trim());
  }
  if (kReleaseMode) {
    return _trimTrailingSlash(kProductionShipApiBaseUrl);
  }
  return _trimTrailingSlash(kLocalDevApiBaseUrl);
}

/// 本地开发默认（模拟器访问 Mac 上的后端）
const String kLocalDevApiBaseUrl = 'http://127.0.0.1:8000';

/// **发布到外网前**：改为正式环境根地址（无末尾 `/`）。
/// 示例：`https://api.example.com` 或 `https://example.com`（若 API 与站点同域需带路径则写完整前缀）。
const String kProductionShipApiBaseUrl = 'http://43.160.235.149:8000';

String _trimTrailingSlash(String u) {
  var s = u.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
