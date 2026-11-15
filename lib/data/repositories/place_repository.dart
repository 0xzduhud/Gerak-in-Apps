import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_model.dart';

// ============================================================================
// [PBI-11.3] PlaceRepository — Overpass API + Curated Local Dataset + Cache
// ============================================================================

/// Mengirim query Overpass dan mengembalikan isi JSON-nya.
typedef OverpassFetcher = Future<String> Function(String query);

/// Sumber data tempat olahraga.
enum PlacesSource { cache, overpass, nominatim, curated }

class PlacesResult {
  const PlacesResult(
    this.places, {
    this.stale = false,
    this.source = PlacesSource.overpass,
  });

  final List<Place> places;

  /// true = internet gagal, yang ditampilkan adalah data cadangan/cache.
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
  static const String _prefsKey = 'places_cache_v2';
  static const int _maxEntries = 12;

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

  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static const Duration cacheTtl = Duration(hours: 6);
  static const int defaultRadiusMeters = 3000;
  static const int maxResults = 80;

  final OverpassFetcher _fetcher;
  final PlaceCache _cache;
  final DateTime Function() _now;

  /// Daftar tempat olahraga terverifikasi di area Yogyakarta / Sleman / sekitarnya.
  /// Memastikan gym, taman, dan lapangan selalu muncul tanpa pernah kosong (Revisi 3).
  static const List<Place> curatedPlaces = [
    // --- GYM / FITNESS CENTRE ---
    Place(
      id: 'curated/gym/1',
      name: 'FitHub Seturan',
      type: PlaceType.gym,
      lat: -7.7712,
      lng: 110.4101,
      address: 'Jl. Seturan Raya No. 9A, Caturtunggal, Depok, Sleman',
      openingHours: 'Mo-Su 06:00-22:00',
    ),
    Place(
      id: 'curated/gym/2',
      name: 'Powerhouse Gym & Fitness Seturan',
      type: PlaceType.gym,
      lat: -7.7685,
      lng: 110.4082,
      address: 'Jl. Perumnas No. 128, Mundu, Caturtunggal, Sleman',
      openingHours: 'Mo-Sa 07:00-21:00',
    ),
    Place(
      id: 'curated/gym/3',
      name: 'Empire Fit Club Jogja',
      type: PlaceType.gym,
      lat: -7.7589,
      lng: 110.3956,
      address: 'Jl. Candok, Condongcatur, Kec. Depok, Sleman',
      openingHours: 'Mo-Su 06:00-21:00',
    ),
    Place(
      id: 'curated/gym/4',
      name: 'Celebrity Fitness Jogja City Mall',
      type: PlaceType.gym,
      lat: -7.7541,
      lng: 110.3602,
      address: 'Lantai 2 Jogja City Mall, Jl. Magelang KM 6',
      openingHours: 'Mo-Su 06:00-22:00',
    ),
    Place(
      id: 'curated/gym/5',
      name: 'Rai Fitness Yogyakarta',
      type: PlaceType.gym,
      lat: -7.7825,
      lng: 110.3912,
      address: 'Jl. Colombo No. 7, Caturtunggal, Depok, Sleman',
      openingHours: 'Mo-Su 06:00-21:00',
    ),
    Place(
      id: 'curated/gym/6',
      name: 'Sahid Fitness & Aerobic Babarsari',
      type: PlaceType.gym,
      lat: -7.7792,
      lng: 110.4152,
      address: 'Jl. Babarsari No. 2, Caturtunggal, Depok, Sleman',
      openingHours: 'Mo-Sa 06:00-22:00',
    ),
    Place(
      id: 'curated/gym/7',
      name: 'Gold\'s Gym Malioboro',
      type: PlaceType.gym,
      lat: -7.7925,
      lng: 110.3658,
      address: 'Mal Malioboro Lantai 3, Jl. Malioboro No. 52-58',
      openingHours: 'Mo-Su 06:00-22:00',
    ),

    // --- TAMAN / PARK / JOGGING TRACK ---
    Place(
      id: 'curated/park/1',
      name: 'Embung Tambakboyo (Taman & Jogging Track)',
      type: PlaceType.park,
      lat: -7.7582,
      lng: 110.4154,
      address: 'Ngringin, Condongcatur, Kec. Depok, Sleman',
      openingHours: 'Mo-Su 05:00-18:30',
    ),
    Place(
      id: 'curated/park/2',
      name: 'Taman Kuliner & Jogging Condongcatur',
      type: PlaceType.park,
      lat: -7.7561,
      lng: 110.3985,
      address: 'Jl. Anggajaya III, Condongcatur, Depok, Sleman',
      openingHours: 'Mo-Su 06:00-22:00',
    ),
    Place(
      id: 'curated/park/3',
      name: 'Taman Lembah UGM (Outdoor Gym & Jogging)',
      type: PlaceType.park,
      lat: -7.7735,
      lng: 110.3812,
      address: 'Kawasan Lembah UGM, Jl. Karangmalang, Caturtunggal',
      openingHours: 'Mo-Su 05:00-19:00',
    ),
    Place(
      id: 'curated/park/4',
      name: 'Taman Denggung Sleman',
      type: PlaceType.park,
      lat: -7.7165,
      lng: 110.3582,
      address: 'Jl. Magelang KM 9.5, Tridadi, Sleman',
      openingHours: '24 Jam',
    ),
    Place(
      id: 'curated/park/5',
      name: 'Taman Pintar & Area Terbuka Hijau',
      type: PlaceType.park,
      lat: -7.8005,
      lng: 110.3672,
      address: 'Jl. Panembahan Senopati No. 1-3, Gondomanan, Yogyakarta',
      openingHours: 'Mo-Su 06:00-20:00',
    ),
    Place(
      id: 'curated/park/6',
      name: 'Alun-Alun Kidul Yogyakarta (Jogging Track)',
      type: PlaceType.park,
      lat: -7.8118,
      lng: 110.3632,
      address: 'Patehan, Kraton, Kota Yogyakarta',
      openingHours: '24 Jam',
    ),

    // --- LAPANGAN / PUSAT OLAHRAGA ---
    Place(
      id: 'curated/field/1',
      name: 'Stadion Maguwoharjo Sleman',
      type: PlaceType.field,
      lat: -7.7497,
      lng: 110.4282,
      address: 'Jl. Kepuhsari, Maguwoharjo, Kec. Depok, Sleman',
      openingHours: 'Mo-Su 06:00-21:00',
    ),
    Place(
      id: 'curated/field/2',
      name: 'GOR UNY & Lapangan Atletik',
      type: PlaceType.field,
      lat: -7.7725,
      lng: 110.3878,
      address: 'Kompleks Kampus UNY Karangmalang, Caturtunggal',
      openingHours: 'Mo-Su 06:00-22:00',
    ),
    Place(
      id: 'curated/field/3',
      name: 'Meteor Futsal & Badminton Seturan',
      type: PlaceType.field,
      lat: -7.7662,
      lng: 110.4125,
      address: 'Jl. Seturan Raya No. 4, Caturtunggal, Depok, Sleman',
      openingHours: 'Mo-Su 08:00-24:00',
    ),
    Place(
      id: 'curated/field/4',
      name: 'Lapangan Sepak Bola UPN Veteran Yogyakarta',
      type: PlaceType.field,
      lat: -7.7618,
      lng: 110.4095,
      address: 'Jl. SWK 104, Condongcatur, Depok, Sleman',
      openingHours: 'Mo-Su 06:00-18:00',
    ),
    Place(
      id: 'curated/field/5',
      name: 'Stadion Mandala Krida',
      type: PlaceType.field,
      lat: -7.7942,
      lng: 110.3912,
      address: 'Jl. Kenari, Semaki, Umbulharjo, Yogyakarta',
      openingHours: 'Mo-Su 06:00-21:00',
    ),
    Place(
      id: 'curated/field/6',
      name: 'Gelanggang Kridosono Yogyakarta',
      type: PlaceType.field,
      lat: -7.7885,
      lng: 110.3725,
      address: 'Jl. Yos Sudarso No. 1, Kotabaru, Gondokusuman',
      openingHours: 'Mo-Su 06:00-22:00',
    ),
  ];

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
            .timeout(const Duration(seconds: 15));
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

  static String buildQuery(double lat, double lng, int radius) => '''
[out:json][timeout:15];
(
  nwr["leisure"="fitness_centre"]["name"](around:$radius,$lat,$lng);
  nwr["leisure"="park"]["name"](around:$radius,$lat,$lng);
  nwr["leisure"~"^(pitch|sports_centre|stadium)\$"]["name"](around:$radius,$lat,$lng);
);
out center $maxResults;
''';

  static String cacheKey(double lat, double lng, int radius) =>
      '${(lat * 100).round()}_${(lng * 100).round()}_$radius';

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
    if (fresh && !force && cached.places.isNotEmpty) {
      final merged = _mergeCurated(cached.places);
      return PlacesResult(
        _withDistance(merged, oLat, oLng),
        source: PlacesSource.cache,
      );
    }

    try {
      final body = await _fetcher(buildQuery(lat, lng, radius));
      final onlinePlaces = parseOverpass(body);
      final merged = _mergeCurated(onlinePlaces);
      await _cache.write(key, CachedPlaces(_now(), merged));
      return PlacesResult(
        _withDistance(merged, oLat, oLng),
        source: PlacesSource.overpass,
      );
    } catch (_) {
      // Jika jaringan Overpass gagal, gabungkan cache atau pakai curated places
      if (cached != null && cached.places.isNotEmpty) {
        final merged = _mergeCurated(cached.places);
        return PlacesResult(
          _withDistance(merged, oLat, oLng),
          stale: true,
          source: PlacesSource.cache,
        );
      }

      // Fallback tangguh: gunakan curated places sehingga peta tidak pernah kosong!
      return PlacesResult(
        _withDistance(curatedPlaces, oLat, oLng),
        stale: true,
        source: PlacesSource.curated,
      );
    }
  }

  /// Menggabungkan tempat online dengan daftar curated agar Gym, Taman, dan Lapangan selalu lengkap
  List<Place> _mergeCurated(List<Place> onlinePlaces) {
    final Map<String, Place> map = {};

    // 1. Masukkan curated places dulu
    for (final p in curatedPlaces) {
      map[p.name.toLowerCase().trim()] = p;
    }

    // 2. Masukkan online places dari Overpass (menimpa jika ada data live lebih detail)
    for (final p in onlinePlaces) {
      map[p.name.toLowerCase().trim()] = p;
    }

    return map.values.toList();
  }

  List<Place> _withDistance(List<Place> places, double lat, double lng) {
    final list = [
      for (final p in places)
        p.copyWith(distanceMeters: distanceMeters(lat, lng, p.lat, p.lng)),
    ]..sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
    return list.length > maxResults ? list.sublist(0, maxResults) : list;
  }
}
