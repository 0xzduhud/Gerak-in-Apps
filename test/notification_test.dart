import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/core/utils/reminder_planner.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/models/notification_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/models/schedule_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/notification_repository.dart';

class _MemStore implements NotificationStore {
  List<AppNotification> data = [];

  @override
  Future<List<AppNotification>> load() async => List.of(data);

  @override
  Future<void> save(List<AppNotification> items) async => data = List.of(items);
}

// 18:00 WIB = 11:00 UTC -> pengingat 10:30 UTC.
WorkoutSchedule _schedule({int? id = 1, bool done = false}) => WorkoutSchedule(
      id: id,
      title: 'Lari',
      startAt: DateTime(2026, 11, 3, 18, 0),
      zoneCode: 'WIB',
      durationMinutes: 45,
      done: done,
    );

void main() {
  group('PBI-13 ReminderPlanner.due (dalam aplikasi)', () {
    test('belum waktunya -> kosong', () {
      expect(
        ReminderPlanner.due([_schedule()], DateTime.utc(2026, 11, 3, 10, 29)),
        isEmpty,
      );
    });

    test('lewat waktu pengingat -> satu notifikasi', () {
      final r = ReminderPlanner.due(
        [_schedule()],
        DateTime.utc(2026, 11, 3, 10, 31),
      );
      expect(r.length, 1);
      expect(r.first.title, 'Pengingat: Lari');
      expect(r.first.body, contains('18:00 WIB'));
      expect(r.first.createdAt, DateTime.utc(2026, 11, 3, 10, 30));
    });

    test('jadwal selesai atau tanpa id diabaikan', () {
      final now = DateTime.utc(2026, 11, 3, 10, 31);
      expect(ReminderPlanner.due([_schedule(done: true)], now), isEmpty);
      expect(ReminderPlanner.due([_schedule(id: null)], now), isEmpty);
    });

    test('jadwal lebih dari 24 jam lalu diabaikan', () {
      expect(
        ReminderPlanner.due([_schedule()], DateTime.utc(2026, 11, 5, 12, 0)),
        isEmpty,
      );
    });

    test('ID berubah jika jam jadwal diubah', () {
      final a = ReminderPlanner.notificationId(_schedule());
      final b = ReminderPlanner.notificationId(
        _schedule().copyWith(startAt: DateTime(2026, 11, 3, 19, 0)),
      );
      expect(a, isNot(b));
    });
  });

  group('PBI-13B ReminderPlanner.upcoming (alarm sistem)', () {
    test('pengingat di masa depan dijadwalkan tepat waktu', () {
      final r = ReminderPlanner.upcoming(
        [_schedule()],
        DateTime.utc(2026, 11, 3, 10, 0),
      );
      expect(r.length, 1);
      expect(r.first.id, 1);
      expect(r.first.fireAtUtc, DateTime.utc(2026, 11, 3, 10, 30));
      expect(r.first.title, 'Pengingat: Lari');
    });

    test('waktu pengingat sudah lewat -> tidak dijadwalkan sistem', () {
      expect(
        ReminderPlanner.upcoming(
          [_schedule()],
          DateTime.utc(2026, 11, 3, 10, 31),
        ),
        isEmpty,
      );
    });

    test('jadwal selesai atau tanpa id dilewati', () {
      final now = DateTime.utc(2026, 11, 3, 9, 0);
      expect(ReminderPlanner.upcoming([_schedule(done: true)], now), isEmpty);
      expect(ReminderPlanner.upcoming([_schedule(id: null)], now), isEmpty);
    });

    test('urut dari yang paling dekat', () {
      final later = _schedule(id: 2).copyWith(
        startAt: DateTime(2026, 11, 4, 18, 0),
      );
      final r = ReminderPlanner.upcoming(
        [later, _schedule(id: 1)],
        DateTime.utc(2026, 11, 3, 9, 0),
      );
      expect(r.map((e) => e.id).toList(), [1, 2]);
    });
  });

  group('PBI-13 NotificationRepository', () {
    final item = AppNotification(
      id: 'a',
      title: 't',
      body: 'b',
      createdAt: DateTime.utc(2026, 11, 3, 10, 30),
    );

    test('addNew tidak membuat dobel', () async {
      final repo = NotificationRepository(store: _MemStore());
      expect(await repo.addNew([item]), 1);
      expect(await repo.addNew([item]), 0);
      expect((await repo.all()).length, 1);
    });

    test('hapus menyembunyikan dan tidak muncul lagi saat addNew', () async {
      final repo = NotificationRepository(store: _MemStore());
      await repo.addNew([item]);
      await repo.delete('a');
      expect(await repo.all(), isEmpty);
      expect(await repo.addNew([item]), 0);
      expect(await repo.all(), isEmpty);
    });

    test('markRead dan markAllRead', () async {
      final repo = NotificationRepository(store: _MemStore());
      await repo.addNew([
        item,
        AppNotification(
          id: 'b',
          title: 't2',
          body: 'b2',
          createdAt: DateTime.utc(2026, 11, 3, 11, 0),
        ),
      ]);
      await repo.markRead('a');
      var list = await repo.all();
      expect(list.first.id, 'b'); // terbaru di atas
      expect(list.where((n) => n.read).length, 1);
      await repo.markAllRead();
      list = await repo.all();
      expect(list.every((n) => n.read), isTrue);
    });

    test('clearAll menyembunyikan semua', () async {
      final repo = NotificationRepository(store: _MemStore());
      await repo.addNew([item]);
      await repo.clearAll();
      expect(await repo.all(), isEmpty);
    });

    test('toJson/fromJson bolak-balik', () {
      final back = AppNotification.fromJson(item.toJson());
      expect(back.id, 'a');
      expect(back.createdAt, item.createdAt);
      expect(back.read, isFalse);
    });
  });

  group('PBI-13 pruneSchedule', () {
    final old = AppNotification(
      id: 'schedule:1:2026-11-03T11:00:00.000Z',
      title: 't',
      body: 'b',
      createdAt: DateTime.utc(2026, 11, 3, 10, 30),
    );

    test('ID tidak sah disembunyikan, yang sah dipertahankan', () async {
      final repo = NotificationRepository(store: _MemStore());
      await repo.addNew([old]);
      await repo.pruneSchedule({old.id});
      expect((await repo.all()).length, 1);
      await repo.pruneSchedule({});
      expect(await repo.all(), isEmpty);
    });

    test('notifikasi non-jadwal tidak ikut dibuang', () async {
      final repo = NotificationRepository(store: _MemStore());
      await repo.addNew([
        AppNotification(
          id: 'sys:1',
          title: 's',
          body: 'b',
          createdAt: DateTime.utc(2026, 11, 3),
          kind: AppNotification.kindSystem,
        ),
      ]);
      await repo.pruneSchedule({});
      expect((await repo.all()).length, 1);
    });
  });
}