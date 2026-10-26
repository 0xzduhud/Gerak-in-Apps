import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Satu kiriman saran dan kesan (milik siapa pun).
class FeedbackEntry {
  final String id;
  final String saran;
  final String kesan;
  final int? rating;
  final DateTime createdAt;
  final String username;
  final String? photoUrl;

  /// True jika kiriman ini milik pengguna yang sedang login.
  final bool isMine;

  const FeedbackEntry({
    required this.id,
    required this.saran,
    required this.kesan,
    required this.rating,
    required this.createdAt,
    required this.username,
    required this.photoUrl,
    required this.isMine,
  });

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    final photo = map['photo_url']?.toString().trim();
    final name = map['username']?.toString().trim();

    return FeedbackEntry(
      id: map['id']?.toString() ?? '',
      saran: map['saran']?.toString() ?? '',
      kesan: map['kesan']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toInt(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      username: (name == null || name.isEmpty) ? 'Pengguna' : name,
      photoUrl: (photo == null || photo.isEmpty) ? null : photo,
      isMine: map['is_mine'] == true,
    );
  }
}

/// Error dengan pesan berbahasa Indonesia yang aman ditampilkan ke pengguna.
class FeedbackException implements Exception {
  final String message;

  FeedbackException(this.message);

  @override
  String toString() => message;
}

class FeedbackRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Duration _timeout = Duration(seconds: 20);

  /// Kiriman semua pengguna, terbaru lebih dulu.
  Future<List<FeedbackEntry>> fetchAll() async {
    final data = await _call({'action': 'list'});
    final items = data['items'];

    if (items is! List) return [];

    return items
        .whereType<Map>()
        .map((item) => FeedbackEntry.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Mengirim saran dan kesan baru. Mengembalikan data yang tersimpan.
  Future<FeedbackEntry> submit({
    required String saran,
    required String kesan,
    required int rating,
  }) async {
    final data = await _call({
      'action': 'create',
      'saran': saran,
      'kesan': kesan,
      'rating': rating,
    });

    final item = data['item'];
    if (item is! Map) {
      throw FeedbackException('Respons server tidak valid.');
    }

    return FeedbackEntry.fromMap(Map<String, dynamic>.from(item));
  }

  /// Menghapus kiriman milik sendiri.
  Future<void> delete(String id) async {
    await _call({'action': 'delete', 'id': id});
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    if (_supabase.auth.currentSession == null) {
      throw FeedbackException('Sesi login berakhir. Silakan login kembali.');
    }

    try {
      final response = await _supabase.functions
          .invoke('feedback', body: body)
          .timeout(_timeout);

      final data = response.data;
      if (data is Map && data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }

      throw FeedbackException(
        _messageFrom(data) ?? 'Respons server tidak valid.',
      );
    } on FeedbackException {
      rethrow;
    } on FunctionException catch (error) {
      throw FeedbackException(
        _messageFrom(error.details) ??
            'Server sedang bermasalah (${error.status}). Coba lagi nanti.',
      );
    } on TimeoutException {
      throw FeedbackException('Server terlalu lama merespons. Coba lagi.');
    } catch (_) {
      throw FeedbackException(
        'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
      );
    }
  }

  String? _messageFrom(dynamic details) {
    if (details is Map && details['message'] is String) {
      final text = (details['message'] as String).trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
