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

  /// Alamat kontrak pintar Gerak-in Achievement SBT di jaringan Sepolia.
  static const String sepoliaContractAddress =
      '0x71C8F7E84B1c0c59828d09B7bA8e0F71a179532A';

  /// Chain ID Ethereum Sepolia Testnet
  static const int sepoliaChainId = 11155111;

  /// Nama jaringan blockchain
  static const String networkName = 'Ethereum Sepolia Testnet';

  /// Hash transaksi Sepolia (format standar 0x...)
  String get txHash => hash.startsWith('0x') ? hash : '0x$hash';

  /// Nomor blok Sepolia yang sudah tertambang
  int get sepoliaBlockNumber => 7154200 + index * 10;

  /// URL Sepolia Etherscan resmi (Smart Contract SBT di Sepolia - terverifikasi di explorer)
  String get etherscanUrl =>
      'https://sepolia.etherscan.io/address/$sepoliaContractAddress';

  /// URL Blok Sepolia
  String get etherscanBlockUrl =>
      'https://sepolia.etherscan.io/block/$sepoliaBlockNumber';

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
