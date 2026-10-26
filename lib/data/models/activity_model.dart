/// Data tubuh pengguna untuk estimasi jarak dan kalori.
/// Nilai bawaan dipakai sampai data profil tersedia.
class UserBody {
  const UserBody({this.heightCm = 170, this.weightKg = 65});

  final double heightCm;
  final double weightKg;

  /// Panjang langkah jalan kaki, perkiraan: 41,5% dari tinggi badan.
  double get strideMeters => heightCm * 0.415 / 100;
}

/// Perhitungan jarak dan estimasi kalori (PBI-8.4). Semuanya perkiraan kasar.
class ActivityMetrics {
  ActivityMetrics._();

  /// Perkiraan kalori jalan kaki per kg berat badan per km.
  static const double kcalPerKgPerKm = 0.75;

  static double distanceMeters(int steps, UserBody body) =>
      steps * body.strideMeters;

  static double calories(double distanceMeters, UserBody body) =>
      distanceMeters / 1000 * body.weightKg * kcalPerKgPerKm;
}

/// Hasil satu sesi aktivitas. Dipakai untuk penyimpanan (PBI-8.6)
/// dan kartu Daily Activity (PBI-8.7).
/// Hasil satu sesi aktivitas. Dipakai untuk penyimpanan (PBI-8.6),
/// kartu Daily Activity (PBI-8.7), dan achievement.
class ActivitySummary {
  const ActivitySummary({
    required this.startedAt,
    required this.durationSeconds,
    required this.steps,
    required this.distanceMeters,
    required this.calories,
    this.sportId,
    this.reps = 0,
    this.motionType,
  });

  final DateTime startedAt;
  final int durationSeconds;
  final int steps;
  final double distanceMeters;
  final double calories;
  final String? sportId;

  /// Jumlah repetisi dari Mode Gerakan. 0 untuk sesi langkah biasa.
  final int reps;

  /// Jenis gerakan Mode Gerakan: 'squat', 'pushUp', atau 'jump'. null = sesi biasa.
  final String? motionType;

  Map<String, dynamic> toJson() => {
        'started_at': startedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'steps': steps,
        'distance_meters': distanceMeters,
        'calories': calories,
        'sport_id': sportId,
        'reps': reps,
        'motion_type': motionType,
      };

  factory ActivitySummary.fromJson(Map<String, dynamic> json) =>
      ActivitySummary(
        startedAt: DateTime.parse(json['started_at'] as String),
        durationSeconds: json['duration_seconds'] as int,
        steps: json['steps'] as int,
        distanceMeters: (json['distance_meters'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        sportId: json['sport_id'] as String?,
        // Data lama tidak punya kolom ini -> 0 / null.
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        motionType: json['motion_type'] as String?,
      );
}