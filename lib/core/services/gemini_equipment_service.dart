import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/workout/screens/ai_equipment_scanner_screen.dart';

class GeminiEquipmentService {
  GeminiEquipmentService._();
  static final GeminiEquipmentService instance = GeminiEquipmentService._();

  String get apiKey {
    final envKey = dotenv.env['GEMINI_API_KEY']?.trim();
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    return const String.fromEnvironment('GEMINI_API_KEY');
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Menganalisis foto alat gym menggunakan Google Gemini Vision API.
  Future<GymEquipmentInfo?> analyzeEquipmentImage(File imageFile) async {
    try {
      final key = apiKey;
      if (key.isEmpty) {
        debugPrint('Gemini: API Key kosong.');
        return null;
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _getMimeType(imageFile.path);

      // Model aktif Gemini yang mendukung vision multimodal
      const models = ['gemini-3.5-flash-lite', 'gemini-flash-latest', 'gemini-3.8-flash'];

      final prompt = '''
Kamu adalah instruktur kebugaran dan pelatih gym profesional bersertifikasi.
Analisis foto ini untuk mengidentifikasi alat olahraga / gym yang tampak di dalam foto.
Berikan hasil analisis dalam format JSON dengan struktur tepat seperti ini:
{
  "name": "Nama Alat Gym (contoh: Leg Press Machine, Cable Crossover, Smith Machine, Barbell, Dumbbell, Treadmill, dll)",
  "category": "Kategori Alat (contoh: Mesin Kaki / Beban Bebas Dada / Mesin Kabel / Kardio)",
  "targetMuscles": "Daftar otot primer dan sekunder yang dilatih (contoh: Quadriceps, Glutes, Hamstrings)",
  "utility": "Penjelasan fungsi alat, manfaat biomekanik, dan mengapa alat ini efektif.",
  "tutorial": [
    "Langkah 1: Pengaturan posisi dan beban yang aman",
    "Langkah 2: Postur awal dan cengkeraman / dudukan yang benar",
    "Langkah 3: Eksekusi gerakan dengan kontrol penuh dan napas yang tepat",
    "Langkah 4: Rentang gerak dan fase eksentrik/pengembalian beban"
  ],
  "commonMistakes": [
    "Kesalahan 1 yang sering dilakukan pemula",
    "Kesalahan 2 yang berisiko menyebabkan cedera sendi"
  ]
}
Pastikan jawaban dalam Bahasa Indonesia yang jelas, edukatif, dan praktis untuk gym-goer.
''';

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 1500,
          'response_mime_type': 'application/json',
        },
      });

      for (final modelName in models) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$key',
          );

          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: requestBody,
              )
              .timeout(const Duration(seconds: 20));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates.first['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                // Cari part yang memiliki teks JSON
                String? rawText;
                for (final part in parts) {
                  final text = part['text']?.toString();
                  if (text != null && text.trim().isNotEmpty) {
                    rawText = text;
                    break;
                  }
                }

                if (rawText != null) {
                  // Bersihkan markdown jika ada
                  rawText = rawText.replaceAll(RegExp(r'```json\s*'), '');
                  rawText = rawText.replaceAll(RegExp(r'```\s*'), '').trim();

                  // Ambil substring antara { dan } terakhir
                  final startIdx = rawText.indexOf('{');
                  final endIdx = rawText.lastIndexOf('}');
                  if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
                    rawText = rawText.substring(startIdx, endIdx + 1);
                  }

                  final jsonResult = jsonDecode(rawText) as Map<String, dynamic>;
                  final name = jsonResult['name']?.toString() ?? 'Alat Gym';
                  final category = jsonResult['category']?.toString() ?? 'Alat Latihan';
                  final targetMuscles = jsonResult['targetMuscles']?.toString() ?? 'Otot Tubuh';
                  final utility = jsonResult['utility']?.toString() ?? 'Melatih otot tubuh.';

                  final tutorialList = (jsonResult['tutorial'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      <String>[];

                  final mistakesList = (jsonResult['commonMistakes'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      <String>[];

                  debugPrint('Gemini AI berhasil menganalisis alat dengan model $modelName: $name');

                  return GymEquipmentInfo(
                    name: name,
                    category: category,
                    targetMuscles: targetMuscles,
                    utility: utility,
                    tutorial: tutorialList.isNotEmpty
                        ? tutorialList
                        : ['Gunakan alat ini sesuai panduan pelatih gym.'],
                    commonMistakes: mistakesList.isNotEmpty
                        ? mistakesList
                        : ['Hindari mengangkat beban berlebih tanpa pemanasan.'],
                    icon: _getAppropriateIcon('$category $name'),
                    isAiGenerated: true,
                  );
                }
              }
            }
          } else {
            debugPrint(
              'Gemini ($modelName) error ${response.statusCode}: ${response.body}',
            );
          }
        } catch (innerError) {
          debugPrint('Gemini model $modelName gagal, mencoba model cadangan: $innerError');
        }
      }
    } catch (e, stack) {
      debugPrint('Gemini equipment analysis failed: $e\n$stack');
    }

    return null;
  }

  IconData _getAppropriateIcon(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('kaki') || lower.contains('leg') || lower.contains('squat')) {
      return Icons.airline_seat_legroom_extra_rounded;
    }
    if (lower.contains('kabel') || lower.contains('pulley') || lower.contains('cable')) {
      return Icons.cable_rounded;
    }
    if (lower.contains('treadmill') || lower.contains('kardio') || lower.contains('sepeda')) {
      return Icons.directions_run_rounded;
    }
    if (lower.contains('dada') || lower.contains('press') || lower.contains('bench')) {
      return Icons.horizontal_distribute_rounded;
    }
    return Icons.fitness_center_rounded;
  }
}
