import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/core/utils/timezone_converter.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/models/schedule_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/schedule_repository.dart';

class _FakeStore implements ScheduleStore {
  final List<WorkoutSchedule> data = [];
  int _next = 1;

  @override
  Future<List<WorkoutSchedule>> loadAll() async => List.of(data);

  @override
  Future<WorkoutSchedule> upsert(WorkoutSchedule s) async {
    if (s.id == null) {
      final saved = s.copyWith(id: _next++);
      data.add(saved);
      return saved;
    }
    final i = data.indexWhere((e) => e.id == s.id);
    data[i] = s;
    return s;
  }

  @override
  Future<void> delete(int id) async => data.removeWhere((e) => e.id == id);
}

void main() {
  group('PBI-12 TimezoneConverter', () {
    test('WIB -> WITA = +1 jam', () {
      final r = TimezoneConverter.convert(
        DateTime(2026, 11, 3, 10, 30),
        TimezoneConverter.wib,
        TimezoneConverter.wita,
      );
      expect(r.time.hour, 11);
      expect(r.time.minute, 30);
      expect(r.dayShift, 0);
    });

    test('WIB -> WIT = +2 jam', () {
      final r = TimezoneConverter.convert(
        DateTime(2026, 11, 3, 10, 0),
        TimezoneConverter.wib,
        TimezoneConverter.wit,
      );
      expect(r.time.hour, 12);
    });

    test('melewati tengah malam: hari berganti', () {
      final r = TimezoneConverter.convert(
        DateTime(2026, 11, 3, 23, 0),
        TimezoneConverter.wib,
        TimezoneConverter.wit,
      );
      expect(r.time.day, 4);
      expect(r.time.hour, 1);
      expect(r.dayShift, 1);
      expect(TimezoneConverter.dayShiftLabel(r.dayShift), '+1 hari');
    });

    test('Tokyo -> WIB mundur 2 jam, bisa mundur hari', () {
      final r = TimezoneConverter.convert(
        DateTime(2026, 11, 1, 1, 0),
        TimezoneConverter.tokyo,
        TimezoneConverter.wib,
      );
      expect(r.time.month, 10);
      expect(r.time.day, 31);
      expect(r.time.hour, 23);
      expect(r.dayShift, -1);
    });

    test('zona sama tidak mengubah apa pun', () {
      final r = TimezoneConverter.convert(
        DateTime(2026, 5, 5, 6, 7),
        TimezoneConverter.wib,
        TimezoneConverter.wib,
      );
      expect(r.time.hour, 6);
      expect(r.dayShift, 0);
    });

    test('kode tidak dikenal -> WIB', () {
      expect(TimezoneConverter.byCode('XYZ').code, 'WIB');
      expect(TimezoneConverter.byCode(null).code, 'WIB');
    });

    test('format waktu dan tanggal', () {
      expect(TimezoneConverter.formatTime(DateTime(2026, 1, 1, 5, 3)), '05:03');
      expect(
        TimezoneConverter.formatDate(DateTime(2026, 11, 2)), // Senin
        'Sen, 2 Nov 2026',
      );
    });
  });

  group('PBI-12 WorkoutSchedule', () {
    test('validasi judul dan durasi', () {
      final ok = WorkoutSchedule(title: 'Lari', startAt: DateTime(2026, 1, 1));
      expect(ok.validate(), isNull);
      expect(ok.copyWith(title: '  ').validate(), isNotNull);
      expect(ok.copyWith(durationMinutes: 1).validate(), isNotNull);
      expect(ok.copyWith(durationMinutes: 999).validate(), isNotNull);
    });

    test('toJson/fromJson bolak-balik', () {
      final s = WorkoutSchedule(
        id: 3,
        title: 'Gym',
        startAt: DateTime(2026, 11, 3, 18, 15),
        zoneCode: 'WITA',
        durationMinutes: 60,
        note: 'leg day',
        done: true,
      );
      final back = WorkoutSchedule.fromJson({'id': 3, ...s.toJson()});
      expect(back.title, 'Gym');
      expect(back.startAt, DateTime(2026, 11, 3, 18, 15));
      expect(back.zoneCode, 'WITA');
      expect(back.durationMinutes, 60);
      expect(back.done, isTrue);
    });

    test('startUtc memperhitungkan zona', () {
      final s = WorkoutSchedule(
        title: 'x',
        startAt: DateTime(2026, 11, 3, 7, 0),
        zoneCode: 'WIB',
      );
      expect(s.startUtc, DateTime.utc(2026, 11, 3, 0, 0));
    });
  });

  group('PBI-12 ScheduleRepository', () {
    test('diurutkan menurut waktu UTC, bukan jam dinding', () async {
      final repo = ScheduleRepository(store: _FakeStore());
      // 09:00 WIT = 00:00 UTC; 08:00 WIB = 01:00 UTC -> WIT lebih awal.
      await repo.save(WorkoutSchedule(
        title: 'WIB 08:00',
        startAt: DateTime(2026, 11, 3, 8, 0),
        zoneCode: 'WIB',
      ));
      await repo.save(WorkoutSchedule(
        title: 'WIT 09:00',
        startAt: DateTime(2026, 11, 3, 9, 0),
        zoneCode: 'WIT',
      ));
      final list = await repo.all();
      expect(list.first.title, 'WIT 09:00');
    });

    test('save menolak data tidak valid', () async {
      final repo = ScheduleRepository(store: _FakeStore());
      expect(
        () => repo.save(WorkoutSchedule(title: '', startAt: DateTime(2026))),
        throwsArgumentError,
      );
    });

    test('hapus menghilangkan jadwal', () async {
      final repo = ScheduleRepository(store: _FakeStore());
      final s = await repo.save(
        WorkoutSchedule(title: 'a', startAt: DateTime(2026)),
      );
      await repo.delete(s.id!);
      expect(await repo.all(), isEmpty);
    });
  });
}