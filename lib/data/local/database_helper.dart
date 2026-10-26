import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// [PBI-8.6] Database lokal SQLite.
// Versi 2 menambahkan server_id untuk sinkronisasi aktivitas yang aman
// terhadap percobaan ulang. Data pada versi 1 tetap dipertahankan.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'gerakin.db';
  static const int _dbVersion = 2;
  static const String tableActivities = 'activities';

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

    await db.execute(
      'CREATE INDEX idx_activities_started_at '
      'ON $tableActivities (started_at)',
    );

    await db.execute(
      'CREATE INDEX idx_activities_sync '
      'ON $tableActivities (synced)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableActivities ADD COLUMN server_id TEXT',
      );

      await db.execute(
        'CREATE INDEX idx_activities_sync '
        'ON $tableActivities (synced)',
      );
    }
  }
}
// ===================== AKHIR DatabaseHelper =====================
