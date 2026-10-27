import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = 'gerak_in_session_token';
  static const String _biometricKey = 'gerak_in_biometric_enabled';
  static const String _appProcessKey = 'gerak_in_app_process_started';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled ? 'true' : 'false');
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricKey);
    return value == 'true';
  }

  /// Memeriksa apakah proses aplikasi pernah dimulai sebelumnya.
  static Future<bool> wasAppProcessStarted() async {
    final value = await _storage.read(key: _appProcessKey);
    return value == 'true';
  }

  /// Menandai bahwa proses aplikasi sudah dimulai.
  static Future<void> markAppProcessStarted() async {
    await _storage.write(key: _appProcessKey, value: 'true');
  }
}
