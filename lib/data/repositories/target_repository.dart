import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../local/database_helper.dart';
import '../models/target_model.dart';

// ============================================================================
// [PBI-10.1] TargetStore — antarmuka penyimpanan target harian
// ============================================================================
abstract class TargetStore {
  /// null jika pengguna belum pernah mengatur target.
  Future<DailyTarget?> load();
  Future<void> save(DailyTarget target);
}

/// Android/iOS: SQLite (tabel `targets`, satu baris id = 1).
class SqliteTargetStore implements TargetStore {
  SqliteTargetStore([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  @override
  Future<DailyTarget?> load() async {
    final db = await _helper.database;
    final rows = await db.query(
      DatabaseHelper.tableTargets,
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyTarget.fromJson(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<void> save(DailyTarget target) async {
    final db = await _helper.database;
    // `synced` = 0 (pending): disiapkan untuk sinkronisasi ke server.
    await db.insert(
      DatabaseHelper.tableTargets,
      {
        'id': 1,
        ...target.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Flutter Web (sqflite tidak tersedia): disimpan sebagai JSON di
/// shared_preferences. Hanya cadangan agar fitur bisa dicoba di Edge.
class PrefsTargetStore implements TargetStore {
  static const String _key = 'daily_target_v1';

  @override
  Future<DailyTarget?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return DailyTarget.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(DailyTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(target.toJson()));
  }
}

// ============================================================================
// TargetRepository — pintu masuk yang dipakai layar
// ============================================================================
class TargetRepository {
  TargetRepository({TargetStore? store}) : _store = store ?? _defaultStore();

  static TargetStore _defaultStore() =>
      kIsWeb ? PrefsTargetStore() : SqliteTargetStore();

  final TargetStore _store;

  /// Target tersimpan, atau nilai bawaan jika belum pernah diatur.
  Future<DailyTarget> load() async =>
      (await _store.load()) ?? const DailyTarget();

  /// Menyimpan target (dipaksa masuk rentang) dan mengembalikan nilai akhirnya.
  Future<DailyTarget> save(DailyTarget target) async {
    final fixed = target.clamped();
    await _store.save(fixed);
    return fixed;
  }
}