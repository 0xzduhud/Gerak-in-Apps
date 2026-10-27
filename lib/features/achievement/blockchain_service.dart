import 'dart:convert';

import '../../core/utils/hash_helper.dart';
import '../../data/repositories/achievement_repository.dart';
import 'block.dart';

class BlockchainService {
  BlockchainService({AchievementRepository? repository})
    : _repository = repository ?? AchievementRepository();

  final AchievementRepository _repository;

  static const int difficulty = 2;

  // Dart tidak mendukung operator perkalian untuk String.
  String get _targetPrefix => List.filled(difficulty, '0').join();

  Future<Block> ensureGenesis(String userId) async {
    _validateUserId(userId);

    final latest = await _repository.getLatestBlock(userId);
    if (latest != null) return latest;

    final timestampMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    const index = 0;
    const achievementId = Block.genesisAchievementId;
    const data = '{}';
    const prevHash = Block.genesisPrevHash;

    var nonce = 0;
    late String hash;

    do {
      final payload =
          '$index|$timestampMs|$userId|$achievementId|$data|$prevHash|$nonce';

      hash = HashHelper.sha256Hex(payload);

      if (hash.startsWith(_targetPrefix)) break;

      nonce++;
    } while (true);

    final genesis = Block(
      index: index,
      timestampMs: timestampMs,
      userId: userId,
      achievementId: achievementId,
      data: data,
      prevHash: prevHash,
      nonce: nonce,
      hash: hash,
    );

    try {
      await _repository.insertBlock(genesis);
      return genesis;
    } catch (_) {
      // Jika proses lain sudah membuat genesis, gunakan blok yang tersimpan.
      final existing = await _repository.getLatestBlock(userId);
      if (existing != null) return existing;
      rethrow;
    }
  }

  Future<Block> addAchievement({
    required String userId,
    required String achievementId,
    Map<String, dynamic> data = const {},
  }) async {
    _validateUserId(userId);

    if (achievementId.trim().isEmpty ||
        achievementId == Block.genesisAchievementId) {
      throw ArgumentError('achievementId tidak valid.');
    }

    await ensureGenesis(userId);

    final existingBlocks = await _repository.getBlocksForUser(userId);

    final alreadyUnlocked = existingBlocks.any(
      (block) => block.achievementId == achievementId,
    );

    if (alreadyUnlocked) {
      throw StateError('Achievement ini sudah tercatat di blockchain.');
    }

    final previousBlock = await _repository.getLatestBlock(userId);

    if (previousBlock == null) {
      throw StateError('Gagal mendapatkan blok terakhir.');
    }

    final timestampMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final index = previousBlock.index + 1;
    final prevHash = previousBlock.hash;
    final dataJson = jsonEncode(data);

    var nonce = 0;
    late String hash;

    do {
      final payload =
          '$index|$timestampMs|$userId|$achievementId|$dataJson|$prevHash|$nonce';

      hash = HashHelper.sha256Hex(payload);

      if (hash.startsWith(_targetPrefix)) break;

      nonce++;
    } while (true);

    final block = Block(
      index: index,
      timestampMs: timestampMs,
      userId: userId,
      achievementId: achievementId,
      data: dataJson,
      prevHash: prevHash,
      nonce: nonce,
      hash: hash,
    );

    await _repository.insertBlock(block);

    return block;
  }

  Future<bool> verifyChain(String userId) async {
    _validateUserId(userId);

    final blocks = await _repository.getBlocksForUser(userId);

    if (blocks.isEmpty) return false;

    final genesis = blocks.first;

    if (genesis.index != 0 ||
        genesis.achievementId != Block.genesisAchievementId ||
        genesis.prevHash != Block.genesisPrevHash ||
        genesis.data != '{}') {
      return false;
    }

    for (var i = 0; i < blocks.length; i++) {
      final current = blocks[i];

      if (current.userId != userId ||
          current.index != i ||
          !current.isHashValid ||
          !current.hash.startsWith(_targetPrefix)) {
        return false;
      }

      if (i > 0) {
        final previous = blocks[i - 1];

        if (current.prevHash != previous.hash ||
            current.achievementId == Block.genesisAchievementId) {
          return false;
        }
      }
    }

    return true;
  }

  Future<List<Block>> getChain(String userId) async {
    _validateUserId(userId);

    await ensureGenesis(userId);

    return _repository.getBlocksForUser(userId);
  }

  void _validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId tidak boleh kosong.');
    }
  }
}
