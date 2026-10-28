import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/data/models/place_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/geocoding_repository.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/nominatim_place_source.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/place_repository.dart';

const String _nominatimBody = '''
[
 {"lat":"-7.43","lon":"111.01","name":"Fit Gym","category":"leisure",
  "type":"fitness_centre","osm_type":"node","osm_id":11,
  "display_name":"Fit Gym, Jalan Raya, Sragen, Jawa Tengah",
  "extratags":{"opening_hours":"Mo-Su 06:00-21:00"}},
 {"lat":"-7.44","lon":"111.02","name":"Taman Kota","category":"leisure",
  "type":"park","osm_type":"way","osm_id":12,"display_name":"Taman Kota, Sragen"},
 {"lat":"-7.45","lon":"111.03","name":"Toko","category":"shop",
  "type":"sports","osm_type":"node","osm_id":13,"display_name":"Toko"},
 {"lat":"-7.46","lon":"111.04","name":"","category":"leisure",
  "type":"pitch","osm_type":"node","osm_id":14,"display_name":"X"},
 {"lat":"x","lon":"111.04","name":"Rusak","category":"leisure",
  "type":"pitch","osm_type":"node","osm_id":15,"display_name":"Rusak"}
]
''';

const String _overpassBody = '''
{"elements":[{"type":"node","id":1,"lat":-7.43,"lon":111.01,
 "tags":{"name":"Gym Kota","leisure":"fitness_centre"}}]}
''';

const Place _gym = Place(
  id: 'node/1',
  name: 'Gym',
  type: PlaceType.gym,
  lat: -7.43,
  lng: 111.01,
);

NominatimPlaceSource _source(Future<String> Function(Uri) get) =>
    NominatimPlaceSource(
      getBody: get,
      throttle: GeocodingRepository(
        delay: (d) async {},
        fetcher: (q) async => '[]',
      ),
    );

void main() {
  group('Cadangan Nominatim: pengurai dan kotak area', () {
    test('hanya objek leisure bernama yang valid', () {
      final places = parseNominatimPlaces(_nominatimBody);
      expect(places.map((p) => p.id), ['node/11', 'way/12']);
      expect(places[0].type, PlaceType.gym);
      expect(places[0].address, 'Jalan Raya, Sragen');
      expect(places[0].openingHours, 'Mo-Su 06:00-21:00');
      expect(places[1].type, PlaceType.park);
    });

    test('bukan daftar = kosong', () {
      expect(parseNominatimPlaces('{}'), isEmpty);
    });

    test('kotak area: 111,32 km di khatulistiwa = 1 derajat', () {
      final b = nominatimViewbox(0, 100, 111320);
      expect(b.north, closeTo(1, 1e-9));
      expect(b.south, closeTo(-1, 1e-9));
      expect(b.west, closeTo(99, 1e-9));
      expect(b.east, closeTo(101, 1e-9));
    });
  });

  group('NominatimPlaceSource', () {
    test('mencari 4 kategori, area dibatasi, duplikat dibuang', () async {
      final queries = <String>[];
      Uri? last;
      final s = _source((uri) async {
        queries.add(uri.queryParameters['q']!);
        last = uri;
        return _nominatimBody;
      });
      final r = await s.nearby(-7.43, 111.01, 3000);
      expect(queries, [
        '[fitness_centre]',
        '[park]',
        '[pitch]',
        '[sports_centre]',
      ]);
      expect(last!.queryParameters['bounded'], '1');
      expect(last!.queryParameters.containsKey('viewbox'), isTrue);
      expect(r.map((p) => p.id), ['node/11', 'way/12']);
    });

    test('sebagian gagal: hasil yang ada tetap dikembalikan', () async {
      final s = _source((uri) async {
        if (uri.queryParameters['q'] == '[park]') throw Exception('timeout');
        return _nominatimBody;
      });
      final r = await s.nearby(-7.43, 111.01, 3000);
      expect(r, isNotEmpty);
    });

    test('semua gagal: melempar', () async {
      final s = _source((uri) async => throw Exception('down'));
      expect(s.nearby(-7.43, 111.01, 3000), throwsException);
    });
  });

  group('Balapan server dan pengecekan jawaban', () {
    test('firstSuccess: mengembalikan yang pertama berhasil', () async {
      final r = await firstSuccess<String>({
        'a': () async => throw Exception('gagal cepat'),
        'b': () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 'ok-b';
        },
      });
      expect(r, 'ok-b');
    });

    test('firstSuccess: semua gagal, pesan memuat semuanya', () {
      expect(
        firstSuccess<String>({
          'a': () async => throw Exception('x1'),
          'b': () async => throw Exception('x2'),
        }),
        throwsA(
          predicate(
            (e) => e.toString().contains('a: x1') && e.toString().contains('b: x2'),
          ),
        ),
      );
    });

    test('jawaban Overpass: timeout tersembunyi dianggap gagal', () {
      expect(
        () => ensureValidOverpassBody(
          '{"elements":[],"remark":"runtime error: Query timed out"}',
        ),
        throwsException,
      );
      expect(() => ensureValidOverpassBody('<html>busy</html>'), throwsException);
      expect(() => ensureValidOverpassBody(_overpassBody), returnsNormally);
    });
  });

  group('PlaceRepository dengan cadangan', () {
    test('Overpass sukses: cadangan tidak dipanggil', () async {
      var fallbackCalls = 0;
      final repo = PlaceRepository(
        fetcher: (q) async => _overpassBody,
        fallback: (lat, lng, r) async {
          fallbackCalls++;
          return [_gym];
        },
        cache: MemoryPlaceCache(),
      );
      final r = await repo.nearby(-7.43, 111.01);
      expect(r.source, PlacesSource.overpass);
      expect(fallbackCalls, 0);
    });

    test('Overpass gagal: pakai cadangan dan tidak disimpan di cache', () async {
      var overpassCalls = 0;
      var fallbackCalls = 0;
      final repo = PlaceRepository(
        fetcher: (q) async {
          overpassCalls++;
          throw Exception('timeout');
        },
        fallback: (lat, lng, r) async {
          fallbackCalls++;
          return [_gym];
        },
        cache: MemoryPlaceCache(),
      );
      final r1 = await repo.nearby(-7.43, 111.01);
      expect(r1.source, PlacesSource.nominatim);
      expect(r1.places.length, 1);
      await repo.nearby(-7.43, 111.01);
      expect(overpassCalls, 2); // tidak ada cache yang menghalangi
      expect(fallbackCalls, 2);
    });

    test('keduanya gagal tanpa cache: pesan memuat dua penyebab', () {
      final repo = PlaceRepository(
        fetcher: (q) async => throw Exception('timeout'),
        fallback: (lat, lng, r) async => throw Exception('nominatim down'),
        cache: MemoryPlaceCache(),
      );
      expect(
        repo.nearby(-7.43, 111.01),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('Overpass: timeout') &&
                e.toString().contains('Cadangan: nominatim down'),
          ),
        ),
      );
    });

    test('keduanya gagal tetapi ada cache lama: stale', () async {
      var clock = DateTime(2026, 10, 25, 10);
      var fail = false;
      final repo = PlaceRepository(
        fetcher: (q) async {
          if (fail) throw Exception('timeout');
          return _overpassBody;
        },
        fallback: (lat, lng, r) async => throw Exception('down'),
        cache: MemoryPlaceCache(),
        now: () => clock,
      );
      await repo.nearby(-7.43, 111.01);
      clock = clock.add(const Duration(hours: 7));
      fail = true;
      final r = await repo.nearby(-7.43, 111.01);
      expect(r.stale, isTrue);
      expect(r.places.length, 1);
    });
  });
}