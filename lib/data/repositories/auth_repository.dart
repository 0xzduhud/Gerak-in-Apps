import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/secure_storage_service.dart';

class AuthRepository {
  AuthRepository();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Registrasi menggunakan Supabase Auth.
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
        data: {
          'username': username.trim().toLowerCase(),
          'full_name': fullName.trim(),
        },
      );

      final authUser = response.user;

      if (authUser == null) {
        throw Exception('Supabase tidak mengembalikan data akun.');
      }

      final session = response.session;

      if (session == null) {
        return {
          'success': true,
          'pending_confirmation': true,
          'user': {
            'auth_user_id': authUser.id,
            'email': authUser.email ?? email.trim(),
            'username': username.trim().toLowerCase(),
            'full_name': fullName.trim(),
          },
        };
      }

      final profile = await _syncProfile(password: password);

      return {
        'success': true,
        'token':
            _supabase.auth.currentSession?.accessToken ?? session.accessToken,
        'user': profile,
      };
    } on AuthException catch (error) {
      throw Exception(_translateAuthError(error.message));
    } on FunctionException catch (error) {
      debugPrint(
        '[REGISTER] FunctionException: '
        'status=${error.status}, details=${error.details}',
      );

      throw Exception(
        'Akun Auth dibuat, tetapi sinkronisasi profil gagal. '
        'Silakan coba login kembali.',
      );
    }
  }

  /// Login menggunakan username atau email.
  /// Verifikasi password tetap dilakukan oleh Supabase Auth.
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final totalTimer = Stopwatch()..start();
    var stage = 'Memulai login';

    try {
      // TAHAP 1: Memanggil Edge Function.
      stage = 'Edge Function auth-login-identifier';
      debugPrint('[LOGIN] Memulai Tahap 1: $stage');

      final functionTimer = Stopwatch()..start();

      final response = await _supabase.functions
          .invoke(
            'auth-login-identifier',
            body: {'identifier': identifier.trim(), 'password': password},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Login membutuhkan waktu terlalu lama. '
                'Periksa koneksi internet dan coba lagi.',
              );
            },
          );

      functionTimer.stop();

      debugPrint(
        '[LOGIN] Tahap 1 selesai: '
        '${functionTimer.elapsedMilliseconds} ms',
      );

      final data = response.data;

      // Tangani respons error yang dikembalikan Edge Function.
      if (response.status < 200 ||
          response.status >= 300 ||
          data is! Map ||
          data['success'] != true) {
        final message = data is Map ? data['message']?.toString() : null;

        if (response.status == 401) {
          throw Exception('Email/username atau password salah.');
        }

        if (response.status == 429) {
          throw Exception(
            'Terlalu banyak percobaan login. '
            'Silakan coba lagi nanti.',
          );
        }

        if (response.status == 504) {
          throw Exception('Layanan login kehabisan waktu. Silakan coba lagi.');
        }

        if (response.status >= 500) {
          debugPrint(
            '[LOGIN] Edge Function error: '
            'status=${response.status}, message=$message',
          );

          throw Exception(
            'Layanan login sedang bermasalah. Silakan coba lagi.',
          );
        }

        throw Exception(
          message != null && message.isNotEmpty
              ? message
              : 'Login gagal. Periksa data yang dimasukkan.',
        );
      }

      final refreshToken = data['refresh_token'];

      if (refreshToken is! String || refreshToken.isEmpty) {
        throw Exception('Refresh token tidak ditemukan.');
      }

      // TAHAP 2: Membentuk sesi Supabase.
      stage = 'Pembentukan sesi Supabase';
      debugPrint('[LOGIN] Memulai Tahap 2: $stage');

      final sessionTimer = Stopwatch()..start();

      final sessionResponse = await _supabase.auth
          .setSession(refreshToken)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Pembentukan sesi login membutuhkan waktu terlalu lama. '
                'Silakan coba lagi.',
              );
            },
          );

      sessionTimer.stop();

      debugPrint(
        '[LOGIN] Tahap 2 selesai: '
        '${sessionTimer.elapsedMilliseconds} ms',
      );

      if (sessionResponse.session == null || sessionResponse.user == null) {
        throw Exception('Supabase gagal membentuk sesi login.');
      }

      // TAHAP 3: Sinkronisasi profil pengguna.
      stage = 'Sinkronisasi profil sync-user-profile';
      debugPrint('[LOGIN] Memulai Tahap 3: $stage');

      final profileTimer = Stopwatch()..start();

      final profile = await _syncProfile(password: password).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
            'Sinkronisasi profil membutuhkan waktu terlalu lama. '
            'Silakan coba lagi.',
          );
        },
      );

      profileTimer.stop();

      debugPrint(
        '[LOGIN] Tahap 3 selesai: '
        '${profileTimer.elapsedMilliseconds} ms',
      );

      final activeSession = _supabase.auth.currentSession;

      if (activeSession == null) {
        throw Exception('Sesi login tidak tersedia.');
      }

      debugPrint('[LOGIN] Semua tahap berhasil.');

      return {
        'success': true,
        'token': activeSession.accessToken,
        'user': profile,
      };
    } on AuthException catch (error) {
      debugPrint('[LOGIN] AuthException pada $stage: ${error.message}');

      throw Exception(_translateAuthError(error.message));
    } on FunctionException catch (error) {
      debugPrint(
        '[LOGIN] FunctionException pada $stage: '
        'status=${error.status}, details=${error.details}',
      );

      if (error.status == 401) {
        throw Exception('Email/username atau password salah.');
      }

      if (error.status == 429) {
        throw Exception(
          'Terlalu banyak percobaan login. Silakan coba lagi nanti.',
        );
      }

      if (error.status == 504) {
        throw Exception('Layanan login kehabisan waktu. Silakan coba lagi.');
      }

      throw Exception('Layanan login sedang bermasalah. Silakan coba lagi.');
    } finally {
      totalTimer.stop();

      debugPrint('[LOGIN] Tahap terakhir: $stage');
      debugPrint('[LOGIN] Total waktu: ${totalTimer.elapsedMilliseconds} ms');
    }
  }

  /// Menerjemahkan pesan error autentikasi.
  String _translateAuthError(String message) {
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid login credentials') ||
        normalized.contains('invalid credentials')) {
      return 'Email/username atau password salah.';
    }

    if (normalized.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. '
          'Periksa kotak masuk email kamu.';
    }

    if (normalized.contains('too many requests')) {
      return 'Terlalu banyak percobaan. Silakan coba lagi nanti.';
    }

    return message;
  }

  /// Memperbarui sesi Supabase menggunakan refresh token,
  /// lalu mengambil profil pengguna untuk login biometrik.
  Future<Map<String, dynamic>?> refreshSessionAndGetUser() async {
    try {
      final response = await _supabase.auth.refreshSession();

      final session = response.session;
      final authUser = response.user;

      if (session == null || authUser == null) {
        debugPrint('[BIOMETRIC] Sesi tidak tersedia setelah refresh.');
        return null;
      }

      final profile = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', authUser.id)
          .maybeSingle();

      if (profile == null) {
        debugPrint('[BIOMETRIC] Profil pengguna tidak ditemukan.');
        return null;
      }

      debugPrint('[BIOMETRIC] Sesi berhasil diperbarui.');

      return Map<String, dynamic>.from(profile);
    } on AuthException catch (error) {
      debugPrint('[BIOMETRIC] Refresh sesi gagal: ${error.message}');
      return null;
    } on PostgrestException catch (error) {
      debugPrint('[BIOMETRIC] Pengambilan profil gagal: ${error.message}');
      return null;
    } catch (error, stackTrace) {
      debugPrint('[BIOMETRIC] Pemulihan sesi gagal: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Memvalidasi sesi sebelum pengguna diizinkan masuk ke Home.
  Future<Map<String, dynamic>?> validateSession(String token) async {
    try {
      final session = _supabase.auth.currentSession;

      if (session == null || token.isEmpty) {
        debugPrint('[SESSION] Sesi tidak tersedia.');
        return null;
      }

      // Mempertahankan perilaku validasi sesi yang sudah ada.
      if (session.isExpired) {
        debugPrint('[SESSION] Access token kedaluwarsa. Login diperlukan.');
        return null;
      }

      final response = await _supabase.auth.getUser(session.accessToken);

      final verifiedUser = response.user;

      if (verifiedUser == null) {
        debugPrint('[SESSION] Pengguna tidak valid.');
        return null;
      }

      final profile = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', verifiedUser.id)
          .maybeSingle();

      if (profile == null) {
        debugPrint('[SESSION] Profil tidak ditemukan.');
        return null;
      }

      debugPrint('[SESSION] Sesi valid.');

      return Map<String, dynamic>.from(profile);
    } on AuthException catch (error) {
      debugPrint('[SESSION] Autentikasi gagal: ${error.message}');
      return null;
    } on PostgrestException catch (error) {
      debugPrint('[SESSION] Profil gagal diambil: ${error.message}');
      return null;
    } catch (error, stackTrace) {
      debugPrint('[SESSION] Validasi sesi gagal: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Sinkronisasi profil melalui Edge Function tepercaya.
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

  /// Sesi dikelola oleh Supabase Auth.
  Future<void> saveSession(String token) async {
    // Tidak menyimpan access token secara manual.
  }

  /// Logout dan membersihkan token lama jika ada.
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
