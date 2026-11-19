import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database_helper.dart';
import '../models/target_model.dart';

// ============================================================================
// [PBI-10.1] TargetStore — antarmuka penyimpanan target harian
// ============================================================================
abstract class TargetStore {
  /// null jika pengguna belum pernah mengatur target.
  Future<DailyTarget?> load({String? userId});
  Future<void> save(DailyTarget target, {String? userId});
}

/// Android/iOS: SQLite (tabel `targets`, dipisahkan per `user_id`).
class SqliteTargetStore implements TargetStore {
  SqliteTargetStore([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  @override
  Future<DailyTarget?> load({String? userId}) async {
    final db = await _helper.database;

    if (userId != null && userId.isNotEmpty) {
      final rows = await db.query(
        DatabaseHelper.tableTargets,
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return DailyTarget.fromJson(Map<String, dynamic>.from(rows.first));
      }
    }

    // Fallback data umum/lama jika belum diset per user
    final fallbackRows = await db.query(
      DatabaseHelper.tableTargets,
      where: 'id = 1',
      limit: 1,
    );
    if (fallbackRows.isNotEmpty) {
      return DailyTarget.fromJson(Map<String, dynamic>.from(fallbackRows.first));
    }
    return null;
  }

  @override
  Future<void> save(DailyTarget target, {String? userId}) async {
    final db = await _helper.database;
    if (userId != null && userId.isNotEmpty) {
      await db.delete(
        DatabaseHelper.tableTargets,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
    await db.insert(
      DatabaseHelper.tableTargets,
      {
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        ...target.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Flutter Web: disimpan per user_id di SharedPreferences.
class PrefsTargetStore implements TargetStore {
  String _keyFor(String? userId) =>
      userId != null && userId.isNotEmpty
          ? 'daily_target_$userId'
          : 'daily_target_v1';

  @override
  Future<DailyTarget?> load({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(userId)) ?? prefs.getString('daily_target_v1');
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
  Future<void> save(DailyTarget target, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(userId), jsonEncode(target.toJson()));
  }
}

// ============================================================================
// TargetRepository — pintu masuk yang dipakai layar
// ============================================================================
class TargetRepository {
  TargetRepository({TargetStore? store, SupabaseClient? client})
      : _store = store ?? _defaultStore(),
        _client = client;

  static TargetStore _defaultStore() =>
      kIsWeb ? PrefsTargetStore() : SqliteTargetStore();

  final TargetStore _store;
  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  String _currentUserId([String? overrideUserId]) {
    if (overrideUserId != null && overrideUserId.trim().isNotEmpty) {
      return overrideUserId.trim();
    }
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    } catch (_) {}
    return 'default_user';
  }

  /// Target tersimpan khusus akun pengguna aktif, atau nilai bawaan jika belum diatur.
  Future<DailyTarget> load({String? userId}) async {
    final effectiveUserId = _currentUserId(userId);
    return (await _store.load(userId: effectiveUserId)) ?? const DailyTarget();
  }

  /// Menyimpan target untuk akun pengguna aktif.
  Future<DailyTarget> save(DailyTarget target, {String? userId}) async {
    final effectiveUserId = _currentUserId(userId);
    final fixed = target.clamped();
    await _store.save(fixed, userId: effectiveUserId);
    return fixed;
  }
}