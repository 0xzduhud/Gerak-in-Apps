import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../local/database_helper.dart';
import '../models/activity_model.dart';

// ============================================================================
// [PBI-8.7] DailyTotals — total aktivitas satu hari
// ============================================================================
class DailyTotals {
  const DailyTotals({
    this.steps = 0,
    this.calories = 0,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
  });

  final int steps;
  final double calories;
  final double distanceMeters;
  final int durationSeconds;

  static const DailyTotals empty = DailyTotals();

  factory DailyTotals.from(Iterable<ActivitySummary> items) {
    var steps = 0;
    var calories = 0.0;
    var distance = 0.0;
    var seconds = 0;

    for (final activity in items) {
      steps += activity.steps;
      calories += activity.calories;
      distance += activity.distanceMeters;
      seconds += activity.durationSeconds;
    }

    return DailyTotals(
      steps: steps,
      calories: calories,
      distanceMeters: distance,
      durationSeconds: seconds,
    );
  }
}

// ============================================================================
// ActivityStore — antarmuka penyimpanan lokal dan antrean sinkronisasi
// ============================================================================
abstract class ActivityStore {
  Future<void> insert(ActivitySummary summary);

  Future<List<ActivitySummary>> forDay(DateTime day);

  Future<List<Map<String, dynamic>>> pendingForSync();

  Future<void> setServerId(String localId, String serverId);

  Future<void> markSynced(String localId);
}

// ============================================================================
// Android/iOS — SQLite
// ============================================================================
class SqliteActivityStore implements ActivityStore {
  SqliteActivityStore([DatabaseHelper? helper])
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  @override
  Future<void> insert(ActivitySummary summary) async {
    final db = await _helper.database;

    await db.insert(DatabaseHelper.tableActivities, {
      ...summary.toJson(),
      'server_id': null,
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
        .map((row) => ActivitySummary.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> pendingForSync() async {
    final db = await _helper.database;

    final rows = await db.query(
      DatabaseHelper.tableActivities,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'started_at ASC',
    );

    return rows.map((row) {
      final result = Map<String, dynamic>.from(row);
      result['local_id'] = row['id'].toString();
      return result;
    }).toList();
  }

  @override
  Future<void> setServerId(String localId, String serverId) async {
    final id = int.tryParse(localId);
    if (id == null) {
      throw ArgumentError.value(localId, 'localId', 'ID lokal tidak valid');
    }

    final db = await _helper.database;
    await db.update(
      DatabaseHelper.tableActivities,
      {'server_id': serverId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markSynced(String localId) async {
    final id = int.tryParse(localId);
    if (id == null) {
      throw ArgumentError.value(localId, 'localId', 'ID lokal tidak valid');
    }

    final db = await _helper.database;
    await db.update(
      DatabaseHelper.tableActivities,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ============================================================================
// Flutter Web — SharedPreferences
// Mempertahankan format activities_v1 dan menambahkan metadata sinkronisasi.
// ============================================================================
class PrefsActivityStore implements ActivityStore {
  static const String _key = 'activities_v1';
  static const Uuid _uuid = Uuid();

  List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null) return [];

    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _readAndNormalize(
    SharedPreferences prefs,
  ) async {
    final list = _decode(prefs.getString(_key));
    var changed = false;

    for (final item in list) {
      // Data lama dari activities_v1 tetap dianggap belum tersinkronisasi.
      if (item['local_id'] == null) {
        item['local_id'] = _uuid.v4();
        changed = true;
      }

      if (!item.containsKey('server_id')) {
        item['server_id'] = null;
        changed = true;
      }

      if (!item.containsKey('synced')) {
        item['synced'] = 0;
        changed = true;
      }
    }

    if (changed) {
      await prefs.setString(_key, jsonEncode(list));
    }

    return list;
  }

  @override
  Future<void> insert(ActivitySummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _readAndNormalize(prefs);

    list.add({
      ...summary.toJson(),
      'local_id': _uuid.v4(),
      'server_id': null,
      'synced': 0,
    });

    await prefs.setString(_key, jsonEncode(list));
  }

  @override
  Future<List<ActivitySummary>> forDay(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _readAndNormalize(prefs);

    return list
        .map(ActivitySummary.fromJson)
        .where(
          (activity) =>
              activity.startedAt.year == day.year &&
              activity.startedAt.month == day.month &&
              activity.startedAt.day == day.day,
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> pendingForSync() async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _readAndNormalize(prefs);

    return list
        .where((item) => item['synced'] != 1)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Future<void> setServerId(String localId, String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _readAndNormalize(prefs);
    var found = false;

    for (final item in list) {
      if (item['local_id'] == localId) {
        item['server_id'] = serverId;
        found = true;
        break;
      }
    }

    if (!found) {
      throw StateError('Aktivitas lokal tidak ditemukan: $localId');
    }

    await prefs.setString(_key, jsonEncode(list));
  }

  @override
  Future<void> markSynced(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _readAndNormalize(prefs);
    var found = false;

    for (final item in list) {
      if (item['local_id'] == localId) {
        item['synced'] = 1;
        found = true;
        break;
      }
    }

    if (!found) {
      throw StateError('Aktivitas lokal tidak ditemukan: $localId');
    }

    await prefs.setString(_key, jsonEncode(list));
  }
}

// ============================================================================
// ActivityRepository — penyimpanan lokal dan sinkronisasi ke Supabase
// ============================================================================
class ActivityRepository {
  ActivityRepository({ActivityStore? store, SupabaseClient? client})
    : _store = store ?? _defaultStore(),
      _client = client;

  static ActivityStore _defaultStore() =>
      kIsWeb ? PrefsActivityStore() : SqliteActivityStore();

  static const Uuid _uuid = Uuid();

  final ActivityStore _store;
  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Simpan secara lokal terlebih dahulu.
  /// Kegagalan server tidak membatalkan penyimpanan lokal.
  Future<void> save(ActivitySummary summary) async {
    await _store.insert(summary);

    try {
      await syncPending();
    } catch (error) {
      debugPrint('Sinkronisasi aktivitas ditunda: $error');
    }
  }

  Future<DailyTotals> totalsForDay(DateTime day) async {
    // Membantu mencoba ulang antrean saat layar aktivitas dibuka kembali.
    try {
      await syncPending();
    } catch (error) {
      debugPrint('Gagal mencoba ulang sinkronisasi: $error');
    }

    return DailyTotals.from(await _store.forDay(day));
  }

  /// Mengirim aktivitas lokal yang belum tersinkronisasi.
  ///
  /// ID server dibuat sekali dan disimpan sebelum POST. Percobaan ulang akan
  /// memakai ID yang sama sehingga aktivitas tidak sengaja dibuat berulang.
  Future<void> syncPending() async {
    final session = _supabase.auth.currentSession;

    if (session == null || session.accessToken.isEmpty) {
      // Pengguna belum login: aktivitas tetap tersimpan secara lokal.
      return;
    }

    final pending = await _store.pendingForSync();

    for (final item in pending) {
      final localId = item['local_id']?.toString();

      if (localId == null || localId.isEmpty) {
        debugPrint('Aktivitas dilewati karena ID lokal tidak tersedia.');
        continue;
      }

      var serverId = item['server_id']?.toString();

      if (serverId == null || serverId.isEmpty) {
        serverId = _uuid.v4();

        // Persist ID sebelum mengirim request ke server.
        await _store.setServerId(localId, serverId);
      }

      final startedAt = DateTime.parse(item['started_at'] as String)
          .toUtc()
          .toIso8601String();

      final payload = <String, dynamic>{
        'id': serverId,
        'started_at': startedAt,
        'duration_sec': (item['duration_seconds'] as num).toInt(),
        'steps': (item['steps'] as num).toInt(),
        'distance_m': (item['distance_meters'] as num).toDouble(),
        'calories': (item['calories'] as num).toDouble(),
        'reps': 0,

        // ID olahraga lokal berupa slug, sedangkan ID server adalah bigint.
        // Jangan mengirim slug ke kolom numerik.
        'sport_id': null,
      };

      try {
        final response = await _supabase.functions.invoke(
          'activities',
          method: HttpMethod.post,
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
          body: payload,
        );

        if (response.status >= 200 &&
            response.status < 300 &&
            _responseConfirmsSuccess(response.data)) {
          await _store.markSynced(localId);
          debugPrint('Aktivitas $serverId berhasil disinkronisasi.');
          continue;
        }
      } catch (error) {
        debugPrint('POST aktivitas $serverId belum terkonfirmasi: $error');
      }

      // Jika POST gagal atau respons tidak pasti, periksa apakah server
      // sebenarnya sudah menyimpan aktivitas tersebut.
      try {
        final exists = await _serverContainsActivity(
          serverId,
          session.accessToken,
        );

        if (exists) {
          await _store.markSynced(localId);
          debugPrint(
            'Aktivitas $serverId sudah ada di server; antrean diperbarui.',
          );
        } else {
          debugPrint(
            'Aktivitas $serverId tetap pending untuk percobaan berikutnya.',
          );
        }
      } catch (error) {
        debugPrint(
          'Verifikasi aktivitas $serverId gagal; tetap pending: $error',
        );
      }
    }
  }

  bool _responseConfirmsSuccess(dynamic responseData) {
    if (responseData is! Map) return false;

    return responseData['success'] == true && responseData['data'] != null;
  }

  Future<bool> _serverContainsActivity(
    String serverId,
    String accessToken,
  ) async {
    final response = await _supabase.functions.invoke(
      'activities',
      method: HttpMethod.get,
      headers: {'Authorization': 'Bearer $accessToken'},
      queryParameters: {'id': serverId},
    );

    if (response.status < 200 || response.status >= 300) {
      return false;
    }

    final responseData = response.data;
    if (responseData is! Map || responseData['success'] != true) {
      return false;
    }

    final data = responseData['data'];

    if (data is List) {
      return data.any((row) => row is Map && row['id']?.toString() == serverId);
    }

    if (data is Map) {
      return data['id']?.toString() == serverId;
    }

    return false;
  }
}
// ===================== AKHIR activity_repository.dart =====================
