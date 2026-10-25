import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../local/database_helper.dart';
import '../models/schedule_model.dart';

// ============================================================================
// [PBI-12.x] ScheduleStore — antarmuka penyimpanan jadwal
// ============================================================================
abstract class ScheduleStore {
  Future<List<WorkoutSchedule>> loadAll();

  /// Insert jika `id == null`, selain itu update. Mengembalikan data tersimpan.
  Future<WorkoutSchedule> upsert(WorkoutSchedule schedule);
  Future<void> delete(int id);
}

/// Android/iOS: SQLite.
class SqliteScheduleStore implements ScheduleStore {
  SqliteScheduleStore([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  @override
  Future<List<WorkoutSchedule>> loadAll() async {
    final db = await _helper.database;
    final rows = await db.query(DatabaseHelper.tableSchedules);
    return rows
        .map((r) => WorkoutSchedule.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<WorkoutSchedule> upsert(WorkoutSchedule schedule) async {
    final db = await _helper.database;
    final values = {...schedule.toJson(), 'synced': 0};
    if (schedule.id == null) {
      final id = await db.insert(DatabaseHelper.tableSchedules, values);
      return schedule.copyWith(id: id);
    }
    await db.update(
      DatabaseHelper.tableSchedules,
      values,
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
    return schedule;
  }

  @override
  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.delete(
      DatabaseHelper.tableSchedules,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

/// Flutter Web: JSON di shared_preferences (cadangan untuk uji di Edge).
class PrefsScheduleStore implements ScheduleStore {
  static const String _key = 'schedules_v1';

  Future<List<WorkoutSchedule>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) =>
              WorkoutSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<WorkoutSchedule> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((s) => {'id': s.id, ...s.toJson()}).toList()),
    );
  }

  @override
  Future<List<WorkoutSchedule>> loadAll() => _read();

  @override
  Future<WorkoutSchedule> upsert(WorkoutSchedule schedule) async {
    final list = await _read();
    if (schedule.id == null) {
      final nextId = list.fold<int>(0, (m, s) => (s.id ?? 0) > m ? s.id! : m) + 1;
      final saved = schedule.copyWith(id: nextId);
      list.add(saved);
      await _write(list);
      return saved;
    }
    final i = list.indexWhere((s) => s.id == schedule.id);
    if (i >= 0) {
      list[i] = schedule;
    } else {
      list.add(schedule);
    }
    await _write(list);
    return schedule;
  }

  @override
  Future<void> delete(int id) async {
    final list = await _read()..removeWhere((s) => s.id == id);
    await _write(list);
  }
}

// ============================================================================
// [PBI-12.x] ScheduleRepository — pintu masuk yang dipakai layar/provider
// ============================================================================
class ScheduleRepository {
  ScheduleRepository({ScheduleStore? store}) : _store = store ?? _defaultStore();

  static ScheduleStore _defaultStore() =>
      kIsWeb ? PrefsScheduleStore() : SqliteScheduleStore();

  final ScheduleStore _store;

  /// Diurutkan dari yang paling awal (berdasarkan waktu UTC, bukan jam dinding).
  Future<List<WorkoutSchedule>> all() async {
    final list = await _store.loadAll();
    list.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return list;
  }

  Future<WorkoutSchedule> save(WorkoutSchedule schedule) {
    final error = schedule.validate();
    if (error != null) throw ArgumentError(error);
    return _store.upsert(schedule);
  }

  Future<void> delete(int id) => _store.delete(id);
}