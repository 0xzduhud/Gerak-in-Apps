import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/place_model.dart';
import 'geocoding_repository.dart';

// ============================================================================
// [PBI-11.3] Sumber cadangan tempat olahraga: Nominatim (OpenStreetMap).
// Dipakai hanya saat semua server Overpass gagal. Memakai pencarian per
// kategori di dalam area (viewbox + bounded=1), maksimal 1 permintaan/detik.
// Hasilnya bisa lebih sedikit dari Overpass.
// ============================================================================
class Viewbox {
  const Viewbox({
    required this.west,
    required this.north,
    required this.east,
    required this.south,
  });

  final double west;
  final double north;
  final double east;
  final double south;

  /// Format Nominatim: kiri,atas,kanan,bawah (bujur,lintang).
  String get param => '$west,$north,$east,$south';
}

/// Kotak persegi di sekitar titik dengan setengah sisi = [radiusMeters].
Viewbox nominatimViewbox(double lat, double lng, int radiusMeters) {
  const metersPerDegree = 111320.0;
  final dLat = radiusMeters / metersPerDegree;
  final cosLat = math.max(math.cos(lat * math.pi / 180.0).abs(), 0.01);
  final dLng = radiusMeters / (metersPerDegree * cosLat);
  return Viewbox(
    west: lng - dLng,
    north: lat + dLat,
    east: lng + dLng,
    south: lat - dLat,
  );
}

/// Mengurai jawaban Nominatim (jsonv2) menjadi [Place].
/// Hanya objek `leisure` bernama dengan jenis yang dikenal.
List<Place> parseNominatimPlaces(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];
  final seen = <String>{};
  final out = <Place>[];
  for (final e in decoded) {
    if (e is! Map) continue;
    if (e['category'] != 'leisure') continue;

    final lat = double.tryParse('${e['lat']}');
    final lon = double.tryParse('${e['lon']}');
    final name = e['name']?.toString().trim() ?? '';
    final osmType = e['osm_type']?.toString();
    final osmId = e['osm_id']?.toString();
    if (lat == null || lon == null || name.isEmpty) continue;
    if (osmType == null || osmId == null) continue;

    final parts = (e['display_name']?.toString() ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final tags = <String, dynamic>{'name': name, 'leisure': e['type']};
    if (parts.length > 1) tags['addr:street'] = parts[1];
    if (parts.length > 2) tags['addr:city'] = parts[2];
    final extra = e['extratags'];
    if (extra is Map && extra['opening_hours'] != null) {
      tags['opening_hours'] = extra['opening_hours'];
    }

    final place = Place.fromOverpass({
      'type': osmType,
      'id': osmId,
      'lat': lat,
      'lon': lon,
      'tags': tags,
    });
    if (place != null && seen.add(place.id)) out.add(place);
  }
  return out;
}

class NominatimPlaceSource {
  NominatimPlaceSource({
    Future<String> Function(Uri uri)? getBody,
    GeocodingRepository? throttle,
  })  : _get = getBody ?? _httpGet,
        _throttle = throttle ?? GeocodingRepository.shared;

  /// Kata kunci kategori OSM (nilai tag `leisure`) untuk gym, taman, lapangan.
  static const List<String> keywords = [
    'fitness_centre',
    'park',
    'pitch',
    'sports_centre',
  ];

  final Future<String> Function(Uri uri) _get;
  final GeocodingRepository _throttle;

  static Future<String> _httpGet(Uri uri) async {
    final response = await http
        .get(
          uri,
          headers: kIsWeb ? null : {'User-Agent': 'Gerakin/1.0 (student project)'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Nominatim HTTP ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  Uri _uri(String keyword, Viewbox box) =>
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '[$keyword]',
        'format': 'jsonv2',
        'viewbox': box.param,
        'bounded': '1',
        'limit': '40',
        'extratags': '1',
        'accept-language': 'id',
      });

  /// Gagal (melempar) hanya jika SEMUA permintaan gagal; jika sebagian
  /// berhasil, hasil yang ada dikembalikan.
  Future<List<Place>> nearby(double lat, double lng, int radius) async {
    final box = nominatimViewbox(lat, lng, radius);
    final seen = <String>{};
    final out = <Place>[];
    Object? firstError;
    var succeeded = 0;

    for (final keyword in keywords) {
      try {
        final body = await _throttle.throttled(() => _get(_uri(keyword, box)));
        succeeded++;
        for (final p in parseNominatimPlaces(body)) {
          if (seen.add(p.id)) out.add(p);
        }
      } catch (e) {
        firstError ??= e;
      }
    }
    if (succeeded == 0) {
      final msg = '${firstError ?? 'tidak ada jawaban'}'.replaceFirst('Exception: ', '');
      throw Exception('Nominatim: $msg');
    }
    return out;
  }
}