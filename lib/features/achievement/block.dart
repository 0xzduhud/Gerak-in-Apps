import 'package:gerakinapps/core/utils/hash_helper.dart';

/// Satu blok dalam rantai achievement milik satu akun.
///
/// Hash blok dihitung dari seluruh isinya ditambah [prevHash], sehingga
/// mengubah satu blok akan membuat hash blok itu dan semua blok sesudahnya
/// tidak cocok lagi saat rantai diverifikasi.
class Block {
  const Block({
    required this.index,
    required this.timestampMs,
    required this.userId,
    required this.achievementId,
    required this.data,
    required this.prevHash,
    required this.nonce,
    required this.hash,
  });

  /// `prev_hash` milik blok pertama (genesis): 64 angka nol.
  static const String genesisPrevHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// Id khusus untuk blok pertama di rantai tiap akun.
  static const String genesisAchievementId = 'GENESIS';

  /// Nomor urut blok, dimulai dari 0 (blok genesis).
  final int index;

  /// Waktu blok dibuat, milidetik sejak epoch (UTC).
  final int timestampMs;

  final String userId;

  /// Id achievement yang terbuka, atau [genesisAchievementId].
  final String achievementId;

  /// Data pemicu dalam bentuk JSON string (misalnya skor atau level).
  final String data;

  final String prevHash;

  /// Angka yang dicari saat proof-of-work agar hash memenuhi kesulitan.
  final int nonce;

  final String hash;

  /// Teks yang di-hash. Urutan dan pemisah tidak boleh diubah, karena
  /// perubahan akan membuat semua blok lama dianggap tidak valid.
  String get payload =>
      '$index|$timestampMs|$userId|$achievementId|$data|$prevHash|$nonce';

  /// Menghitung ulang hash dari isi blok saat ini.
  String computeHash() => HashHelper.sha256Hex(payload);

  /// True bila [hash] yang tersimpan cocok dengan isi blok.
  bool get isHashValid => hash == computeHash();

  Map<String, dynamic> toMap() => {
    'block_index': index,
    'timestamp_ms': timestampMs,
    'user_id': userId,
    'achievement_id': achievementId,
    'data': data,
    'prev_hash': prevHash,
    'nonce': nonce,
    'hash': hash,
  };

  factory Block.fromMap(Map<String, dynamic> map) => Block(
    index: (map['block_index'] as num).toInt(),
    timestampMs: (map['timestamp_ms'] as num).toInt(),
    userId: map['user_id'] as String,
    achievementId: map['achievement_id'] as String,
    data: map['data'] as String,
    prevHash: map['prev_hash'] as String,
    nonce: (map['nonce'] as num).toInt(),
    hash: map['hash'] as String,
  );
}
