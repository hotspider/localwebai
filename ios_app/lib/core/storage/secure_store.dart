import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _kTokenKey = 'access_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _kTokenKey);

  Future<void> writeToken(String token) => _storage.write(key: _kTokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _kTokenKey);
}

