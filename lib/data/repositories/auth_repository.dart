import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/secure_storage_service.dart';

class AuthRepository {
  AuthRepository();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Registrasi akun melalui Supabase Auth.
  ///
  /// Username dan nama lengkap disimpan sebagai metadata Auth.
  /// Sinkronisasi profil serta password_hash dilakukan oleh Edge Function
  /// yang akan kita siapkan berikutnya.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username.trim(), 'full_name': fullName.trim()},
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Supabase tidak mengembalikan data akun.');
      }

      final session = response.session;

      // Jika konfirmasi email aktif, sesi bisa belum tersedia.
      // Akun Auth sudah dibuat; profil akan disinkronkan setelah login.
      if (session == null) {
        return {
          'success': true,
          'pending_confirmation': true,
          'user': {
            'auth_user_id': authUser.id,
            'email': authUser.email ?? email.trim(),
            'username': username.trim(),
            'full_name': fullName.trim(),
          },
        };
      }

      final profile = await _syncProfile(password: password);

      return {'success': true, 'token': session.accessToken, 'user': profile};
    } on AuthException catch (error) {
      throw Exception(error.message);
    } on FunctionException catch (error) {
      throw Exception(
        'Akun Auth dibuat, tetapi sinkronisasi profil gagal. '
        'Silakan coba login kembali. Detail: ${error.reasonPhrase ?? error.toString()}',
      );
    }
  }

  /// Login menggunakan kredensial resmi Supabase Auth.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final session = response.session;

      if (session == null || response.user == null) {
        throw Exception('Sesi login tidak berhasil dibuat.');
      }

      final profile = await _syncProfile(password: password);

      return {'success': true, 'token': session.accessToken, 'user': profile};
    } on AuthException catch (error) {
      throw Exception(error.message);
    } on FunctionException catch (error) {
      throw Exception(
        'Login berhasil, tetapi profil gagal dimuat. '
        'Coba login kembali. Detail: ${error.reasonPhrase ?? error.toString()}',
      );
    }
  }

  /// Memvalidasi sesi Supabase dan mengambil profil pengguna.
  Future<Map<String, dynamic>?> validateSession(String token) async {
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session == null || user == null || session.accessToken != token) {
        return null;
      }

      final response = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } on AuthException {
      return null;
    } on PostgrestException {
      return null;
    }
  }

  /// Menyinkronkan profil melalui Edge Function tepercaya.
  ///
  /// Password hanya dikirim melalui HTTPS ke fungsi server untuk
  /// menghasilkan hash tambahan. Password tidak disimpan dalam database.
  Future<Map<String, dynamic>> _syncProfile({required String password}) async {
    final response = await _supabase.functions.invoke(
      'sync-user-profile',
      body: {'password': password},
    );

    final data = response.data;

    if (response.status < 200 ||
        response.status >= 300 ||
        data is! Map ||
        data['success'] != true ||
        data['user'] is! Map) {
      throw Exception(
        data is Map
            ? (data['message']?.toString() ?? 'Sinkronisasi profil gagal.')
            : 'Respons sinkronisasi profil tidak valid.',
      );
    }

    return Map<String, dynamic>.from(data['user'] as Map);
  }

  /// Supabase Flutter mengelola dan menyimpan sesi secara otomatis.
  /// Metode ini dipertahankan untuk kompatibilitas dengan layar lama.
  Future<void> saveSession(String token) async {
    // Tidak perlu menyimpan token secara manual.
    // Sesi dikelola oleh Supabase Auth.
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } finally {
      await SecureStorageService.clearToken();
    }
  }

  /// Mengambil token sesi Supabase aktif.
  Future<String?> getSavedToken() async {
    return _supabase.auth.currentSession?.accessToken;
  }
}
