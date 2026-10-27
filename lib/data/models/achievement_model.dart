import 'package:flutter/material.dart';

/// Jenis data yang memicu sebuah achievement.
enum AchievementTrigger {
  workoutCount,
  bestSteps,
  gamesPlayed,
  bestTargetScore,
  bestTargetLevel,
}

/// Aturan umum achievement yang bisa diubah di satu tempat.
class AchievementRules {
  AchievementRules._();

  /// Sesi workout baru dihitung untuk achievement bila durasinya minimal
  /// segini. Mencegah achievement didapat dengan menekan Mulai lalu Selesai.
  static const int minSessionSeconds = 60;
}

/// Statistik satu akun. Dipakai untuk mengecek syarat achievement.
class AchievementStats {
  const AchievementStats({
    this.workoutCount = 0,
    this.bestSteps = 0,
    this.gamesPlayed = 0,
    this.bestTargetScore = 0,
    this.bestTargetLevel = 0,
  });

  /// Jumlah sesi workout yang dihitung (durasi minimal sudah terpenuhi).
  final int workoutCount;

  /// Langkah terbanyak dalam satu sesi workout.
  final int bestSteps;

  /// Jumlah game yang diselesaikan (kuis dan Tangkap Target).
  final int gamesPlayed;

  /// Skor tertinggi di Tangkap Target.
  final int bestTargetScore;

  /// Level tertinggi di Tangkap Target.
  final int bestTargetLevel;

  static const AchievementStats empty = AchievementStats();

  int valueFor(AchievementTrigger trigger) => switch (trigger) {
    AchievementTrigger.workoutCount => workoutCount,
    AchievementTrigger.bestSteps => bestSteps,
    AchievementTrigger.gamesPlayed => gamesPlayed,
    AchievementTrigger.bestTargetScore => bestTargetScore,
    AchievementTrigger.bestTargetLevel => bestTargetLevel,
  };

  AchievementStats copyWith({
    int? workoutCount,
    int? bestSteps,
    int? gamesPlayed,
    int? bestTargetScore,
    int? bestTargetLevel,
  }) => AchievementStats(
    workoutCount: workoutCount ?? this.workoutCount,
    bestSteps: bestSteps ?? this.bestSteps,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    bestTargetScore: bestTargetScore ?? this.bestTargetScore,
    bestTargetLevel: bestTargetLevel ?? this.bestTargetLevel,
  );

  Map<String, dynamic> toMap(String userId) => {
    'user_id': userId,
    'workout_count': workoutCount,
    'best_steps': bestSteps,
    'games_played': gamesPlayed,
    'best_target_score': bestTargetScore,
    'best_target_level': bestTargetLevel,
  };

  factory AchievementStats.fromMap(Map<String, dynamic> map) =>
      AchievementStats(
        workoutCount: (map['workout_count'] as num?)?.toInt() ?? 0,
        bestSteps: (map['best_steps'] as num?)?.toInt() ?? 0,
        gamesPlayed: (map['games_played'] as num?)?.toInt() ?? 0,
        bestTargetScore: (map['best_target_score'] as num?)?.toInt() ?? 0,
        bestTargetLevel: (map['best_target_level'] as num?)?.toInt() ?? 0,
      );
}

/// Definisi satu achievement (data tetap, bukan status per akun).
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.trigger,
    required this.threshold,
    this.isPremium = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementTrigger trigger;

  /// Nilai minimal dari [trigger] agar achievement terbuka.
  final int threshold;

  /// Penanda saja. Penguncian premium dikerjakan di sprint berikutnya.
  final bool isPremium;

  bool isMet(AchievementStats stats) => stats.valueFor(trigger) >= threshold;

  /// Progres 0..1 untuk ditampilkan sebagai bar di layar achievement.
  double progress(AchievementStats stats) =>
      (stats.valueFor(trigger) / threshold).clamp(0.0, 1.0);
}

/// Daftar seluruh achievement. Angka syarat bisa diubah di sini.
class AchievementCatalog {
  AchievementCatalog._();

  static const List<AchievementDef> all = [
    AchievementDef(
      id: 'first_workout',
      title: 'Langkah Pertama',
      description: 'Selesaikan 1 sesi workout',
      icon: Icons.directions_run_rounded,
      trigger: AchievementTrigger.workoutCount,
      threshold: 1,
    ),
    AchievementDef(
      id: 'workout_5',
      title: 'Mulai Rutin',
      description: 'Selesaikan 5 sesi workout',
      icon: Icons.fitness_center_rounded,
      trigger: AchievementTrigger.workoutCount,
      threshold: 5,
    ),
    AchievementDef(
      id: 'workout_25',
      title: 'Pejuang Tangguh',
      description: 'Selesaikan 25 sesi workout',
      icon: Icons.military_tech_rounded,
      trigger: AchievementTrigger.workoutCount,
      threshold: 25,
      isPremium: true,
    ),
    AchievementDef(
      id: 'steps_500',
      title: 'Langkah Kilat',
      description: 'Capai 500 langkah dalam satu sesi',
      icon: Icons.directions_walk_rounded,
      trigger: AchievementTrigger.bestSteps,
      threshold: 500,
    ),
    AchievementDef(
      id: 'steps_2000',
      title: 'Langkah Hebat',
      description: 'Capai 2.000 langkah dalam satu sesi',
      icon: Icons.bolt_rounded,
      trigger: AchievementTrigger.bestSteps,
      threshold: 2000,
      isPremium: true,
    ),
    AchievementDef(
      id: 'first_game',
      title: 'Pemain Baru',
      description: 'Selesaikan game pertamamu (kuis atau Tangkap Target)',
      icon: Icons.sports_esports_rounded,
      trigger: AchievementTrigger.gamesPlayed,
      threshold: 1,
    ),
    AchievementDef(
      id: 'target_150',
      title: 'Penangkap Handal',
      description: 'Raih skor 150 atau lebih di Tangkap Target',
      icon: Icons.touch_app_rounded,
      trigger: AchievementTrigger.bestTargetScore,
      threshold: 150,
    ),
    AchievementDef(
      id: 'target_level_5',
      title: 'Master Target',
      description: 'Capai level 5 di Tangkap Target',
      icon: Icons.emoji_events_rounded,
      trigger: AchievementTrigger.bestTargetLevel,
      threshold: 5,
      isPremium: true,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
