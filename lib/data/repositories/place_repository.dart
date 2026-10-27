import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_model.dart';

// ============================================================================
// [PBI-11.3] PlaceRepository — Overpass API + cache sementara per area
// ============================================================================

/// Mengirim query Overpass dan mengembalikan isi JSON-nya.
typedef OverpassFetcher = Future<String> Function(String query);

class PlacesResult {
  const PlacesResult(this.places, {this.stale = false});

  final List<Place> places;

  /// true = internet gagal, yang ditampilkan adalah data lama dari cache.
  final bool stale;
}

class CachedPlaces {
  const CachedPlaces(this.savedAt, this.places);

  final DateTime savedAt;
  final List<Place> places;
}

abstract class PlaceCache {
  Future<CachedPlaces?> read(String key);
  Future<void> write(String key, CachedPlaces value);
}

class MemoryPlaceCache implements PlaceCache {
  final Map<String, CachedPlaces> _data = {};

  @override
  Future<CachedPlaces?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, CachedPlaces value) async =>
      _data[key] = value;
}

/// Cache tahan restart aplikasi (shared_preferences; jalan di HP dan web).
class PrefsPlaceCache implements PlaceCache {
  static const String _prefsKey = 'places_cache_v1';
  static const int _maxEntries = 8;

  Future<Map<String, dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<CachedPlaces?> read(String key) async {
    final entry = (await _load())[key];
    if (entry is! Map) return null;
    final t = (entry['t'] as num?)?.toInt();
    final items = entry['items'];
    if (t == null || items is! List) return null;
    final places = <Place>[];
    for (final item in items) {
      if (item is! Map) continue;
      final p = Place.fromJson(Map<String, dynamic>.from(item));
      if (p != null) places.add(p);
    }
    return CachedPlaces(DateTime.fromMillisecondsSinceEpoch(t), places);
  }

  @override
  Future<void> write(String key, CachedPlaces value) async {
    final all = await _load();
    all[key] = {
      't': value.savedAt.millisecondsSinceEpoch,
      'items': value.places.map((p) => p.toJson()).toList(),
    };
    // Simpan hanya entri terbaru supaya tidak membengkak.
    if (all.length > _maxEntries) {
      final keys = all.keys.toList()
        ..sort((a, b) => ((all[a] as Map)['t'] as num)
            .compareTo((all[b] as Map)['t'] as num));
      for (final k in keys.take(all.length - _maxEntries)) {
        all.remove(k);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(all));
  }
}

class PlaceRepository {
  PlaceRepository({
    OverpassFetcher? fetcher,
    PlaceCache? cache,
    DateTime Function()? now,
  })  : _fetcher = fetcher ?? _fetchFromOverpass,
        _cache = cache ?? PrefsPlaceCache(),
        _now = now ?? DateTime.now;

  /// Server publik Overpass sering sibuk, jadi ada server cadangan.
  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Cache dianggap segar selama 6 jam.
  static const Duration cacheTtl = Duration(hours: 6);
  static const int defaultRadiusMeters = 3000;
  static const int maxResults = 80;

  final OverpassFetcher _fetcher;
  final PlaceCache _cache;
  final DateTime Function() _now;

  static Future<String> _fetchFromOverpass(String query) async {
    Object? lastError;
    for (final endpoint in _endpoints) {
      final host = Uri.parse(endpoint).host;
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: kIsWeb
                  ? null
                  : {'User-Agent': 'Gerakin/1.0 (student project)'},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          return utf8.decode(response.bodyBytes);
        }
        lastError = 'HTTP ${response.statusCode} dari $host';
      } catch (e) {
        lastError = '$host: $e';
      }
    }
    throw Exception(lastError ?? 'Overpass tidak dapat dihubungi');
  }

  /// Query Overpass: gym, taman, dan lapangan/pusat olahraga bernama.
  static String buildQuery(double lat, double lng, int radius) => '''
[out:json][timeout:25];
(
  nwr["leisure"="fitness_centre"]["name"](around:$radius,$lat,$lng);
  nwr["leisure"="park"]["name"](around:$radius,$lat,$lng);
  nwr["leisure"~"^(pitch|sports_centre|stadium)\$"]["name"](around:$radius,$lat,$lng);
);
out center $maxResults;
''';

  /// Satu sel cache = kira-kira 1 km x 1 km (pembulatan 0,01 derajat).
  static String cacheKey(double lat, double lng, int radius) =>
      '${(lat * 100).round()}_${(lng * 100).round()}_$radius';

  /// Tempat olahraga di sekitar ([lat], [lng]), diurutkan dari yang terdekat.
  /// [force] = abaikan cache segar (tombol muat ulang).
    /// Tempat olahraga di sekitar ([lat], [lng]), diurutkan dari yang terdekat.
  /// [fromLat]/[fromLng] = titik asal perhitungan jarak (bawaan: pusat
  /// pencarian). [force] = abaikan cache segar (tombol muat ulang).
  Future<PlacesResult> nearby(
    double lat,
    double lng, {
    int radius = defaultRadiusMeters,
    bool force = false,
    double? fromLat,
    double? fromLng,
  }) async {
    final oLat = fromLat ?? lat;
    final oLng = fromLng ?? lng;
    final key = cacheKey(lat, lng, radius);
    final cached = await _cache.read(key);

    final fresh =
        cached != null && _now().difference(cached.savedAt) < cacheTtl;
    if (fresh && !force) {
      return PlacesResult(_withDistance(cached.places, oLat, oLng));
    }

    try {
      final body = await _fetcher(buildQuery(lat, lng, radius));
      final places = parseOverpass(body);
      await _cache.write(key, CachedPlaces(_now(), places));
      return PlacesResult(_withDistance(places, oLat, oLng));
    } catch (_) {
      // Internet gagal: pakai data lama jika ada, jika tidak teruskan error.
      if (cached != null) {
        return PlacesResult(
          _withDistance(cached.places, oLat, oLng),
          stale: true,
        );
      }
      rethrow;
    }
  }

  List<Place> _withDistance(List<Place> places, double lat, double lng) {
    final list = [
      for (final p in places)
        p.copyWith(distanceMeters: distanceMeters(lat, lng, p.lat, p.lng)),
    ]..sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
    return list.length > maxResults ? list.sublist(0, maxResults) : list;
  }
}