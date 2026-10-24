import 'package:flutter/foundation.dart';
import 'package:gerakinapps/features/chatbot/chat_message.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Penyimpanan riwayat chat di SQLite (lokal, per akun).
///
/// Catatan: sqflite hanya berjalan di Android dan iOS. Di Chrome (web),
/// semua metode melempar UnsupportedError. Pemanggil (ChatProvider)
/// harus menangkapnya dan tetap menjalankan chat tanpa riwayat.
class ChatLocalDb {
  ChatLocalDb._internal();
  static final ChatLocalDb _instance = ChatLocalDb._internal();
  factory ChatLocalDb() => _instance;

  static const String _dbName = 'gerakin_chat.db';
  static const String _table = 'chat_messages';

  /// Batas riwayat tersimpan per akun. Yang lebih lama dihapus otomatis.
  static const int _maxStoredPerUser = 200;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> _getDb() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Riwayat chat lokal hanya tersedia di Android dan iOS.',
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
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'sent',
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_chat_messages_user ON $_table (user_id, id)',
        );
      },
    );
  }

  /// Menyimpan satu pesan dan mengembalikannya lengkap dengan id.
  Future<ChatMessage> insertMessage(String userId, ChatMessage message) async {
    final db = await _getDb();

    final id = await db.insert(_table, {
      'user_id': userId,
      'role': message.role.name,
      'content': message.content,
      'status': message.status.name,
      'created_at': message.createdAt.toUtc().toIso8601String(),
    });

    await _trim(db, userId);
    return message.copyWith(id: id);
  }

  /// Mengubah status pesan (misalnya `error` menjadi `sent` setelah kirim ulang).
  Future<void> updateStatus(int id, ChatStatus status) async {
    final db = await _getDb();
    await db.update(
      _table,
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Memuat riwayat, urutan lama ke baru. Hanya [limit] pesan terakhir.
  Future<List<ChatMessage>> getMessages(
    String userId, {
    int limit = 100,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.reversed.map(ChatMessage.fromMap).toList();
  }

  Future<void> deleteMessage(int id) async {
    final db = await _getDb();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Menghapus seluruh riwayat milik satu akun.
  Future<void> clearHistory(String userId) async {
    final db = await _getDb();
    await db.delete(_table, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> _trim(Database db, String userId) async {
    await db.rawDelete(
      'DELETE FROM $_table WHERE user_id = ? AND id NOT IN '
      '(SELECT id FROM $_table WHERE user_id = ? ORDER BY id DESC LIMIT ?)',
      [userId, userId, _maxStoredPerUser],
    );
  }
}
