import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/data/models/place_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/place_repository.dart';

Place? _from(Map<String, String> tags) => Place.fromOverpass({
      'type': 'node',
      'id': 1,
      'lat': -7.4,
      'lon': 111.0,
      'tags': {'name': 'Tempat', ...tags},
    });

void main() {
  group('Jenis tempat dari label OSM', () {
    test('leisure=fitness_centre = Gym', () {
      expect(_from({'leisure': 'fitness_centre'})!.type, PlaceType.gym);
    });

    test('amenity=gym = Gym', () {
      expect(_from({'amenity': 'gym'})!.type, PlaceType.gym);
    });

    test('sports_centre dengan sport=fitness = Gym', () {
      expect(
        _from({'leisure': 'sports_centre', 'sport': 'fitness;yoga'})!.type,
        PlaceType.gym,
      );
    });

    test('sports_centre biasa = Lapangan', () {
      expect(_from({'leisure': 'sports_centre'})!.type, PlaceType.field);
    });

    test('sports_hall dan track = Lapangan', () {
      expect(_from({'leisure': 'sports_hall'})!.type, PlaceType.field);
      expect(_from({'leisure': 'track'})!.type, PlaceType.field);
    });

    test('tanpa leisure tetapi sport=yoga = Gym', () {
      expect(_from({'sport': 'yoga'})!.type, PlaceType.gym);
    });

    test('pitch dengan sport=fitness tetap Lapangan', () {
      expect(
        _from({'leisure': 'pitch', 'sport': 'fitness'})!.type,
        PlaceType.field,
      );
    });

    test('kolam renang dan tempat tanpa label olahraga diabaikan', () {
      expect(_from({'leisure': 'swimming_pool'}), isNull);
      expect(_from({'shop': 'bakery'}), isNull);
    });
  });

  group('Query Overpass', () {
    test('memuat label gym alternatif dan batas hasil 200', () {
      final q = PlaceRepository.buildQuery(-7.4, 111.0, 3000);
      expect(q, contains('"amenity"="gym"'));
      expect(q, contains('"sport"~"fitness|bodybuilding|crossfit|yoga|pilates"'));
      expect(q, contains('"leisure"="sports_hall"'));
      expect(q, contains('around:3000,-7.4,111.0'));
      expect(q, contains('out center 200;'));
    });
  });
}