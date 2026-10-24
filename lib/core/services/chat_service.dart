import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Error dari ChatService. [message] sudah berbahasa Indonesia dan
/// aman ditampilkan langsung ke pengguna.
class ChatServiceException implements Exception {
  final String message;
  final int? statusCode;

  ChatServiceException(this.message, {this.statusCode});

  /// True jika pengguna perlu login ulang.
  bool get isUnauthorized => statusCode == 401;

  /// True jika kena batas jumlah pesan per menit.
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}

class ChatService {
  ChatService._internal();
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  // Server memberi batas 20 detik ke Gemini, jadi 35 detik di sini
  // cukup untuk satu putaran penuh.
  static const Duration _timeout = Duration(seconds: 35);

  /// Mengirim percakapan ke Edge Function `chat` dan mengembalikan balasan.
  ///
  /// [messages] berisi map `{'role': 'user' | 'model', 'content': '...'}`
  /// dengan urutan lama ke baru. Pesan terakhir harus dari 'user'.
  /// Server hanya memakai 10 pesan terakhir.
  Future<String> sendMessage(List<Map<String, String>> messages) async {
    if (messages.isEmpty) {
      throw ChatServiceException('Pesan tidak boleh kosong.');
    }

    if (_supabase.auth.currentSession == null) {
      throw ChatServiceException(
        'Sesi login berakhir. Silakan login kembali.',
        statusCode: 401,
      );
    }

    try {
      final response = await _supabase.functions
          .invoke('chat', body: {'messages': messages})
          .timeout(_timeout);

      final data = response.data;
      if (data is Map && data['success'] == true && data['reply'] is String) {
        return (data['reply'] as String).trim();
      }

      throw ChatServiceException(
        _messageFromDetails(data) ?? 'Balasan chatbot tidak valid.',
        statusCode: response.status,
      );
    } on ChatServiceException {
      rethrow;
    } on FunctionException catch (error) {
      // invoke melempar FunctionException untuk status selain 2xx.
      throw ChatServiceException(
        _messageFromDetails(error.details) ?? _fallbackMessage(error.status),
        statusCode: error.status,
      );
    } on TimeoutException {
      throw ChatServiceException(
        'Chatbot terlalu lama merespons. Coba lagi.',
        statusCode: 504,
      );
    } catch (_) {
      // Tidak ada koneksi, DNS gagal, CORS di web, dan sejenisnya.
      throw ChatServiceException(
        'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
      );
    }
  }

  /// Mengambil field `message` dari body error server (Map atau String).
  String? _messageFromDetails(dynamic details) {
    if (details is Map && details['message'] is String) {
      final text = (details['message'] as String).trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _fallbackMessage(int status) {
    switch (status) {
      case 401:
        return 'Sesi login berakhir. Silakan login kembali.';
      case 429:
        return 'Terlalu banyak pesan. Tunggu sebentar lalu coba lagi.';
      case 504:
        return 'Chatbot terlalu lama merespons. Coba lagi.';
      default:
        return 'Chatbot sedang bermasalah. Coba lagi nanti.';
    }
  }
}
