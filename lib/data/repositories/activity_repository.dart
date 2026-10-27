import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../local/database_helper.dart';
import '../models/activity_model.dart';

// ============================================================================
// [PBI-8.7] DailyTotals — total aktivitas satu hari (untuk card Daily Activity)
// ============================================================================
// ============================================================================
// [PBI-8.7] DailyTotals — total aktivitas satu hari (untuk card Daily Activity)
// ============================================================================
class DailyTotals {
  const DailyTotals({
    this.steps = 0,
    this.calories = 0,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.reps = 0,
    this.sessions = 0,
  });

  final int steps;
  final double calories;
  final double distanceMeters;
  final int durationSeconds;

  /// Total repetisi (sesi repetisi dan Mode Gerakan).
  final int reps;

  /// Jumlah sesi latihan.
  final int sessions;

  static const DailyTotals empty = DailyTotals();

  factory DailyTotals.from(Iterable<ActivitySummary> items) {
    var steps = 0;
    var calories = 0.0;
    var distance = 0.0;
    var seconds = 0;
    var reps = 0;
    var sessions = 0;
    for (final a in items) {
      steps += a.steps;
      calories += a.calories;
      distance += a.distanceMeters;
      seconds += a.durationSeconds;
      reps += a.reps;
      sessions++;
    }
    return DailyTotals(
      steps: steps,
      calories: calories,
      distanceMeters: distance,
      durationSeconds: seconds,
      reps: reps,
      sessions: sessions,
    );
  }
}

// ============================================================================
// [PBI-8.6] ActivityStore — antarmuka penyimpanan + dua implementasinya
// ============================================================================
abstract class ActivityStore {
  Future<void> insert(ActivitySummary summary);

  /// Semua aktivitas yang DIMULAI pada tanggal [day] (waktu lokal).
  Future<List<ActivitySummary>> forDay(DateTime day);
}

/// Android/iOS: SQLite lewat [DatabaseHelper].
class SqliteActivityStore implements ActivityStore {
  SqliteActivityStore([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  @override
  Future<void> insert(ActivitySummary summary) async {
    final db = await _helper.database;
    // `synced` = 0 (pending): disiapkan untuk sinkronisasi ke server (Sprint 4).
    await db.insert(DatabaseHelper.tableActivities, {
      ...summary.toJson(),
      'synced': 0,
    });
  }

  @override
  Future<List<ActivitySummary>> forDay(DateTime day) async {
    final db = await _helper.database;
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final rows = await db.query(
      DatabaseHelper.tableActivities,
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'started_at ASC',
    );
    return rows
        .map((r) => ActivitySummary.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }
}

/// Flutter Web (sqflite tidak tersedia): daftar aktivitas disimpan sebagai JSON
/// di shared_preferences. Hanya cadangan agar fitur tetap bisa dicoba di Edge.
class PrefsActivityStore implements ActivityStore {
  static const String _key = 'activities_v1';

  List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> insert(ActivitySummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key))..add(summary.toJson());
    await prefs.setString(_key, jsonEncode(list));
  }

  @override
  Future<List<ActivitySummary>> forDay(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key))
        .map(ActivitySummary.fromJson)
        .where(
          (a) =>
              a.startedAt.year == day.year &&
              a.startedAt.month == day.month &&
              a.startedAt.day == day.day,
        )
        .toList();
  }
}

// ============================================================================
// [PBI-8.6] ActivityRepository — pintu masuk yang dipakai layar
// ============================================================================
class ActivityRepository {
  ActivityRepository({ActivityStore? store}) : _store = store ?? _defaultStore();

  static ActivityStore _defaultStore() =>
      kIsWeb ? PrefsActivityStore() : SqliteActivityStore();

  final ActivityStore _store;

  /// Menyimpan hasil satu sesi. Bagian API/server menyusul (Sprint 3-4).
  Future<void> save(ActivitySummary summary) => _store.insert(summary);

  /// Total aktivitas pada tanggal [day] (PBI-8.7).
  Future<DailyTotals> totalsForDay(DateTime day) async =>
      DailyTotals.from(await _store.forDay(day));

        /// [PBI-10.4] Riwayat aktivitas dari tanggal [from] sampai [to] (inklusif),
  /// diurutkan dari yang terbaru.
  Future<List<ActivitySummary>> history({
    required DateTime from,
    required DateTime to,
  }) async {
    final out = <ActivitySummary>[];
    var day = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    var guard = 0; // pengaman: maksimal 400 hari sekali ambil
    while (!day.isAfter(last) && guard < 400) {
      out.addAll(await _store.forDay(day));
      day = DateTime(day.year, day.month, day.day + 1);
      guard++;
    }
    out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }
}
// ===================== AKHIR activity_repository.dart =======================