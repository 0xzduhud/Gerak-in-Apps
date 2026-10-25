import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/data/models/place_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/place_repository.dart';

const String _sample = '''
{"elements":[
 {"type":"node","id":1,"lat":-7.78,"lon":110.37,
  "tags":{"name":"Gym Satu","leisure":"fitness_centre",
          "addr:street":"Jl. Kaliurang","addr:housenumber":"10"}},
 {"type":"way","id":2,"center":{"lat":-7.79,"lon":110.38},
  "tags":{"name":"Taman Dua","leisure":"park"}},
 {"type":"node","id":3,"lat":-7.77,"lon":110.36,"tags":{"leisure":"park"}},
 {"type":"node","id":4,"lat":-7.77,"lon":110.36,
  "tags":{"name":"Aneh","leisure":"swimming_pool"}},
 {"type":"way","id":5,"tags":{"name":"Tanpa Koordinat","leisure":"pitch"}},
 {"type":"node","id":1,"lat":-7.78,"lon":110.37,
  "tags":{"name":"Gym Satu","leisure":"fitness_centre"}}
]}
''';

class _Fetcher {
  int calls = 0;
  bool fail = false;

  Future<String> call(String query) async {
    calls++;
    if (fail) throw Exception('offline');
    return _sample;
  }
}

void main() {
  group('PBI-11.5 jarak', () {
    test('titik yang sama = 0', () {
      expect(distanceMeters(-7.8, 110.4, -7.8, 110.4), 0);
    });

    test('1 derajat bujur di khatulistiwa sekitar 111,2 km', () {
      expect(distanceMeters(0, 0, 0, 1), closeTo(111195, 100));
    });

    test('simetris', () {
      final a = distanceMeters(-7.78, 110.37, -7.80, 110.40);
      final b = distanceMeters(-7.80, 110.40, -7.78, 110.37);
      expect(a, closeTo(b, 1e-6));
    });

    test('formatDistance', () {
      expect(formatDistance(450), '450 m');
      expect(formatDistance(1234), '1.2 km');
      expect(formatDistance(2500), '2.5 km');
    });
  });

  group('PBI-11.3 parseOverpass', () {
    test('menyaring elemen tak valid dan membuang duplikat', () {
      final places = parseOverpass(_sample);
      expect(places.map((p) => p.id), ['node/1', 'way/2']);
    });

    test('jenis, alamat, dan koordinat pusat way terbaca', () {
      final places = parseOverpass(_sample);
      expect(places[0].type, PlaceType.gym);
      expect(places[0].address, 'Jl. Kaliurang 10');
      expect(places[1].type, PlaceType.park);
      expect(places[1].lat, -7.79);
      expect(places[1].lng, 110.38);
    });

    test('toJson lalu fromJson menghasilkan data yang sama', () {
      final original = parseOverpass(_sample).first;
      final copy = Place.fromJson(original.toJson())!;
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.type, original.type);
      expect(copy.address, original.address);
    });

    test('JSON rusak/kosong tidak melempar', () {
      expect(parseOverpass('{}'), isEmpty);
      expect(parseOverpass('{"elements":"x"}'), isEmpty);
    });
  });

  group('PBI-11.3 PlaceRepository (cache per area)', () {
    late _Fetcher fetcher;
    late DateTime clock;
    late PlaceRepository repo;

    setUp(() {
      fetcher = _Fetcher();
      clock = DateTime(2026, 10, 25, 10);
      repo = PlaceRepository(
        fetcher: fetcher.call,
        cache: MemoryPlaceCache(),
        now: () => clock,
      );
    });

    test('hasil diurutkan dari terdekat dan memuat jarak', () async {
      final r = await repo.nearby(-7.78, 110.37);
      expect(r.places.map((p) => p.id), ['node/1', 'way/2']);
      expect(r.places.first.distanceMeters, closeTo(0, 1));
      expect(r.places.last.distanceMeters, greaterThan(1000));
      expect(r.stale, isFalse);
    });

    test('area yang sama memakai cache (tanpa permintaan baru)', () async {
      await repo.nearby(-7.78, 110.37);
      await repo.nearby(-7.7801, 110.3701);
      expect(fetcher.calls, 1);
    });

    test('cache kedaluwarsa (lewat 6 jam) mengambil ulang', () async {
      await repo.nearby(-7.78, 110.37);
      clock = clock.add(const Duration(hours: 7));
      await repo.nearby(-7.78, 110.37);
      expect(fetcher.calls, 2);
    });

    test('force mengabaikan cache segar', () async {
      await repo.nearby(-7.78, 110.37);
      await repo.nearby(-7.78, 110.37, force: true);
      expect(fetcher.calls, 2);
    });

    test('internet gagal + ada cache lama: stale = true', () async {
      await repo.nearby(-7.78, 110.37);
      clock = clock.add(const Duration(hours: 7));
      fetcher.fail = true;
      final r = await repo.nearby(-7.78, 110.37);
      expect(r.stale, isTrue);
      expect(r.places.length, 2);
    });

    test('internet gagal tanpa cache: error diteruskan', () async {
      fetcher.fail = true;
      expect(repo.nearby(-7.78, 110.37), throwsException);
    });

    test('area berbeda tidak memakai cache area lain', () async {
      await repo.nearby(-7.78, 110.37);
      await repo.nearby(-7.90, 110.50);
      expect(fetcher.calls, 2);
    });
  });
}