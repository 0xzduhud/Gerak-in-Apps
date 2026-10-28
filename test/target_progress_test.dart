import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/data/models/target_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/activity_repository.dart' show DailyTotals;
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/target_repository.dart';

class _FakeStore implements TargetStore {
  DailyTarget? saved;

  @override
  Future<DailyTarget?> load() async => saved;

  @override
  Future<void> save(DailyTarget target) async => saved = target;
}

void main() {
  const target = DailyTarget(
    steps: 8000,
    durationMinutes: 30,
    calories: 300,
    reps: 50,
  );

  group('PBI-10.1 DailyTarget', () {
    test('nilai bawaan: langkah tidak dipakai, repetisi 50', () {
      const t = DailyTarget();
      expect(t.steps, 0);
      expect(t.durationMinutes, 30);
      expect(t.calories, 300);
      expect(t.reps, 50);
    });

    test('clamped memaksa nilai masuk rentang', () {
      final t = const DailyTarget(
        steps: 999999,
        durationMinutes: 1,
        calories: -5,
        reps: 99999,
      ).clamped();
      expect(t.steps, 30000);
      expect(t.durationMinutes, 5);
      expect(t.calories, 50);
      expect(t.reps, 1000);
    });

    test('langkah dan repetisi boleh 0 (tidak dipakai)', () {
      final t = const DailyTarget(steps: -3, reps: -1).clamped();
      expect(t.steps, 0);
      expect(t.reps, 0);
    });

    test('fromJson memakai bawaan untuk nilai yang hilang', () {
      final t = DailyTarget.fromJson({'steps': 5000});
      expect(t.steps, 5000);
      expect(t.durationMinutes, 30);
      expect(t.calories, 300);
      expect(t.reps, 50);
    });

    test('toJson dan fromJson bolak-balik', () {
      expect(DailyTarget.fromJson(target.toJson()), target);
    });
  });

  group('PBI-10.3 TargetProgress', () {
    test('setengah jalan: belum ada target tercapai', () {
      final p = TargetProgress.from(
        target,
        const DailyTotals(
          steps: 4000,
          durationSeconds: 900,
          calories: 150,
          reps: 25,
        ),
      );
      expect(p.steps.ratio, closeTo(0.5, 1e-9));
      expect(p.duration.ratio, closeTo(0.5, 1e-9));
      expect(p.calories.ratio, closeTo(0.5, 1e-9));
      expect(p.reps.ratio, closeTo(0.5, 1e-9));
      expect(p.activeCount, 4);
      expect(p.achievedCount, 0);
      expect(p.allAchieved, isFalse);
      expect(p.overallRatio, closeTo(0.5, 1e-9));
    });

    test('semua target tercapai', () {
      final p = TargetProgress.from(
        target,
        const DailyTotals(
          steps: 8000,
          durationSeconds: 1800,
          calories: 300,
          reps: 50,
        ),
      );
      expect(p.achievedCount, 4);
      expect(p.allAchieved, isTrue);
      expect(p.overallRatio, closeTo(1.0, 1e-9));
    });

    test('melebihi target: rasio dipotong 1.0 tetapi tercapai', () {
      final p = TargetProgress.from(target, const DailyTotals(steps: 12000));
      expect(p.steps.ratio, 1.0);
      expect(p.steps.achieved, isTrue);
      expect(p.duration.achieved, isFalse);
    });

    test('persen dibulatkan ke bawah (7999/8000 = 99%, belum tercapai)', () {
      final p = TargetProgress.from(target, const DailyTotals(steps: 7999));
      expect(p.steps.percent, 99);
      expect(p.steps.achieved, isFalse);
    });

    test('tanpa aktivitas: semua nol', () {
      final p = TargetProgress.from(target, DailyTotals.empty);
      expect(p.achievedCount, 0);
      expect(p.overallRatio, 0);
    });

    test('target bernilai 0 tidak dihitung', () {
      const t = DailyTarget(
        steps: 0,
        durationMinutes: 30,
        calories: 300,
        reps: 0,
      );
      final p = TargetProgress.from(
        t,
        const DailyTotals(durationSeconds: 1800, calories: 300),
      );
      expect(p.activeCount, 2);
      expect(p.achievedCount, 2);
      expect(p.allAchieved, isTrue);
      expect(p.overallRatio, closeTo(1.0, 1e-9));
      expect(p.steps.active, isFalse);
    });

    test('semua target 0: tidak ada yang dipakai, tidak dianggap tercapai', () {
      const t = DailyTarget(
        steps: 0,
        durationMinutes: 0,
        calories: 0,
        reps: 0,
      );
      final p = TargetProgress.from(t, const DailyTotals(reps: 99));
      expect(p.activeCount, 0);
      expect(p.allAchieved, isFalse);
      expect(p.overallRatio, 0);
    });

    test('repetisi dihitung dari total harian', () {
      final p = TargetProgress.from(target, const DailyTotals(reps: 20));
      expect(p.reps.current, 20);
      expect(p.reps.ratio, closeTo(0.4, 1e-9));
    });
  });

  group('DailyTotals', () {
    test('menjumlahkan repetisi dan jumlah sesi', () {
      // Dibuat lewat konstruktor: logika penjumlahan diuji di
      // progress_display_test.dart (DailyTotals.from).
      const t = DailyTotals(reps: 30, sessions: 2);
      expect(t.reps, 30);
      expect(t.sessions, 2);
    });
  });

  group('TargetRepository', () {
    test('belum pernah diatur: mengembalikan nilai bawaan', () async {
      final repo = TargetRepository(store: _FakeStore());
      expect(await repo.load(), const DailyTarget());
    });

    test('save memaksa rentang dan menyimpan hasilnya', () async {
      final store = _FakeStore();
      final repo = TargetRepository(store: store);
      final saved = await repo.save(const DailyTarget(steps: 999999));
      expect(saved.steps, 30000);
      expect(store.saved, saved);
      expect(await repo.load(), saved);
    });
  });
}