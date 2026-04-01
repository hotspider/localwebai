import '../api/api_client.dart';

/// 将异常转换为用户可读短句（不含技术栈、尽量少暴露 error code）。
String describeErrorForUser(Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'UNAUTHORIZED':
        return '登录已失效，请重新登录';
      case 'NETWORK_ERROR':
        return '网络异常，请检查网络后重试';
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
