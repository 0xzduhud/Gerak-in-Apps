import 'package:flutter/material.dart';

enum Difficulty { pemula, menengah, lanjutan }

extension DifficultyX on Difficulty {
  String get label => switch (this) {
    Difficulty.pemula => 'Pemula',
    Difficulty.menengah => 'Menengah',
    Difficulty.lanjutan => 'Lanjutan',
  };
}

class Sport {
  const Sport({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.equipment,
    required this.sets,
    required this.reps,
    required this.kcalPerMinute,
    required this.description,
    required this.youtubeQuery,
    this.isPremium = false,
  });

  final String id;
  final String name;
  final String category; // kelompok otot / Kardio
  final Difficulty difficulty;
  final String equipment;
  final int sets;
  final String reps;
  final double kcalPerMinute;
  final String description;
  final String youtubeQuery;
  final bool isPremium; // penguncian fitur dikerjakan di Sprint 19

  String get youtubeUrl =>
      'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(youtubeQuery)}';

  /// Icon sementara pengganti gambar, nanti bisa diganti aset gambar.
  IconData get icon => switch (category) {
    'Dada' => Icons.fitness_center_rounded,
    'Punggung' => Icons.accessibility_new_rounded,
    'Bahu' => Icons.sports_gymnastics_rounded,
    'Biceps' || 'Triceps' => Icons.sports_handball_rounded,
    'Kaki' => Icons.directions_walk_rounded,
    'Perut' => Icons.self_improvement_rounded,
    'Kardio' => Icons.directions_run_rounded,
    _ => Icons.fitness_center_rounded,
  };

  int estimateKcal(int minutes) => (kcalPerMinute * minutes).round();

  factory Sport.fromJson(Map<String, dynamic> json) => Sport(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    difficulty:
        Difficulty.values.asNameMap()[json['difficulty']] ?? Difficulty.pemula,
    equipment: json['equipment'] as String? ?? '-',
    sets: json['sets'] as int? ?? 1,
    reps: json['reps'] as String? ?? '-',
    kcalPerMinute: (json['kcal_per_minute'] as num?)?.toDouble() ?? 0,
    description: json['description'] as String? ?? '',
    youtubeQuery: json['youtube_query'] as String? ?? '',
    isPremium: json['is_premium'] as bool? ?? false,
  );
}

enum TargetType { kalori, repetisi, bebas }

extension TargetTypeX on TargetType {
  String get label => switch (this) {
    TargetType.kalori => 'Kalori (kkal)',
    TargetType.repetisi => 'Repetisi',
    TargetType.bebas => 'Tanpa target',
  };
}

/// Pilihan sesi latihan (PBI-7.4 / 7.5).
class WorkoutPlan {
  WorkoutPlan({
    required this.sport,
    required this.targetType,
    required this.targetValue,
    required this.durationMinutes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final Sport sport;
  final TargetType targetType;
  final int targetValue; // 0 jika tanpa target
  final int durationMinutes;
  final DateTime createdAt;

  int get estimatedKcal => sport.estimateKcal(durationMinutes);
}

