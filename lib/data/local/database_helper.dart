import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// [PBI-8.6] Database lokal SQLite.
// [PBI-10.1] Tabel target harian.
// [PBI-12.x] Tabel jadwal workout.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'gerakin.db';
  static const int _dbVersion = 4;

  static const String tableActivities = 'activities';
  static const String tableTargets = 'targets';
  static const String tableSchedules = 'schedules';

  Future<Database>? _opening;

  Future<Database> get database async {
    try {
      return await (_opening ??= _open());
    } catch (_) {
      _opening = null;
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
        server_id TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createActivityIndexes(db);
    await _createTargets(db);
    await _createSchedules(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Nomor versi 2 pernah digunakan oleh dua branch dengan skema
    // berbeda. Periksa struktur aktual agar migrasi tidak bergantung
    // pada nomor versi saja.
    await _ensureActivityServerId(db);
    await _createActivityIndexes(db);
    await _createTargets(db);
    await _createSchedules(db);
  }

  Future<void> _ensureActivityServerId(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableActivities)');

    final hasServerId = columns.any((column) => column['name'] == 'server_id');

    if (!hasServerId) {
      await db.execute(
        'ALTER TABLE $tableActivities ADD COLUMN server_id TEXT',
      );
    }
  }

  Future<void> _createActivityIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activities_started_at '
      'ON $tableActivities (started_at)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activities_sync '
      'ON $tableActivities (synced)',
    );
  }

  // [PBI-10.1] Satu baris (id = 1) berisi target harian.
  Future<void> _createTargets(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTargets (
        id INTEGER PRIMARY KEY,
        steps INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        calories INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // [PBI-12.x] start_at menyimpan waktu jadwal.
  Future<void> _createSchedules(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSchedules (
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
// ===================== AKHIR DatabaseHelper =====================
