import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ID akun yang dipakai untuk menyimpan skor game.
/// Ganti isi fungsi ini bila sumber user id di proyek berbeda.
String currentGameUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id ?? 'guest';
  } catch (_) {
    return 'guest';
  }
}

/// Penyimpanan skor game di SQLite (lokal, per akun).
///
/// Catatan: sqflite hanya berjalan di Android dan iOS. Di web semua metode
/// melempar UnsupportedError, jadi pemanggil harus menangkapnya.
class GameLocalDb {
  GameLocalDb._internal();
  static final GameLocalDb _instance = GameLocalDb._internal();
  factory GameLocalDb() => _instance;

  static const String _dbName = 'gerakin_game.db';
  static const String _table = 'game_scores';

  Database? _db;
  Future<Database>? _opening;

  Future<Database> _getDb() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Skor game lokal hanya tersedia di Android dan iOS.',
      );
    }

    final existing = _db;
    if (existing != null) return existing;

    final pending = _opening ??= _open();
    try {
      final db = await pending;
      _db = db;
      return db;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            game TEXT NOT NULL,
            score INTEGER NOT NULL,
            level INTEGER NOT NULL DEFAULT 1,
            extra INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_game_scores_user ON $_table (user_id, game)',
        );
      },
    );
  }

  /// Menyimpan satu hasil permainan.
  /// [game]: 'quiz' atau 'target'. [extra]: data tambahan,
  /// misalnya jumlah makanan sehat yang tertangkap.
  Future<void> insertScore(
    String userId, {
    required String game,
    required int score,
    int level = 1,
    int extra = 0,
  }) async {
    final db = await _getDb();
    await db.insert(_table, {
      'user_id': userId,
      'game': game,
      'score': score,
      'level': level,
      'extra': extra,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Skor tertinggi satu akun untuk satu game. 0 bila belum pernah main.
  Future<int> getHighScore(String userId, String game) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT MAX(score) AS best FROM $_table WHERE user_id = ? AND game = ?',
      [userId, game],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['best'] as num?)?.toInt() ?? 0;
  }
}
