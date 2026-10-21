import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/services/secure_storage_service.dart';

class AuthRepository {
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await http
        .post(
          Uri.parse(AppConstants.registerEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'email': email,
            'password': password,
            'full_name': fullName,
          }),
        )
        .timeout(const Duration(seconds: 30));

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse(AppConstants.loginEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>?> validateSession(String token) async {
    final response = await http
        .get(
          Uri.parse(AppConstants.sessionEndpoint),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final decoded = _decodeResponse(response);

    if (response.statusCode == 200 &&
        decoded['success'] == true &&
        decoded['user'] is Map<String, dynamic>) {
      return decoded['user'] as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await logout();
    }

    return null;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      throw Exception('Respons server tidak valid.');
    }

    throw Exception('Format respons server tidak dikenali.');
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = _decodeResponse(response);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded['success'] == true) {
      final token = decoded['token'];

      if (token is! String || token.isEmpty) {
        throw Exception('Token sesi tidak ditemukan.');
      }

      return decoded;
    }

    throw Exception(
      decoded['message']?.toString() ??
          'Permintaan gagal (${response.statusCode}).',
    );
  }

  Future<void> saveSession(String token) async {
    await SecureStorageService.saveToken(token);
  }

  Future<void> logout() async {
    await SecureStorageService.clearToken();
  }

  Future<String?> getSavedToken() async {
    return SecureStorageService.getToken();
  }
}
