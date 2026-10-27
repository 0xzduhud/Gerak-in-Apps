import 'dart:convert';
import 'dart:math' as math;

// ============================================================================
// [PBI-11.3] Place — tempat olahraga dari OpenStreetMap (Overpass API)
// [PBI-11.5] Jarak dari pengguna (rumus haversine)
// ============================================================================
enum PlaceType { gym, park, field }

extension PlaceTypeX on PlaceType {
  String get label => switch (this) {
        PlaceType.gym => 'Gym',
        PlaceType.park => 'Taman',
        PlaceType.field => 'Lapangan',
      };
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    this.address,
    this.openingHours,
    this.distanceMeters,
  });

  /// Contoh: "node/123456" atau "way/789".
  final String id;
  final String name;
  final PlaceType type;
  final double lat;
  final double lng;
  final String? address;
  final String? openingHours;

  /// Jarak dari pengguna (meter). null jika belum dihitung.
  final double? distanceMeters;

  Place copyWith({double? distanceMeters}) => Place(
        id: id,
        name: name,
        type: type,
        lat: lat,
        lng: lng,
        address: address,
        openingHours: openingHours,
        distanceMeters: distanceMeters ?? this.distanceMeters,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'lat': lat,
        'lng': lng,
        'address': address,
        'opening_hours': openingHours,
      };

  static Place? fromJson(Map<String, dynamic> j) {
    final type = PlaceType.values.where((t) => t.name == j['type']);
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final name = j['name']?.toString();
    final id = j['id']?.toString();
    if (type.isEmpty || lat == null || lng == null || name == null || id == null) {
      return null;
    }
    return Place(
      id: id,
      name: name,
      type: type.first,
      lat: lat,
      lng: lng,
      address: j['address']?.toString(),
      openingHours: j['opening_hours']?.toString(),
    );
  }

  /// Mengubah satu elemen Overpass menjadi [Place].
  /// Mengembalikan null jika tidak punya nama, koordinat, atau jenis dikenal.
  static Place? fromOverpass(Map<String, dynamic> e) {
    final tagsRaw = e['tags'];
    if (tagsRaw is! Map) return null;
    final tags = Map<String, dynamic>.from(tagsRaw);

    final name = tags['name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;

        final leisure = tags['leisure']?.toString();
    final sport = tags['sport']?.toString() ?? '';
    final fitnessSport = RegExp(
      r'(^|;)(fitness|bodybuilding|crossfit|yoga|pilates)(;|$)',
    ).hasMatch(sport);

    final PlaceType? type;
    if (leisure == 'fitness_centre' || tags['amenity'] == 'gym') {
      type = PlaceType.gym;
    } else if (leisure == 'park' || leisure == 'fitness_station') {
      type = PlaceType.park;
    } else if (leisure == 'sports_centre' && fitnessSport) {
      type = PlaceType.gym;
    } else if (leisure == 'pitch' ||
        leisure == 'sports_centre' ||
        leisure == 'sports_hall' ||
        leisure == 'stadium' ||
        leisure == 'track') {
      type = PlaceType.field;
    } else if (leisure == null && fitnessSport) {
      type = PlaceType.gym;
    } else {
      type = null;
    }
    if (type == null) return null;

    double? lat = (e['lat'] as num?)?.toDouble();
    double? lng = (e['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      final center = e['center'];
      if (center is Map) {
        lat = (center['lat'] as num?)?.toDouble();
        lng = (center['lon'] as num?)?.toDouble();
      }
    }
    if (lat == null || lng == null) return null;

    final osmType = e['type']?.toString();
    final osmId = e['id']?.toString();
    if (osmType == null || osmId == null) return null;

    final street = [tags['addr:street'], tags['addr:housenumber']]
        .whereType<Object>()
        .map((v) => v.toString().trim())
        .where((v) => v.isNotEmpty)
        .join(' ');
    final city = tags['addr:city']?.toString().trim() ?? '';
    final address = [street, city].where((v) => v.isNotEmpty).join(', ');

    return Place(
      id: '$osmType/$osmId',
      name: name,
      type: type,
      lat: lat,
      lng: lng,
      address: address.isEmpty ? null : address,
      openingHours: tags['opening_hours']?.toString(),
    );
  }
}

/// Menguraikan jawaban JSON Overpass. Duplikat (id sama) dibuang.
List<Place> parseOverpass(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map || decoded['elements'] is! List) return const [];
  final seen = <String>{};
  final out = <Place>[];
  for (final e in decoded['elements'] as List) {
    if (e is! Map) continue;
    final place = Place.fromOverpass(Map<String, dynamic>.from(e));
    if (place != null && seen.add(place.id)) out.add(place);
  }
  return out;
}

/// Jarak dua titik di permukaan bumi (meter), rumus haversine.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(a)));
}

/// 450 -> "450 m", 1234 -> "1.2 km"
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

    /// [PBI-11.6] Tautan rute ke tempat tujuan. Di Android akan membuka
/// aplikasi peta yang terpasang; di web membuka Google Maps di tab baru.
Uri navigationUri(double lat, double lng) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );