import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ============================================================================
// [PBI-8.6] DatabaseHelper — database lokal SQLite
// Sementara hanya tabel `activities`. Tabel target/riwayat/jadwal menyusul
// (Sprint 4, 10, 12) dengan menaikkan _dbVersion dan mengisi onUpgrade.
// Catatan: sqflite tidak berjalan di Flutter Web; di web dipakai
// PrefsActivityStore (lihat activity_repository.dart).
// ============================================================================
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'gerakin.db';
  static const int _dbVersion = 1;
  static const String tableActivities = 'activities';

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
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
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
  }
}
// ===================== AKHIR [PBI-8.6] DatabaseHelper =======================