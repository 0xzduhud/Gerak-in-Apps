import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/data/models/activity_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/features/workout/screens/motion_mode_screen.dart';

void main() {
  group('ActivitySummary reps', () {
    test('toJson dan fromJson membawa reps dan motionType', () {
      final s = ActivitySummary(
        startedAt: DateTime(2026, 11, 3, 8),
        durationSeconds: 90,
        steps: 0,
        distanceMeters: 0,
        calories: 0,
        reps: 25,
        motionType: 'squat',
      );
      final back = ActivitySummary.fromJson(s.toJson());
      expect(back.reps, 25);
      expect(back.motionType, 'squat');
    });

    test('data lama tanpa kolom reps -> 0 dan null', () {
      final back = ActivitySummary.fromJson({
        'started_at': DateTime(2026, 11, 3).toIso8601String(),
        'duration_seconds': 60,
        'steps': 100,
        'distance_meters': 70.0,
        'calories': 5.0,
        'sport_id': null,
      });
      expect(back.reps, 0);
      expect(back.motionType, isNull);
    });
  });

  group('MotionSessionProvider.toSummary', () {
    test('null saat belum dimulai', () {
      expect(MotionSessionProvider().toSummary(), isNull);
    });

    test('null jika selesai dengan 0 repetisi', () {
      final p = MotionSessionProvider();
      p.start();
      p.finish();
      expect(p.toSummary(), isNull);
    });
  });
}