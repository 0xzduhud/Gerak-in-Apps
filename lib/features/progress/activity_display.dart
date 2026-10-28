import 'package:flutter/material.dart';

import '../../data/models/activity_model.dart';
import '../../data/models/sport_model.dart';

/// Cara satu sesi ditampilkan, ditentukan dari isinya (bukan dari olahraga),
/// sehingga data lama dan baru sama-sama benar.
enum ActivityKind {
  /// Ada repetisi: latihan beban, Push-up, Squat, dan sejenisnya.
  strength,

  /// Ada langkah: Jogging dan kardio berjarak.
  cardio,

  /// Tanpa repetisi dan langkah: Plank, Mountain Climber. Yang berarti = durasi.
  timed,
}

ActivityKind kindOf(ActivitySummary a) {
  if (a.reps > 0) return ActivityKind.strength;
  if (a.steps > 0) return ActivityKind.cardio;
  return ActivityKind.timed;
}

String durationText(int seconds) {
  final m = seconds ~/ 60;
  return m > 0 ? '$m mnt' : '$seconds dtk';
}

String distanceText(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(2)} km';

/// Angka utama di kanan kartu riwayat.
String headlineOf(ActivitySummary a) => switch (kindOf(a)) {
      ActivityKind.strength => '${a.reps} repetisi',
      ActivityKind.cardio => '${a.steps} langkah',
      ActivityKind.timed => durationText(a.durationSeconds),
    };

/// Baris kecil di bawah angka utama.
String detailOf(ActivitySummary a) {
  final kcal = '${a.calories.round()} kkal';
  return switch (kindOf(a)) {
    ActivityKind.strength => '${durationText(a.durationSeconds)} • $kcal',
    ActivityKind.cardio => [
        durationText(a.durationSeconds),
        if (a.distanceMeters > 0) distanceText(a.distanceMeters),
        kcal,
      ].join(' • '),
    ActivityKind.timed => kcal,
  };
}

/// Nama olahraga. Data lama dari Mode Gerakan tidak punya sportId, jadi nama
/// diambil dari jenis geraknya.
String titleOf(ActivitySummary a, Map<String, Sport> sports) {
  final id = a.sportId;
  if (id != null) return sports[id]?.name ?? id;
  return switch (a.motionType) {
    'squat' => 'Squat',
    'pushUp' => 'Push-up',
    'jump' => 'Lompat',
    _ => 'Aktivitas bebas',
  };
}

IconData iconOf(ActivitySummary a, Map<String, Sport> sports) {
  final id = a.sportId;
  final sport = id == null ? null : sports[id];
  if (sport != null) return sport.icon;
  return kindOf(a) == ActivityKind.cardio
      ? Icons.directions_run_rounded
      : Icons.fitness_center_rounded;
}