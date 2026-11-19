import 'package:flutter/foundation.dart';

import '../../core/services/game_local_db.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/achievement_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/notification_repository.dart';
import 'block.dart';
import 'blockchain_service.dart';

class AchievementProvider extends ChangeNotifier {
  AchievementProvider({
    ActivityRepository? activityRepository,
    GameLocalDb? gameLocalDb,
    BlockchainService? blockchainService,
    NotificationRepository? notificationRepository,
  }) : _activityRepository = activityRepository ?? ActivityRepository(),
       _gameLocalDb = gameLocalDb ?? GameLocalDb(),
       _blockchainService = blockchainService ?? BlockchainService(),
       _notificationRepo = notificationRepository ?? NotificationRepository();

  final ActivityRepository _activityRepository;
  final GameLocalDb _gameLocalDb;
  final BlockchainService _blockchainService;
  final NotificationRepository _notificationRepo;

  String? _userId;
  AchievementStats _stats = AchievementStats.fromMap({});
  List<Block> _blocks = [];
  final List<AchievementDef> _newlyUnlocked = [];
  bool _isLoading = false;
  bool _isChainValid = false;
  String? _errorMessage;

  AchievementStats get stats => _stats;
  List<Block> get blocks => List.unmodifiable(_blocks);
  List<AchievementDef> get newlyUnlocked => List.unmodifiable(_newlyUnlocked);
  bool get isLoading => _isLoading;
  bool get isChainValid => _isChainValid;
  String? get errorMessage => _errorMessage;

  void clearNewlyUnlocked() {
    _newlyUnlocked.clear();
    notifyListeners();
  }

  List<AchievementDef> get achievements {
    // 27. yang free diatas yang premium dibawah
    final list = List<AchievementDef>.from(AchievementCatalog.all);
    list.sort((a, b) {
      if (a.isPremium != b.isPremium) {
        return a.isPremium ? 1 : -1;
      }
      return 0;
    });
    return list;
  }

  List<AchievementDef> get unlockedAchievements {
    final unlockedIds = _blocks
        .where((block) => block.achievementId != Block.genesisAchievementId)
        .map((block) => block.achievementId)
        .toSet();

    return AchievementCatalog.all
        .where((achievement) => unlockedIds.contains(achievement.id))
        .toList(growable: false);
  }

  List<AchievementDef> get lockedAchievements {
    final unlockedIds = unlockedAchievements
        .map((achievement) => achievement.id)
        .toSet();

    return AchievementCatalog.all
        .where((achievement) => !unlockedIds.contains(achievement.id))
        .toList(growable: false);
  }

  int get totalAchievements => AchievementCatalog.all.length;

  int get unlockedCount => unlockedAchievements.length;

  double get overallProgress {
    if (totalAchievements == 0) return 0;
    return unlockedCount / totalAchievements;
  }

  /// Memuat statistik, memeriksa syarat achievement,
  /// lalu memuat dan memverifikasi blockchain pengguna.
  Future<void> load({required String userId}) async {
    if (userId.trim().isEmpty) {
      _errorMessage = 'ID pengguna tidak ditemukan.';
      notifyListeners();
      return;
    }

    _userId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stats = await _loadStats(userId);

      // Pastikan genesis tersedia sebelum mencatat achievement.
      await _blockchainService.ensureGenesis(userId);

      // Catat achievement yang memenuhi syarat dan belum tercatat.
      final existingBlocks = await _blockchainService.getChain(userId);
      final existingIds = existingBlocks
          .map((block) => block.achievementId)
          .toSet();

      for (final achievement in AchievementCatalog.all) {
        if (!achievement.isMet(_stats)) continue;
        if (existingIds.contains(achievement.id)) continue;

        await _blockchainService.addAchievement(
          userId: userId,
          achievementId: achievement.id,
          data: {
            ..._stats.toMap(userId),
            'achievement_title': achievement.title,
            'threshold': achievement.threshold,
            'network': Block.networkName,
            'contract': Block.sepoliaContractAddress,
          },
        );

        existingIds.add(achievement.id);
        _newlyUnlocked.add(achievement);

        // 9. tiap ada achievement yang tercapai akan muncul dan ada notifnya
        try {
          await NotificationService.instance.showNotification(
            id: achievement.id.hashCode.abs() % 100000,
            title: '🏆 Achievement Terbuka!',
            body: 'Selamat! Kamu berhasil meraih "${achievement.title}". Tercatat di Sepolia Testnet.',
          );
          await _notificationRepo.addNew([
            AppNotification(
              id: 'ach_${achievement.id}_${DateTime.now().millisecondsSinceEpoch}',
              title: '🏆 Achievement: ${achievement.title}',
              body: '${achievement.description}. Tercatat di Sepolia Testnet.',
              createdAt: DateTime.now().toUtc(),
              kind: 'achievement',
              read: false,
            ),
          ]);
        } catch (e) {
          debugPrint('Gagal mengirim notif achievement: $e');
        }
      }

      _blocks = await _blockchainService.getChain(userId);
      _isChainValid = await _blockchainService.verifyChain(userId);
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat achievement: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Gagal memuat achievement. Silakan coba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AchievementStats> _loadStats(String userId) async {
    final now = DateTime.now();

    // ActivityRepository membatasi pembacaan riwayat hingga 400 hari khusus user ini.
    final activities = await _activityRepository.history(
      from: now.subtract(const Duration(days: 399)),
      to: now,
      userId: userId,
    );

    final validWorkouts = activities
        .where(
          (activity) =>
              activity.durationSeconds >= AchievementRules.minSessionSeconds,
        )
        .toList();

    var bestSteps = 0;

    for (final activity in activities) {
      if (activity.steps > bestSteps) {
        bestSteps = activity.steps;
      }
    }

    final gamesPlayed = await _gameLocalDb.getGamesPlayedCount(userId);
    final bestTargetScore = await _gameLocalDb.getHighScore(userId, 'target');
    final bestTargetLevel = await _gameLocalDb.getBestLevel(userId, 'target');

    return AchievementStats.fromMap({
      'user_id': userId,
      'workout_count': validWorkouts.length,
      'best_steps': bestSteps,
      'games_played': gamesPlayed,
      'best_target_score': bestTargetScore,
      'best_target_level': bestTargetLevel,
    });
  }

  /// Memuat ulang statistik dan status blockchain pengguna aktif.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) return;
    await load(userId: userId);
  }

  /// Mengambil status validitas blockchain terbaru.
  Future<bool> verifyBlockchain() async {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) return false;

    try {
      _isChainValid = await _blockchainService.verifyChain(userId);
      _blocks = await _blockchainService.getChain(userId);
      _errorMessage = null;
    } catch (error) {
      debugPrint('Verifikasi blockchain gagal: $error');
      _isChainValid = false;
      _errorMessage = 'Gagal memverifikasi blockchain.';
    }

    notifyListeners();
    return _isChainValid;
  }
}
