import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
// [PBI-9.x]  Versi 4: kolom `reps` dan `motion_type` di tabel `activities`.
// ============================================================================
// [PBI-8.6] DatabaseHelper — database lokal SQLite
// [PBI-10.1] Versi 2: tabel `targets`.
// [PBI-12.x] Versi 3: tabel `schedules` (jadwal workout).
// Catatan: sqflite tidak berjalan di Flutter Web; di web dipakai
// shared_preferences (lihat activity/target/schedule_repository.dart).
// ============================================================================
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'gerakin.db';
  static const int _dbVersion = 5;
  static const String tableActivities = 'activities';
  static const String tableTargets = 'targets';
  static const String tableSchedules = 'schedules';

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
        reps INTEGER NOT NULL DEFAULT 0,
        motion_type TEXT,
        synced INTEGER NOT NULL DEFAULT 0
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_activities_started_at '
      'ON $tableActivities (started_at)',
    );
    await _createTargets(db);
    await _createSchedules(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTargets(db);
    }
    if (oldVersion < 3) {
      await _createSchedules(db);
    }
        if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $tableActivities '
        'ADD COLUMN reps INTEGER NOT NULL DEFAULT 0',
      );
      if (oldVersion >= 2 && oldVersion < 5) {
      await db.execute(
        'ALTER TABLE $tableTargets '
        'ADD COLUMN reps INTEGER NOT NULL DEFAULT 50',
      );
    }
      await db.execute(
        'ALTER TABLE $tableActivities ADD COLUMN motion_type TEXT',
      );
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
        reps INTEGER NOT NULL DEFAULT 50,
        updated_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // [PBI-12.x] `start_at` = jam dinding di zona `zone_code`.
  Future<void> _createSchedules(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSchedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        start_at TEXT NOT NULL,
        zone_code TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        done INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
// ===================== AKHIR [PBI-8.6] DatabaseHelper ============================