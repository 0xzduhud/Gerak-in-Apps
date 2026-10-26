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

  // Model utama dan cadangan. Keduanya sudah dites menjawab ~1-2 detik.
  static const List<String> _models = [
    'gemini-3.1-flash-lite',
    'gemini-flash-lite-latest',
  ];

  // Urutan percobaan (indeks ke _models): utama, cadangan, utama lagi.
  static const List<int> _attemptOrder = [0, 1, 0];

  // Jeda sebelum percobaan terakhir.
  static const Duration _retryDelay = Duration(seconds: 2);

  // Status yang biasanya sementara (server sibuk/kuota): layak dicoba lagi.
  static const Set<int> _retryableStatus = {429, 500, 502, 503, 504};

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _requestTimeout = Duration(seconds: 15);

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
      final prompt =
          '''
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

      // 5. Panggil Gemini. Server sibuk (503, dll.) dicoba lagi,
      // berpindah ke model cadangan bila perlu.
      http.Response? response;
      String lastProblem = 'tidak diketahui';

      for (var attempt = 0; attempt < _attemptOrder.length; attempt++) {
        final model = _models[_attemptOrder[attempt]];

        if (attempt == _attemptOrder.length - 1) {
          await Future<void>.delayed(_retryDelay);
        }

        debugPrint(
          'AI: mengirim request ke Gemini ($model), '
          'percobaan ${attempt + 1}/${_attemptOrder.length}...',
        );

        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );
        final stopwatch = Stopwatch()..start();

        try {
          final result = await http
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
            '(HTTP ${result.statusCode})',
          );

          if (result.statusCode == 200) {
            response = result;
            break;
          }

          // Sementara (sibuk/kuota) atau model sudah dihentikan (404):
          // coba percobaan berikutnya.
          if (_retryableStatus.contains(result.statusCode) ||
              result.statusCode == 404) {
            lastProblem = 'HTTP ${result.statusCode}: ${result.body}';
            continue;
          }

          // Selain itu (400, 403, dst.) bukan masalah sementara.
          throw Exception(
            'Gemini menolak request (HTTP ${result.statusCode}): ${result.body}',
          );
        } on TimeoutException {
          lastProblem = 'timeout';
          debugPrint('AI: percobaan ${attempt + 1} timeout.');
        } on http.ClientException catch (e) {
          lastProblem = 'jaringan: $e';
          debugPrint('AI: percobaan ${attempt + 1} gagal jaringan: $e');
        }
      }

      if (response == null) {
        throw Exception(
          'Gemini belum bisa dihubungi setelah ${_attemptOrder.length} '
          'percobaan. Terakhir: $lastProblem',
        );
      }

      // 6. Ambil teks dari respons dan parsing JSON
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Respons Gemini kosong: ${response.body}');
      }

      final parts = candidates[0]['content']?['parts'] as List?;
      String rawText =
          (parts != null && parts.isNotEmpty
              ? parts[0]['text'] as String?
              : null) ??
          '';

      rawText = rawText.replaceAll(RegExp(r'```json\s*'), '');
      rawText = rawText.replaceAll(RegExp(r'```\s*'), '');
      rawText = rawText.trim();

      if (rawText.isEmpty) return null;

      final result = jsonDecode(rawText) as Map<String, dynamic>;

      // Simpan hanya hasil yang berhasil.
      _cache[userId] = _CacheEntry(result, DateTime.now());
      return result;
    } catch (e) {
      debugPrint('=== ERROR AI REKOMENDASI ===');
      debugPrint(e.toString());
      return null;
    }
  }
}
