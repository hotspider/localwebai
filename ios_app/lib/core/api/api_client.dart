import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../storage/secure_store.dart';

class ApiException implements Exception {
  final String code;
  final String message;

  ApiException(this.code, this.message);

  @override
  String toString() => '$code: $message';
}

class ApiClient {
  ApiClient({required String baseUrl, required SecureStore secureStore})
      : _secureStore = secureStore,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(minutes: 5),
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] == true) {
            handler.next(options);
            return;
          }
          final token = await _secureStore.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final SecureStore _secureStore;
  final Dio dio;

  ApiException _mapDioError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        // FastAPI HTTPException: { "detail": { "error": { "code", "message" } } }
        final detail = data['detail'];
        if (detail is Map && detail['error'] is Map) {
          final err = detail['error'] as Map;
          return ApiException('${err['code'] ?? 'ERROR'}', '${err['message'] ?? '请求失败'}');
        }
        if (data['error'] is Map) {
          final err = data['error'] as Map;
          return ApiException('${err['code'] ?? 'ERROR'}', '${err['message'] ?? '请求失败'}');
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return ApiException('VALIDATION_ERROR', '${first['msg']}');
          }
        }
        if (detail is String && detail.isNotEmpty) {
          return ApiException('HTTP_ERROR', detail);
        }
      }
      final code = e.response?.statusCode;
      final suffix = code != null ? ' (HTTP $code)' : '';
      return ApiException('NETWORK_ERROR', '${e.message ?? '网络错误'}$suffix');
    }
    return ApiException('UNKNOWN', '未知错误');
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? receiveTimeout,
    Duration? sendTimeout,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final resp = await dio.post(
        path,
        data: body,
        options: (receiveTimeout != null || sendTimeout != null)
            ? Options(receiveTimeout: receiveTimeout, sendTimeout: sendTimeout)
            : null,
        onSendProgress: onSendProgress,
      );
      return (resp.data as Map).cast<String, dynamic>();
    } catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) async {
    try {
      final resp = await dio.patch(path, data: body);
      return (resp.data as Map).cast<String, dynamic>();
    } catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration? receiveTimeout,
  }) async {
    try {
      final resp = await dio.get(
        path,
        options: receiveTimeout != null ? Options(receiveTimeout: receiveTimeout) : null,
      );
      return (resp.data as Map).cast<String, dynamic>();
    } catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await dio.delete(path);
    } catch (e) {
      throw _mapDioError(e);
    }
  }

  /// 下载二进制（附件预览等）；自动带 Bearer。
  Future<Uint8List> getBytes(
    String path, {
    Duration receiveTimeout = const Duration(minutes: 2),
  }) async {
    try {
      final resp = await dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: receiveTimeout),
      );
      final data = resp.data;
      if (data == null) return Uint8List(0);
      return Uint8List.fromList(data);
    } catch (e) {
      throw _mapDioError(e);
    }
  }
}

