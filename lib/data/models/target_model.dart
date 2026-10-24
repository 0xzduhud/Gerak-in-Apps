import '../repositories/activity_repository.dart' show DailyTotals;

// ============================================================================
// [PBI-10.1] DailyTarget — target aktivitas harian
// ============================================================================
class DailyTarget {
  const DailyTarget({
    this.steps = defaultSteps,
    this.durationMinutes = defaultDurationMinutes,
    this.calories = defaultCalories,
  });

  static const int defaultSteps = 8000;
  static const int defaultDurationMinutes = 30;
  static const int defaultCalories = 300;

  static const int minSteps = 1000;
  static const int maxSteps = 30000;
  static const int minDuration = 5;
  static const int maxDuration = 240;
  static const int minCalories = 50;
  static const int maxCalories = 2000;

  final int steps;
  final int durationMinutes;
  final int calories;

  /// Salinan dengan nilai dipaksa masuk rentang yang diizinkan.
  DailyTarget clamped() => DailyTarget(
        steps: steps.clamp(minSteps, maxSteps),
        durationMinutes: durationMinutes.clamp(minDuration, maxDuration),
        calories: calories.clamp(minCalories, maxCalories),
      );

  DailyTarget copyWith({int? steps, int? durationMinutes, int? calories}) =>
      DailyTarget(
        steps: steps ?? this.steps,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        calories: calories ?? this.calories,
      );

  Map<String, dynamic> toJson() => {
        'steps': steps,
        'duration_minutes': durationMinutes,
        'calories': calories,
      };

  /// Nilai yang hilang/rusak diganti nilai bawaan.
  factory DailyTarget.fromJson(Map<String, dynamic> json) => DailyTarget(
        steps: (json['steps'] as num?)?.toInt() ?? defaultSteps,
        durationMinutes:
            (json['duration_minutes'] as num?)?.toInt() ?? defaultDurationMinutes,
        calories: (json['calories'] as num?)?.toInt() ?? defaultCalories,
      ).clamped();

  @override
  bool operator ==(Object other) =>
      other is DailyTarget &&
      other.steps == steps &&
      other.durationMinutes == durationMinutes &&
      other.calories == calories;

  @override
  int get hashCode => Object.hash(steps, durationMinutes, calories);
}

// ============================================================================
// [PBI-10.3] Pengecekan pencapaian target
// ============================================================================

/// Capaian satu jenis target (langkah, durasi, atau kalori).
class MetricProgress {
  const MetricProgress({required this.current, required this.target});

  final double current;
  final double target;

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
  });

  final MetricProgress steps;
  final MetricProgress duration; // satuan: menit
  final MetricProgress calories;

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
      );

  List<MetricProgress> get all => [steps, duration, calories];

  int get achievedCount => all.where((m) => m.achieved).length;

  bool get allAchieved => achievedCount == all.length;

  /// Rata-rata capaian ketiga target (0.0 sampai 1.0).
  double get overallRatio =>
      all.fold<double>(0, (sum, m) => sum + m.ratio) / all.length;
}