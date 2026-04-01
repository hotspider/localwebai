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
          return '网络异常\n$detail\n当前 API：${CurrentApiBase.display}\n'
              '可在「设置 → 接口地址」切换本地/公网；本地时请确认本机后端已启动。';
        }
        return '网络异常，请检查网络或确认后端已启动';
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
