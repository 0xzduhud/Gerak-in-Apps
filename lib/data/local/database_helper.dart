import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ============================================================================
// [PBI-8.6] DatabaseHelper — database lokal SQLite
// [PBI-10.1] Versi 2: menambah tabel `targets` (target harian).
// Tabel jadwal menyusul (Sprint 12) dengan menaikkan _dbVersion.
// Catatan: sqflite tidak berjalan di Flutter Web; di web dipakai
// penyimpanan shared_preferences (lihat activity_repository.dart
// dan target_repository.dart).
// ============================================================================
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'gerakin.db';
  static const int _dbVersion = 2;
  static const String tableActivities = 'activities';
  static const String tableTargets = 'targets';

  Future<Database>? _opening;

  Future<Database> get database async {
    try {
      return await (_opening ??= _open());
    } catch (_) {
      _opening = null; // izinkan percobaan ulang jika gagal membuka
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableActivities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        steps INTEGER NOT NULL,
        distance_meters REAL NOT NULL,
        calories REAL NOT NULL,
        sport_id TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_activities_started_at '
      'ON $tableActivities (started_at)',
    );
    await _createTargets(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTargets(db);
    }
  }

  // [PBI-10.1] Satu baris (id = 1) berisi target harian yang berlaku.
  Future<void> _createTargets(Database db) async {
    await db.execute('''
      CREATE TABLE $tableTargets (
        id INTEGER PRIMARY KEY,
        steps INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        calories INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
// ===================== AKHIR [PBI-8.6] DatabaseHelper ============================