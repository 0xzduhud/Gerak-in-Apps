import 'package:sqflite/sqflite.dart';

import '../../features/achievement/block.dart';
import '../local/database_helper.dart';

/// Repository untuk menyimpan dan membaca blok blockchain achievement
/// dari SQLite lokal.
///
/// Tabel dibuat secara mandiri agar database_helper.dart tidak perlu diubah.
class AchievementRepository {
  AchievementRepository();

  static const String tableBlocks = 'achievement_blocks';

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  /// Memastikan tabel blockchain tersedia.
  ///
  /// Operasi ini hanya membuat tabel jika belum ada.
  /// Tabel dan data aplikasi lainnya tidak diubah.
  Future<void> _ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBlocks (
        block_index INTEGER NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        achievement_id TEXT NOT NULL,
        data TEXT NOT NULL,
        prev_hash TEXT NOT NULL,
        nonce INTEGER NOT NULL,
        hash TEXT NOT NULL,
        PRIMARY KEY (user_id, block_index)
      )
    ''');
  }

  /// Menyimpan satu blok.
  ///
  /// Mengembalikan row ID dari SQLite jika berhasil.
  /// Jika indeks blok untuk pengguna tersebut sudah ada,
  /// operasi akan gagal dan error diteruskan ke pemanggil.
  Future<int> insertBlock(Block block) async {
    if (block.userId.trim().isEmpty) {
      throw ArgumentError('userId tidak boleh kosong.');
    }

    final db = await _databaseHelper.database;
    await _ensureTable(db);

    return db.insert(
      tableBlocks,
      block.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Mengambil seluruh blok milik satu pengguna,
  /// diurutkan berdasarkan indeks dari yang terkecil.
  Future<List<Block>> getBlocksForUser(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId tidak boleh kosong.');
    }

    final db = await _databaseHelper.database;
    await _ensureTable(db);

    final rows = await db.query(
      tableBlocks,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'block_index ASC',
    );

    return rows.map((row) => Block.fromMap(row)).toList();
  }

  /// Mengambil blok terakhir milik satu pengguna.
  ///
  /// Mengembalikan null jika pengguna belum memiliki blok.
  Future<Block?> getLatestBlock(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId tidak boleh kosong.');
    }

    final db = await _databaseHelper.database;
    await _ensureTable(db);

    final rows = await db.query(
      tableBlocks,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'block_index DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Block.fromMap(rows.first);
  }

  /// Menghitung jumlah blok milik satu pengguna.
  Future<int> getBlockCount(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId tidak boleh kosong.');
    }

    final db = await _databaseHelper.database;
    await _ensureTable(db);

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total '
      'FROM $tableBlocks WHERE user_id = ?',
      [userId],
    );

    return (result.first['total'] as num).toInt();
  }
}
