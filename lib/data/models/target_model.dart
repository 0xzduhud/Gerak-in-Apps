import '../repositories/activity_repository.dart' show DailyTotals;

// ============================================================================
// [PBI-10.1] DailyTarget — target aktivitas harian
// Nilai 0 pada target langkah/repetisi = target itu TIDAK dipakai.
// ============================================================================
class DailyTarget {
  const DailyTarget({
    this.steps = defaultSteps,
    this.durationMinutes = defaultDurationMinutes,
    this.calories = defaultCalories,
    this.reps = defaultReps,
  });

  static const int defaultSteps = 0; // tidak dipakai
  static const int defaultDurationMinutes = 30;
  static const int defaultCalories = 300;
  static const int defaultReps = 50;

  static const int minSteps = 0;
  static const int maxSteps = 30000;
  static const int minDuration = 5;
  static const int maxDuration = 240;
  static const int minCalories = 50;
  static const int maxCalories = 2000;
  static const int minReps = 0;
  static const int maxReps = 1000;

  final int steps;
  final int durationMinutes;
  final int calories;
  final int reps;

  /// Salinan dengan nilai dipaksa masuk rentang yang diizinkan.
  DailyTarget clamped() => DailyTarget(
        steps: steps.clamp(minSteps, maxSteps),
        durationMinutes: durationMinutes.clamp(minDuration, maxDuration),
        calories: calories.clamp(minCalories, maxCalories),
        reps: reps.clamp(minReps, maxReps),
      );

  DailyTarget copyWith({
    int? steps,
    int? durationMinutes,
    int? calories,
    int? reps,
  }) =>
      DailyTarget(
        steps: steps ?? this.steps,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        calories: calories ?? this.calories,
        reps: reps ?? this.reps,
      );

  Map<String, dynamic> toJson() => {
        'steps': steps,
        'duration_minutes': durationMinutes,
        'calories': calories,
        'reps': reps,
      };

  /// Nilai yang hilang/rusak diganti nilai bawaan.
  factory DailyTarget.fromJson(Map<String, dynamic> json) => DailyTarget(
        steps: (json['steps'] as num?)?.toInt() ?? defaultSteps,
        durationMinutes:
            (json['duration_minutes'] as num?)?.toInt() ?? defaultDurationMinutes,
        calories: (json['calories'] as num?)?.toInt() ?? defaultCalories,
        reps: (json['reps'] as num?)?.toInt() ?? defaultReps,
      ).clamped();

  @override
  bool operator ==(Object other) =>
      other is DailyTarget &&
      other.steps == steps &&
      other.durationMinutes == durationMinutes &&
      other.calories == calories &&
      other.reps == reps;

  @override
  int get hashCode => Object.hash(steps, durationMinutes, calories, reps);
}

// ============================================================================
// [PBI-10.3] Pengecekan pencapaian target
// ============================================================================

/// Capaian satu jenis target (durasi, kalori, repetisi, atau langkah).
class MetricProgress {
  const MetricProgress({required this.current, required this.target});

  final double current;
  final double target;

  /// Target dipakai hanya jika nilainya > 0.
  bool get active => target > 0;

  /// 0.0 sampai 1.0 (dipotong di 1.0 walau melebihi target).
  double get ratio =>
      target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();

  /// Persen dibulatkan ke bawah: 99,9% tidak tampil sebagai 100%.
  int get percent => (ratio * 100).floor();

  bool get achieved => target > 0 && current >= target;
}

class TargetProgress {
  const TargetProgress({
    required this.steps,
    required this.duration,
    required this.calories,
    required this.reps,
  });

  final MetricProgress steps;
  final MetricProgress duration; // satuan: menit
  final MetricProgress calories;
  final MetricProgress reps;

  factory TargetProgress.from(DailyTarget target, DailyTotals totals) =>
      TargetProgress(
        steps: MetricProgress(
          current: totals.steps.toDouble(),
          target: target.steps.toDouble(),
        ),
        duration: MetricProgress(
          current: totals.durationSeconds / 60.0,
          target: target.durationMinutes.toDouble(),
        ),
        calories: MetricProgress(
          current: totals.calories,
          target: target.calories.toDouble(),
        ),
        reps: MetricProgress(
          current: totals.reps.toDouble(),
          target: target.reps.toDouble(),
        ),
      );

  /// Hanya target yang dipakai (nilai > 0).
  List<MetricProgress> get all =>
      [duration, calories, reps, steps].where((m) => m.active).toList();

  int get activeCount => all.length;

  int get achievedCount => all.where((m) => m.achieved).length;

  bool get allAchieved => activeCount > 0 && achievedCount == activeCount;

  /// Rata-rata capaian target yang dipakai (0.0 sampai 1.0).
  double get overallRatio => activeCount == 0
      ? 0.0
      : all.fold<double>(0, (sum, m) => sum + m.ratio) / activeCount;
}