import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/common_widgets.dart';
import 'achievement_detail_screen.dart';
import 'achievement_provider.dart';
import 'block.dart';
import 'detail_blockchain_screen.dart';

class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authUserId = Supabase.instance.client.auth.currentUser?.id;

    if (authUserId == null || authUserId.isEmpty) {
      return const PlaceholderPage(
        title: 'Achievement',
        icon: Icons.emoji_events_rounded,
      );
    }

    return ChangeNotifierProvider(
      create: (_) => AchievementProvider()..load(userId: authUserId),
      child: _AchievementContent(userId: authUserId),
    );
  }
}

class _AchievementContent extends StatelessWidget {
  const _AchievementContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Achievement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () {
              context.read<AchievementProvider>().refresh();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Consumer<AchievementProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.blocks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.blocks.isEmpty) {
            return _ErrorView(
              message: provider.errorMessage!,
              onRetry: provider.refresh,
            );
          }

          final achievements = provider.achievements;
          final unlockedIds = provider.unlockedAchievements
              .map((item) => item.id)
              .toSet();

          final blocksByAchievementId = {
            for (final block in provider.blocks)
              if (block.achievementId != Block.genesisAchievementId)
                block.achievementId: block,
          };

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryCard(
                  unlocked: provider.unlockedCount,
                  total: provider.totalAchievements,
                  progress: provider.overallProgress,
                ),
                const SizedBox(height: 16),
                _BlockchainCard(
                  isValid: provider.isChainValid,
                  blockCount: provider.blocks.length,
                  onVerify: provider.verifyBlockchain,
                  onOpenDetails: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DetailBlockchainScreen(
                          userId: userId,
                          blocks: provider.blocks,
                        ),
                      ),
                    );
                  },
                ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Daftar Achievement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (achievements.isEmpty)
                  const Text('Belum ada achievement yang tersedia.')
                else
                  ...achievements.map((achievement) {
                    final unlocked = unlockedIds.contains(achievement.id);
                    final progress = achievement
                        .progress(provider.stats)
                        .clamp(0.0, 1.0);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AchievementDetailScreen(
                                achievement: achievement,
                                stats: provider.stats,
                                block: blocksByAchievementId[achievement.id],
                              ),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: unlocked
                              ? Colors.amber.withValues(alpha: 0.18)
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                          child: Icon(
                            achievement.isPremium
                                ? Icons.workspace_premium_rounded
                                : unlocked
                                ? Icons.emoji_events_rounded
                                : Icons.lock_outline_rounded,
                            color: achievement.isPremium
                                ? Colors.amber.shade700
                                : unlocked
                                ? Colors.amber.shade800
                                : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          achievement.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(achievement.description),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 4),
                            Text(
                              unlocked
                                  ? 'Terbuka'
                                  : 'Progres ${(progress * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: unlocked
                                    ? Colors.green
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (achievement.isPremium)
                              const Icon(
                                Icons.workspace_premium_rounded,
                                color: Colors.amber,
                              ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.unlocked,
    required this.total,
    required this.progress,
  });

  final int unlocked;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events_rounded, size: 30),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Perjalananmu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$unlocked',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    ' / $total achievement',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).round()}% tercapai',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockchainCard extends StatelessWidget {
  const _BlockchainCard({
    required this.isValid,
    required this.blockCount,
    required this.onVerify,
    required this.onOpenDetails,
  });

  final bool isValid;
  final int blockCount;
  final Future<bool> Function() onVerify;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final color = isValid ? Colors.green : Colors.orange;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isValid ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blockchain Achievement',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isValid
                          ? 'Rantai valid · $blockCount blok'
                          : 'Belum terverifikasi · $blockCount blok',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ketuk untuk melihat detail blok',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Verifikasi ulang',
                onPressed: () async {
                  final valid = await onVerify();

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        valid
                            ? 'Blockchain valid.'
                            : 'Blockchain belum valid atau gagal diverifikasi.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.fact_check_outlined),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
