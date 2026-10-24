import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gerakinapps/data/models/activity_model.dart';
import 'package:gerakinapps/features/workout/services/step_detector.dart';
import 'package:gerakinapps/features/workout/workout_provider.dart';

/// Sinyal akselerometer sintetis: gravitasi + gelombang langkah + derau.
List<AccelSample> walk(
  double freq,
  double amp,
  double seconds, {
  int hz = 50,
  double noise = 0.5,
  int seed = 1,
  int startMs = 0,
}) {
  final rnd = math.Random(seed);
  final n = (seconds * hz).round();
  return [
    for (var i = 0; i < n; i++)
      AccelSample(
        0.3,
        0.2,
        9.81 +
            amp * math.sin(2 * math.pi * freq * i / hz) +
            (rnd.nextDouble() - 0.5) * noise * 2,
        startMs + (i * 1000 / hz).round(),
      ),
  ];
}

int countSteps(List<AccelSample> samples) {
  final detector = StepDetector();
  for (final s in samples) {
    detector.addSample(s);
  }
  return detector.steps;
}

void main() {
  group('StepDetector', () {
    test('jalan 30 detik terhitung mendekati 54 langkah', () {
      final steps = countSteps(walk(1.8, 2.5, 30));
      expect(steps, inInclusiveRange(51, 57));
    });

    test('diam tidak menghasilkan langkah', () {
      expect(countSteps(walk(0, 0, 60, noise: 0.2)), 0);
    });

    test('sentakan terisolasi tidak dihitung', () {
      final base = walk(0, 0, 10, noise: 0.2);
      final jolts = [
        for (var i = 0; i < base.length; i++)
          AccelSample(
            base[i].x,
            base[i].y,
            base[i].z + ((i == 100 || i == 250 || i == 400) ? 6 : 0),
            base[i].timestampMs,
          ),
      ];
      expect(countSteps(jolts), 0);
    });

    test('jalan, berhenti, jalan lagi', () {
      final samples = [
        ...walk(1.8, 2.5, 10),
        ...walk(0, 0, 5, noise: 0.2, seed: 2, startMs: 10000),
        ...walk(1.8, 2.5, 10, seed: 3, startMs: 15000),
      ];
      expect(countSteps(samples), inInclusiveRange(34, 38));
    });
  });

  group('ActivityMetrics', () {
    test('jarak dan kalori 1000 langkah (tubuh bawaan)', () {
      const body = UserBody();
      final distance = ActivityMetrics.distanceMeters(1000, body);
      expect(distance, closeTo(705.5, 0.1));
      expect(ActivityMetrics.calories(distance, body), closeTo(34.4, 0.1));
    });

    test('ActivitySummary bolak-balik JSON', () {
      final summary = ActivitySummary(
        startedAt: DateTime(2026, 10, 23, 8),
        durationSeconds: 90,
        steps: 120,
        distanceMeters: 84.7,
        calories: 4.1,
        sportId: 'jogging',
      );
      final copy = ActivitySummary.fromJson(summary.toJson());
      expect(copy.steps, 120);
      expect(copy.sportId, 'jogging');
      expect(copy.startedAt, DateTime(2026, 10, 23, 8));
    });
  });

  group('WorkoutSessionProvider', () {
    test('durasi tidak bertambah saat jeda', () {
      var t = DateTime(2026, 1, 1, 8);
      final session = WorkoutSessionProvider(now: () => t);
      addTearDown(session.dispose);

      session.start();
      t = t.add(const Duration(seconds: 30));
      expect(session.elapsed, const Duration(seconds: 30));

      session.pause();
      t = t.add(const Duration(seconds: 100));
      expect(session.elapsed, const Duration(seconds: 30));
      expect(session.state, SessionState.paused);

      session.resume();
      t = t.add(const Duration(seconds: 20));
      final summary = session.finish();

      expect(summary!.durationSeconds, 50);
      expect(session.state, SessionState.finished);
    });

    test('langkah dihitung saat berjalan dan diabaikan saat jeda', () {
      final session = WorkoutSessionProvider();
      addTearDown(session.dispose);

      session.start();
      for (final s in walk(1.8, 2.5, 20)) {
        session.addSample(s);
      }
      final stepsBeforePause = session.steps;
      expect(stepsBeforePause, inInclusiveRange(34, 38));

      session.pause();
      for (final s in walk(1.8, 2.5, 10, seed: 2, startMs: 20000)) {
        session.addSample(s);
      }
      expect(session.steps, stepsBeforePause);

      final summary = session.finish();
      expect(summary!.steps, stepsBeforePause);
      expect(summary.distanceMeters, greaterThan(0));
      expect(summary.calories, greaterThan(0));
    });

    test('start ulang setelah selesai menghapus hasil lama', () {
      final session = WorkoutSessionProvider();
      addTearDown(session.dispose);

      session.start();
      session.finish();
      session.start();

      expect(session.state, SessionState.running);
      expect(session.summary, isNull);
      expect(session.steps, 0);
    });
  });
}