import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'gerakin.db';

  // Versi 6: menggabungkan skema sinkronisasi dan workout.
  static const int _dbVersion = 6;

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
        reps INTEGER NOT NULL DEFAULT 0,
        motion_type TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createActivityIndexes(db);
    await _createTargets(db);
    await _createSchedules(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Pastikan tabel tersedia pada database lama.
    await _createTargets(db);
    await _createSchedules(db);

    // Gabungkan kebutuhan sinkronisasi dan workout.
    // Pemeriksaan struktur mencegah penambahan kolom ganda,
    // termasuk pada database yang berasal dari branch berbeda.
    await _ensureColumn(db, tableActivities, 'server_id', 'TEXT');

    await _ensureColumn(
      db,
      tableActivities,
      'reps',
      'INTEGER NOT NULL DEFAULT 0',
    );

    await _ensureColumn(db, tableActivities, 'motion_type', 'TEXT');

    await _ensureColumn(
      db,
      tableTargets,
      'reps',
      'INTEGER NOT NULL DEFAULT 50',
    );

    await _createActivityIndexes(db);
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String columnName,
    String columnDefinition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');

    final exists = columns.any((column) => column['name'] == columnName);

    if (!exists) {
      await db.execute(
        'ALTER TABLE $table '
        'ADD COLUMN $columnName $columnDefinition',
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

  // Satu baris (id = 1) menyimpan target harian.
  Future<void> _createTargets(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTargets (
        id INTEGER PRIMARY KEY,
        steps INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        calories INTEGER NOT NULL,
        reps INTEGER NOT NULL DEFAULT 50,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // start_at menyimpan waktu jadwal workout.
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
