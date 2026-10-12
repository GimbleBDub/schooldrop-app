import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists tokens and a per-install device id in the platform keystore (encrypted storage on web).
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _device = 'device_id';

  Future<String?> get accessToken => _storage.read(key: _access);
  Future<String?> get refreshToken => _storage.read(key: _refresh);

  Future<void> save(String accessToken, String refreshToken) async {
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }

  /// The backend keeps one refresh token per device, so web and phone sessions don't log each other out.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _device);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _device, value: id);
    return id;
  }
}
