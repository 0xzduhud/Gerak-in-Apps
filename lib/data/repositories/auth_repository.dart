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

  Map<String, dynamic> _handleResponse(http.Response response) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw Exception('Respons server tidak valid.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format respons server tidak dikenali.');
    }

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
