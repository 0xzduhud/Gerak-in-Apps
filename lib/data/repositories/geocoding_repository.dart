import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// ============================================================================
// [PBI-11.4] Pencarian tempat berdasarkan nama/area (Nominatim, OpenStreetMap)
// Aturan Nominatim: maksimal 1 permintaan per detik, tidak boleh dipakai
// untuk saran otomatis saat mengetik, dan aplikasi harus mengenalkan diri.
// ============================================================================
class GeoResult {
  const GeoResult({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
  });

  final String title;
  final String subtitle;
  final double lat;
  final double lng;
}

/// Mengurai jawaban JSON Nominatim (format jsonv2).
List<GeoResult> parseNominatim(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];
  final out = <GeoResult>[];
  for (final e in decoded) {
    if (e is! Map) continue;
    final lat = double.tryParse('${e['lat']}');
    final lng = double.tryParse('${e['lon']}');
    final display = e['display_name']?.toString().trim() ?? '';
    if (lat == null || lng == null || display.isEmpty) continue;

    final parts = display
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final name = e['name']?.toString().trim() ?? '';
    out.add(
      GeoResult(
        title: name.isNotEmpty ? name : parts.first,
        subtitle: parts.length > 1 ? parts.sublist(1).join(', ') : '',
        lat: lat,
        lng: lng,
      ),
    );
  }
  return out;
}

typedef GeocodeFetcher = Future<String> Function(String query);

class GeocodingRepository {
  GeocodingRepository({
    GeocodeFetcher? fetcher,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  })  : _fetcher = fetcher ?? _fetchFromNominatim,
        _now = now ?? DateTime.now,
        _delay = delay ?? ((d) => Future<void>.delayed(d));

  /// Satu instance dipakai bersama supaya pembatas 1 detik berlaku global.
  static final GeocodingRepository shared = GeocodingRepository();

  static const Duration minInterval = Duration(seconds: 1);
  static const int minQueryLength = 3;

  final GeocodeFetcher _fetcher;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  DateTime? _nextSlot;

  static Future<String> _fetchFromNominatim(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '8',
      'accept-language': 'id',
    });
    final response = await http
        .get(
          uri,
          headers: kIsWeb ? null : {'User-Agent': 'Gerakin/1.0 (student project)'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Nominatim error ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  /// Mencari [query]. Jika dipanggil beruntun, permintaan ditunda agar
  /// jaraknya minimal 1 detik (slot dipesan secara sinkron, jadi aman
  /// walau dipanggil bersamaan).
  /// Menjalankan [action] dengan jeda minimal 1 detik dari permintaan
  /// Nominatim sebelumnya (slot dipesan sinkron, jadi aman walau dipanggil
  /// bersamaan). Dipakai bersama oleh pencarian nama dan pencarian tempat.
  Future<T> throttled<T>(Future<T> Function() action) async {
    final now = _now();
    final reserved = _nextSlot;
    final slot =
        (reserved != null && reserved.isAfter(now)) ? reserved : now;
    _nextSlot = slot.add(minInterval);

    final wait = slot.difference(now);
    if (wait > Duration.zero) await _delay(wait);
    return action();
  }

  /// Mencari [query] (nama kota/area).
  Future<List<GeoResult>> search(String query) async {
    final q = query.trim();
    if (q.length < minQueryLength) return const [];
    return throttled(() async => parseNominatim(await _fetcher(q)));
  }
}