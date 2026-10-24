import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime savedAt;
  _CacheEntry(this.data, this.savedAt);
}

class AiRecommendationService {
  // Singleton: semua pemanggilan AiRecommendationService() memakai instance
  // yang sama, jadi cache dan penggabungan request bekerja di seluruh app.
  static final AiRecommendationService _instance =
      AiRecommendationService._internal();
  factory AiRecommendationService() => _instance;
  AiRecommendationService._internal();

  final _supabase = Supabase.instance.client;

  // Sudah dites: menjawab ~1-2 detik.
  static const String _model = 'gemini-3.1-flash-lite';

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const int _maxAttempts = 2;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<Map<String, dynamic>?>> _inFlight = {};

  /// Set [forceRefresh] ke true kalau ingin mengabaikan cache
  /// (misalnya untuk tombol "Perbarui rekomendasi").
  Future<Map<String, dynamic>?> getRecommendation(
    String userId, {
    bool forceRefresh = false,
  }) {
    // Pakai hasil yang tersimpan kalau masih baru.
    if (!forceRefresh) {
      final cached = _cache[userId];
      if (cached != null &&
          DateTime.now().difference(cached.savedAt) < _cacheDuration) {
        debugPrint('AI: memakai rekomendasi dari cache');
        return Future.value(cached.data);
      }
    }

    // Kalau sudah ada request yang sedang berjalan, tunggu yang itu saja.
    final running = _inFlight[userId];
    if (running != null) {
      debugPrint('AI: request sudah berjalan, menunggu hasilnya...');
      return running;
    }

    final future = _fetchRecommendation(userId).whenComplete(() {
      _inFlight.remove(userId);
    });
    _inFlight[userId] = future;
    return future;
  }

  Future<Map<String, dynamic>?> _fetchRecommendation(String userId) async {
    try {
      // 1. Ambil data aktivitas terakhir dari Supabase
      final activities = await _supabase
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(3);

      // 2. Ambil data daftar olahraga
      final sports = await _supabase
          .from('sports')
          .select('id, name, body_part');

      // 3. Susun prompt
      final prompt = '''
Kamu adalah asisten kebugaran AI.
Riwayat aktivitas terakhir: ${jsonEncode(activities)}. (Jika kosong, anggap pengguna baru mulai dan butuh olahraga ringan/seluruh tubuh).
Daftar olahraga: ${jsonEncode(sports)}.

Tentukan 1 rekomendasi olahraga dari daftar untuk hari ini.
Wajib kembalikan HANYA format JSON murni persis seperti ini:
{"id_sport": angka_id, "nama_olahraga": "Nama", "alasan": "Alasan 1 kalimat"}
''';

      // 4. Ambil API key dari .env
      final apiKey = dotenv.env['GEMINI_API_KEY']?.trim();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'GEMINI_API_KEY tidak ditemukan. Tambahkan di file .env.',
        );
      }

      // 5. Panggil Gemini, dengan retry kalau menggantung/gagal jaringan
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
      );
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      });

      http.Response? response;
      for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
        debugPrint(
          'AI: mengirim request ke Gemini ($_model), '
          'percobaan $attempt/$_maxAttempts...',
        );
        final stopwatch = Stopwatch()..start();
        try {
          response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': apiKey,
                },
                body: body,
              )
              .timeout(_requestTimeout);
          stopwatch.stop();
          debugPrint(
            'AI: Gemini membalas dalam ${stopwatch.elapsedMilliseconds} ms '
            '(HTTP ${response.statusCode})',
          );
          break;
        } on TimeoutException {
          debugPrint('AI: percobaan $attempt timeout.');
          if (attempt == _maxAttempts) rethrow;
        } on http.ClientException catch (e) {
          debugPrint('AI: percobaan $attempt gagal jaringan: $e');
          if (attempt == _maxAttempts) rethrow;
        }
      }

      if (response == null) return null;

      if (response.statusCode != 200) {
        throw Exception(
          'Gemini menolak request (HTTP ${response.statusCode}): ${response.body}',
        );
      }

      // 6. Ambil teks dari respons dan parsing JSON
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Respons Gemini kosong: ${response.body}');
      }

      String rawText =
          candidates[0]['content']['parts'][0]['text'] as String? ?? '';

      rawText = rawText.replaceAll(RegExp(r'```json\s*'), '');
      rawText = rawText.replaceAll(RegExp(r'```\s*'), '');
      rawText = rawText.trim();

      if (rawText.isEmpty) return null;

      final result = jsonDecode(rawText) as Map<String, dynamic>;

      // Simpan hanya hasil yang berhasil.
      _cache[userId] = _CacheEntry(result, DateTime.now());
      return result;
    } on TimeoutException catch (e) {
      debugPrint('=== ERROR AI REKOMENDASI (TIMEOUT) ===');
      debugPrint(e.toString());
      return null;
    } on http.ClientException catch (e) {
      debugPrint('=== ERROR AI REKOMENDASI (JARINGAN/CORS) ===');
      debugPrint(e.toString());
      return null;
    } catch (e) {
      debugPrint('=== ERROR AI REKOMENDASI ===');
      debugPrint(e.toString());
      return null;
    }
  }
}