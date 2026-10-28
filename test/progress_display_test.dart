import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:gerakinapps/data/models/activity_model.dart';
import 'package:gerakinapps/data/models/sport_model.dart';
import 'package:gerakinapps/data/repositories/activity_repository.dart';
import 'package:gerakinapps/features/progress/activity_display.dart';
import 'package:gerakinapps/features/progress/chart_data.dart';

ActivitySummary _a({
  int reps = 0,
  int steps = 0,
  int seconds = 60,
  double meters = 0,
  double kcal = 0,
  String? sportId,
  String? motionType,
  DateTime? at,
}) =>
    ActivitySummary(
      startedAt: at ?? DateTime(2026, 11, 3, 8),
      durationSeconds: seconds,
      steps: steps,
      distanceMeters: meters,
      calories: kcal,
      sportId: sportId,
      reps: reps,
      motionType: motionType,
    );

const _bench = Sport(
  id: 'bench-press',
  name: 'Bench Press',
  category: 'Dada',
  difficulty: Difficulty.pemula,
  equipment: 'Barbell',
  sets: 4,
  reps: '8–12',
  kcalPerMinute: 6,
  description: '',
  youtubeQuery: '',
);

const _jog = Sport(
  id: 'jogging',
  name: 'Jogging',
  category: 'Kardio',
  difficulty: Difficulty.pemula,
  equipment: 'Tanpa alat',
  sets: 1,
  reps: '20–30 menit',
  kcalPerMinute: 9,
  description: '',
  youtubeQuery: '',
);

void main() {
  final sports = {_bench.id: _bench, _jog.id: _jog};

  group('Riwayat: jenis sesi', () {
    test('repetisi = strength, langkah = cardio, sisanya = timed', () {
      expect(kindOf(_a(reps: 10)), ActivityKind.strength);
      expect(kindOf(_a(steps: 100)), ActivityKind.cardio);
      expect(kindOf(_a()), ActivityKind.timed);
    });

    test('repetisi didahulukan jika langkah juga ada', () {
      expect(kindOf(_a(reps: 5, steps: 50)), ActivityKind.strength);
    });
  });

  group('Riwayat: teks tampilan', () {
    test('strength menampilkan repetisi, bukan langkah', () {
      final a = _a(reps: 24, seconds: 125, kcal: 15.4);
      expect(headlineOf(a), '24 repetisi');
      expect(detailOf(a), '2 mnt • 15 kkal');
    });

    test('cardio menampilkan langkah dan jarak', () {
      final a = _a(steps: 1200, meters: 840, seconds: 600, kcal: 60);
      expect(headlineOf(a), '1200 langkah');
      expect(detailOf(a), '10 mnt • 840 m • 60 kkal');
    });

    test('cardio tanpa jarak dan jarak di atas 1 km', () {
      expect(detailOf(_a(steps: 50, seconds: 30, kcal: 2)), '30 dtk • 2 kkal');
      expect(
        detailOf(_a(steps: 5000, meters: 2500, seconds: 1800, kcal: 90)),
        '30 mnt • 2.50 km • 90 kkal',
      );
    });

    test('timed menampilkan durasi sebagai angka utama', () {
      final a = _a(seconds: 45, kcal: 2.6);
      expect(headlineOf(a), '45 dtk');
      expect(detailOf(a), '3 kkal');
    });
  });

  group('Riwayat: judul dan ikon', () {
    test('judul dari data olahraga, id jika tidak dikenal', () {
      expect(titleOf(_a(sportId: 'bench-press'), sports), 'Bench Press');
      expect(titleOf(_a(sportId: 'xyz'), sports), 'xyz');
    });

    test('data lama Mode Gerakan memakai jenis geraknya', () {
      expect(titleOf(_a(reps: 5, motionType: 'squat'), sports), 'Squat');
      expect(titleOf(_a(reps: 5, motionType: 'pushUp'), sports), 'Push-up');
      expect(titleOf(_a(reps: 5, motionType: 'jump'), sports), 'Lompat');
      expect(titleOf(_a(), sports), 'Aktivitas bebas');
    });

    test('ikon mengikuti olahraga, bukan selalu ikon lari', () {
      expect(iconOf(_a(sportId: 'bench-press'), sports), Icons.fitness_center_rounded);
      expect(iconOf(_a(sportId: 'jogging'), sports), Icons.directions_run_rounded);
    });

    test('tanpa data olahraga: ikon menurut jenis sesi', () {
      expect(iconOf(_a(steps: 10), sports), Icons.directions_run_rounded);
      expect(iconOf(_a(reps: 10), sports), Icons.fitness_center_rounded);
    });
  });

  group('DailyTotals.from', () {
    test('menjumlahkan repetisi dan menghitung sesi', () {
      final t = DailyTotals.from([
        _a(reps: 20, seconds: 600, kcal: 50),
        _a(reps: 10, seconds: 300, kcal: 20),
        _a(steps: 1000, seconds: 600, kcal: 40),
      ]);
      expect(t.reps, 30);
      expect(t.sessions, 3);
      expect(t.steps, 1000);
      expect(t.durationSeconds, 1500);
      expect(t.calories, closeTo(110, 1e-9));
    });

    test('tanpa aktivitas: nol', () {
      final t = DailyTotals.from(const []);
      expect(t.sessions, 0);
      expect(t.reps, 0);
    });
  });

  group('Grafik', () {
    test('Durasi adalah pilihan pertama', () {
      expect(ChartMetric.values.first, ChartMetric.duration);
    });

    test('buildBuckets menjumlahkan repetisi dan sesi per hari', () {
      final window = windowFor(ChartRange.weekly, DateTime(2026, 11, 4));
      final buckets = buildBuckets([
        _a(reps: 20, seconds: 600, kcal: 50, at: DateTime(2026, 11, 3, 8)),
        _a(reps: 10, seconds: 300, kcal: 20, at: DateTime(2026, 11, 3, 18)),
        _a(steps: 1000, seconds: 600, kcal: 40, at: DateTime(2026, 11, 2, 7)),
        _a(reps: 99, at: DateTime(2026, 10, 1)), // di luar jendela
      ], window);

      final nov3 = buckets.firstWhere((b) => b.date == DateTime(2026, 11, 3));
      expect(nov3.sessions, 2);
      expect(nov3.reps, 30);
      expect(nov3.minutes, closeTo(15, 1e-9));
      expect(nov3.valueOf(ChartMetric.reps), 30);
      expect(nov3.valueOf(ChartMetric.sessions), 2);

      final nov2 = buckets.firstWhere((b) => b.date == DateTime(2026, 11, 2));
      expect(nov2.steps, 1000);
      expect(nov2.sessions, 1);
    });

    test('summarize menjumlahkan seluruh rentang', () {
      final window = windowFor(ChartRange.weekly, DateTime(2026, 11, 4));
      final s = summarize(
        buildBuckets([
          _a(reps: 20, seconds: 600, kcal: 50, at: DateTime(2026, 11, 3)),
          _a(reps: 10, seconds: 300, kcal: 20, at: DateTime(2026, 11, 3)),
          _a(steps: 1000, seconds: 600, kcal: 40, at: DateTime(2026, 11, 2)),
        ], window),
      );
      expect(s.sessions, 3);
      expect(s.reps, 30);
      expect(s.minutes, closeTo(25, 1e-9));
      expect(s.calories, closeTo(110, 1e-9));
      expect(s.steps, 1000);
    });
  });
}