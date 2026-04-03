import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../config/current_api_base.dart';

/// 将异常转换为用户可读短句（不含技术栈、尽量少暴露 error stack）。
String describeErrorForUser(Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'UNAUTHORIZED':
        return '登录已失效，请重新登录';
      case 'NETWORK_ERROR':
        if (kDebugMode) {
          final detail = e.message.trim();
          final api = CurrentApiBase.display;
          final loopbackHint = api.contains('127.0.0.1') || api.contains('localhost')
              ? '\n真机 Debug 时 127.0.0.1 指向手机本身，连不到 Mac 上的后端。请改用：'
                  '① `flutter run --profile` 或 Release 安装包（走线上 API）；'
                  '② 或 `flutter run --dart-define=API_BASE_URL=https://app.nasclaw.com`；'
                  '③ 或在同一 Wi‑Fi 下把 API 设为电脑的局域网 IP（如 http://192.168.x.x:8000）。'
              : '';
          return '网络异常\n$detail\n当前 API：$api\n'
              '若在后端本机调试：请确认 uvicorn 已监听 0.0.0.0:8000 且地址与上文一致。$loopbackHint';
        }
        return '网络异常，请检查网络或确认后端已启动';
      case 'REALTIME_REQUIRES_WEB_SEARCH':
        return e.message.isNotEmpty ? e.message : '该问题需要开启联网搜索（实时）';
      case 'VALIDATION_ERROR':
      case 'BAD_REQUEST':
        return e.message.isNotEmpty ? e.message : '输入有误，请检查后重试';
      case 'FORBIDDEN':
        return e.message.isNotEmpty ? e.message : '没有权限执行此操作';
      case 'NOT_FOUND':
        return '内容不存在或已被删除';
      default:
        if (e.message.isNotEmpty) return e.message;
        return '操作未成功，请稍后重试';
    }
  }
  final raw = e.toString();
  if (raw.startsWith('UnsupportedError:')) {
    return raw.replaceFirst('UnsupportedError:', '').trim();
  }
  return '操作未成功，请稍后重试';
}
