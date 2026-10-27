import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_model.dart';
import 'nominatim_place_source.dart';

// ============================================================================
// [PBI-11.3] PlaceRepository — Overpass API (dua server, berlomba) +
// cadangan Nominatim + cache sementara per area
// ============================================================================

/// Mengirim query Overpass dan mengembalikan isi JSON-nya.
typedef OverpassFetcher = Future<String> Function(String query);

/// Sumber cadangan saat Overpass gagal.
typedef PlaceFallback = Future<List<Place>> Function(
  double lat,
  double lng,
  int radius,
);

enum PlacesSource { cache, overpass, nominatim }

class PlacesResult {
  const PlacesResult(
    this.places, {
    this.stale = false,
    this.source = PlacesSource.overpass,
  });

  final List<Place> places;

  /// true = internet gagal, yang ditampilkan adalah data lama dari cache.
  final bool stale;

  /// Dari mana data ini berasal.
  final PlacesSource source;
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

String _shortError(Object e) {
  final s = e.toString().replaceFirst('Exception: ', '');
  return s.length > 120 ? '${s.substring(0, 120)}...' : s;
}

/// Menjalankan semua [tasks] bersamaan; mengembalikan hasil yang pertama
/// BERHASIL. Jika semuanya gagal, melempar satu pesan berisi semua kegagalan
/// (berguna untuk mencari penyebab masalah).
Future<T> firstSuccess<T>(Map<String, Future<T> Function()> tasks) {
  if (tasks.isEmpty) {
    return Future<T>.error(Exception('Tidak ada sumber data'));
  }
  final completer = Completer<T>();
  final errors = <String>[];
  var pending = tasks.length;

  tasks.forEach((name, run) {
    Future<T> future;
    try {
      future = run();
    } catch (e) {
      future = Future<T>.error(e);
    }
    future.then(
      (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object e) {
        errors.add('$name: ${_shortError(e)}');
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.completeError(Exception(errors.join(' | ')));
        }
      },
    );
  });
  return completer.future;
}

/// Overpass kadang membalas HTTP 200 tetapi isinya halaman error atau
/// "runtime error ... timed out" dengan hasil kosong. Itu harus dianggap gagal,
/// bukan "tidak ada tempat".
void ensureValidOverpassBody(String body) {
  final t = body.trimLeft();
  if (!t.startsWith('{')) {
    throw Exception('jawaban bukan JSON (server sibuk)');
  }
  if (t.contains('"remark"') &&
      (t.contains('timed out') ||
          t.contains('out of memory') ||
          t.contains('runtime error'))) {
    throw Exception('server kewalahan (query timeout)');
  }
}

class PlaceRepository {
  /// Jika [fetcher] tidak diberikan (pemakaian nyata), sumber cadangan
  /// Nominatim ikut dipakai. Saat pengujian dengan [fetcher] sendiri,
  /// cadangan mati kecuali [fallback] diberikan.
  PlaceRepository({
    OverpassFetcher? fetcher,
    PlaceFallback? fallback,
    PlaceCache? cache,
    DateTime Function()? now,
  })  : _fetcher = fetcher ?? _fetchFromOverpass,
        _fallback =
            fallback ?? (fetcher == null ? NominatimPlaceSource().nearby : null),
        _cache = cache ?? PrefsPlaceCache(),
        _now = now ?? DateTime.now;

  /// Server Overpass publik (kumi.systems kini bernama private.coffee).
  /// Semuanya dicoba bersamaan; tambahkan mirror lain di sini bila perlu.
  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  static const Duration requestTimeout = Duration(seconds: 15);

  /// Cache dianggap segar selama 6 jam.
  static const Duration cacheTtl = Duration(hours: 6);
  static const int defaultRadiusMeters = 3000;
  static const int maxResults = 80;

  final OverpassFetcher _fetcher;
  final PlaceFallback? _fallback;
  final PlaceCache _cache;
  final DateTime Function() _now;

  static Future<String> _getFrom(String endpoint, String query) async {
    final uri = Uri.parse(endpoint).replace(queryParameters: {'data': query});
    final response = await http
        .get(
          uri,
          headers: kIsWeb ? null : {'User-Agent': 'Gerakin/1.0 (student project)'},
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = utf8.decode(response.bodyBytes);
    ensureValidOverpassBody(body);
    return body;
  }

  static Future<String> _fetchFromOverpass(String query) => firstSuccess({
        for (final endpoint in _endpoints)
          Uri.parse(endpoint).host: () => _getFrom(endpoint, query),
      });

  /// Query Overpass: gym, taman, dan lapangan/pusat olahraga bernama.
    /// Batas jumlah hasil dari server. Lebih besar dari [maxResults] karena
  /// Overpass tidak mengurutkan menurut jarak; pemotongan ke 80 terdekat
  /// dilakukan di aplikasi setelah jarak dihitung.
  static const int queryLimit = 200;

  /// Query Overpass: gym (termasuk label alternatif), taman, dan lapangan.
  static String buildQuery(double lat, double lng, int radius) {
    final around = '(around:$radius,$lat,$lng)';
    return '''
[out:json][timeout:12];
(
  nwr["leisure"="fitness_centre"]["name"]$around;
  nwr["amenity"="gym"]["name"]$around;
  nwr["sport"~"fitness|bodybuilding|crossfit|yoga|pilates"]["name"]$around;
  nwr["leisure"="park"]["name"]$around;
  nwr["leisure"="pitch"]["name"]$around;
  nwr["leisure"="sports_centre"]["name"]$around;
  nwr["leisure"="sports_hall"]["name"]$around;
  nwr["leisure"="stadium"]["name"]$around;
  nwr["leisure"="track"]["name"]$around;
);
out center $queryLimit;
''';
  }

  /// Satu sel cache = kira-kira 1 km x 1 km (pembulatan 0,01 derajat).
  static String cacheKey(double lat, double lng, int radius) =>
      '${(lat * 100).round()}_${(lng * 100).round()}_$radius';

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
      return PlacesResult(
        _withDistance(cached.places, oLat, oLng),
        source: PlacesSource.cache,
      );
    }

    // 1) Overpass (beberapa server berlomba)
    Object? overpassError;
    try {
      final body = await _fetcher(buildQuery(lat, lng, radius));
      final places = parseOverpass(body);
      try {
        await _cache.write(key, CachedPlaces(_now(), places));
      } catch (_) {
        // Gagal menyimpan cache tidak boleh membatalkan hasil.
      }
      return PlacesResult(_withDistance(places, oLat, oLng));
    } catch (e) {
      overpassError = e;
    }

    // 2) Cadangan (Nominatim). Hasilnya sengaja tidak disimpan di cache supaya
    //    tidak menghalangi hasil Overpass yang lebih lengkap nanti.
    Object? fallbackError;
    final fallback = _fallback;
    if (fallback != null) {
      try {
        final places = await fallback(lat, lng, radius);
        return PlacesResult(
          _withDistance(places, oLat, oLng),
          source: PlacesSource.nominatim,
        );
      } catch (e) {
        fallbackError = e;
      }
    }

    // 3) Data lama dari cache
    if (cached != null) {
      return PlacesResult(
        _withDistance(cached.places, oLat, oLng),
        stale: true,
        source: PlacesSource.cache,
      );
    }

    // 4) Menyerah, dengan pesan yang memuat semua penyebab
    if (fallback == null) throw overpassError;
    throw Exception(
      'Overpass: ${_shortError(overpassError)} | '
      'Cadangan: ${_shortError(fallbackError ?? 'tidak ada jawaban')}',
    );
  }

  List<Place> _withDistance(List<Place> places, double lat, double lng) {
    final list = [
      for (final p in places)
        p.copyWith(distanceMeters: distanceMeters(lat, lng, p.lat, p.lng)),
    ]..sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
    return list.length > maxResults ? list.sublist(0, maxResults) : list;
  }
}