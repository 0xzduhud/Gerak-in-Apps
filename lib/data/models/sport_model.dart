import 'package:flutter/material.dart';

enum Difficulty { pemula, menengah, lanjutan }

extension DifficultyX on Difficulty {
  String get label => switch (this) {
    Difficulty.pemula => 'Pemula',
    Difficulty.menengah => 'Menengah',
    Difficulty.lanjutan => 'Lanjutan',
  };
}

/// Jenis tampilan sesi untuk sebuah olahraga.
enum TrackingMode { cardio, reps, timed }

extension TrackingModeX on TrackingMode {
  String get label => switch (this) {
    TrackingMode.cardio => 'Kardio (durasi dan jarak)',
    TrackingMode.reps => 'Set dan repetisi',
    TrackingMode.timed => 'Set berdurasi',
  };
}

/// Tempat HP diletakkan agar sensor ikut bergerak bersama latihan.
enum Placement { pocket, forearm, chest, machine }

extension PlacementX on Placement {
  String get label => switch (this) {
    Placement.pocket => 'Saku celana',
    Placement.forearm => 'Lengan bawah',
    Placement.chest => 'Dada atau punggung atas',
    Placement.machine => 'Tumpukan beban mesin',
  };

  String get hint => switch (this) {
    Placement.pocket =>
      'Masukkan HP ke saku celana di sisi paha, layar menghadap badan.',
    Placement.forearm =>
      'Pasang HP di armband lengan bawah, atau genggam erat bersama beban.',
    Placement.chest =>
      'Taruh HP di dada atau punggung atas dan jaga tetap stabil.',
    Placement.machine =>
      'Letakkan HP di atas tumpukan beban mesin. Pastikan tidak bisa jatuh.',
  };

  IconData get icon => switch (this) {
    Placement.pocket => Icons.checkroom_rounded,
    Placement.forearm => Icons.watch_rounded,
    Placement.chest => Icons.accessibility_new_rounded,
    Placement.machine => Icons.vertical_align_center_rounded,
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
    this.tracking = TrackingMode.reps,
    this.placement = Placement.pocket,
    this.perSide = false,
    this.restSeconds = 60,
  });

  final String id;
  final String name;
  final String category; // kelompok otot / Kardio
  final Difficulty difficulty;
  final String equipment;
  final int sets;
  final String reps; // teks tampilan, mis. "8–12" atau "30 detik"
  final double kcalPerMinute;
  final String description;
  final String youtubeQuery;
  final bool isPremium; // penguncian fitur dikerjakan di Sprint 19

  /// Menentukan isi layar sesi: kardio, set dan repetisi, atau set berdurasi.
  final TrackingMode tracking;

  /// Panduan tempat HP agar sensor bisa menghitung.
  final Placement placement;

  /// true jika repetisi dihitung per sisi (mis. dumbbell row).
  final bool perSide;

  /// Waktu istirahat antar set dalam detik (0 = tanpa istirahat).
  final int restSeconds;

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

  // Tebakan bila JSON lama belum punya field "tracking" atau "placement".
  static TrackingMode _inferTracking(String reps) {
    final r = reps.toLowerCase();
    if (r.contains('menit')) return TrackingMode.cardio;
    if (r.contains('detik')) return TrackingMode.timed;
    return TrackingMode.reps;
  }

  static Placement _inferPlacement(String category) => switch (category) {
    'Dada' || 'Punggung' || 'Bahu' || 'Biceps' || 'Triceps' =>
      Placement.forearm,
    'Perut' => Placement.chest,
    _ => Placement.pocket,
  };

  factory Sport.fromJson(Map<String, dynamic> json) {
    final repsText = json['reps'] as String? ?? '-';
    final category = json['category'] as String;
    return Sport(
      id: json['id'] as String,
      name: json['name'] as String,
      category: category,
      difficulty:
          Difficulty.values.asNameMap()[json['difficulty']] ??
          Difficulty.pemula,
      equipment: json['equipment'] as String? ?? '-',
      sets: json['sets'] as int? ?? 1,
      reps: repsText,
      kcalPerMinute: (json['kcal_per_minute'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      youtubeQuery: json['youtube_query'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
      tracking:
          TrackingMode.values.asNameMap()[json['tracking']] ??
          _inferTracking(repsText),
      placement:
          Placement.values.asNameMap()[json['placement']] ??
          _inferPlacement(category),
      perSide: json['per_side'] as bool? ?? repsText.contains('per sisi'),
      restSeconds: json['rest_seconds'] as int? ?? 60,
    );
  }
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