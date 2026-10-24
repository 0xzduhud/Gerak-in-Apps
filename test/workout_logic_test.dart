import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gerakinapps/data/models/sport_model.dart';
import 'package:gerakinapps/data/repositories/sport_repository.dart';
import 'package:gerakinapps/features/workout/widgets/timer_widgets.dart';
import 'package:gerakinapps/features/workout/workout_provider.dart';

const _json = '''
[
  {"id":"push-up","name":"Push-up","category":"Dada","difficulty":"pemula","kcal_per_minute":7},
  {"id":"burpee","name":"Burpee","category":"Kardio","difficulty":"lanjutan","kcal_per_minute":12,"is_premium":true},
  {"id":"plank","name":"Plank","category":"Perut","difficulty":"pemula","kcal_per_minute":4}
]
''';

class _FakeRepo extends SportRepository {
  @override
  Future<List<Sport>> loadAll() async => SportRepository.parse(_json);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WorkoutProvider> makeProvider() async {
    final p = WorkoutProvider(repository: _FakeRepo());
    await p.load();
    return p;
  }

  test('seed asli valid dan id unik', () {
    final raw = File('assets/data/sports_seed.json').readAsStringSync();
    final sports = SportRepository.parse(raw);
    expect(sports, isNotEmpty);
    expect(sports.map((s) => s.id).toSet().length, sports.length);
    expect(sports.every((s) => s.youtubeUrl.startsWith('https://')), true);
  });

  test('load memuat semua data', () async {
    final p = await makeProvider();
    expect(p.sports.length, 3);
    expect(p.categories, ['Dada', 'Kardio', 'Perut']);
  });

  test('search nama (tidak peka huruf besar/kecil)', () async {
    final p = await makeProvider();
    p.setQuery('  PUSH ');
    expect(p.sports.map((s) => s.id), ['push-up']);
  });

  test('filter kategori dan kesulitan', () async {
    final p = await makeProvider();
    p.setCategory('Kardio');
    p.setDifficulty(Difficulty.lanjutan);
    expect(p.sports.map((s) => s.id), ['burpee']);
    p.resetFilter();
    expect(p.sports.length, 3);
  });

  test('simpan gagal jika belum pilih olahraga', () async {
    final p = await makeProvider();
    expect(await p.savePlan(), false);
    expect(p.error, isNotNull);
  });

  test('simpan gagal jika durasi tidak valid', () async {
    final p = await makeProvider();
    p.selectSport(p.sports.first);
    p.setDuration(0);
    expect(await p.savePlan(), false);
  });

  test('simpan gagal jika target kalori 0', () async {
    final p = await makeProvider();
    p.selectSport(p.sports.first);
    p.setTargetType(TargetType.kalori);
    expect(await p.savePlan(), false);
  });

  test('simpan berhasil dan estimasi kalori benar', () async {
    final p = await makeProvider();
    p.selectSport(p.sports.first); // Push-up, 7 kkal/menit
    p.setDuration(20);
    expect(p.estimatedKcal, 140);
    expect(await p.savePlan(), true);
    expect(p.error, isNull);
  });

    test('ganti olahraga mengembalikan form ke default', () async {
    final p = await makeProvider();
    p.selectSport(p.sports.first);
    p.setTargetType(TargetType.kalori);
    p.setTargetValue(300);
    p.setDuration(45);
    p.selectSport(p.sports[1]);
    expect(p.targetType, TargetType.bebas);
    expect(p.targetValue, 0);
    expect(p.duration, 30);
  });

    test('format stopwatch dan jam', () {
    expect(
      formatStopwatch(const Duration(minutes: 1, seconds: 5, milliseconds: 230)),
      '01:05.23',
    );
    expect(formatStopwatch(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatClock(75), '01:15');
  });
}