import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/achievement_model.dart';
import '../premium/subscription_provider.dart';
import 'block.dart';

class AchievementDetailScreen extends StatelessWidget {
  const AchievementDetailScreen({
    super.key,
    required this.achievement,
    required this.stats,
    required this.block,
  });

  final AchievementDef achievement;
  final AchievementStats stats;
  final Block? block;

  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      timestampMs,
      isUtc: true,
    ).toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final isLocked = achievement.isPremium && !isPremium;
    final progress = achievement.progress(stats).clamp(0.0, 1.0);
    final isUnlocked = block != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Achievement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: achievement.isPremium
                        ? Colors.amber.withValues(alpha: 0.18)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      isLocked
                          ? Icons.lock_rounded
                          : isUnlocked
                          ? Icons.emoji_events_rounded
                          : Icons.flag_outlined,
                      size: 42,
                      color: achievement.isPremium
                          ? Colors.amber.shade700
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    achievement.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(achievement.description, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: isUnlocked ? 'Terbuka' : 'Belum terbuka',
                        icon: isUnlocked
                            ? Icons.check_circle_outline
                            : Icons.lock_outline,
                      ),
                      if (achievement.isPremium)
                        const _StatusChip(
                          label: 'Premium',
                          icon: Icons.workspace_premium_outlined,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isLocked)
            _PremiumLockedCard()
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progres Achievement',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).round()}% tercapai'),
                    const SizedBox(height: 12),
                    Text(
                      isUnlocked
                          ? 'Achievement ini sudah tercatat.'
                          : 'Selesaikan syarat achievement untuk membukanya.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (block != null)
              _BlockchainDetailCard(block: block!, formatDate: _formatDate)
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Belum ada blok blockchain untuk achievement ini.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PremiumLockedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 52,
              color: Colors.amber,
            ),
            const SizedBox(height: 12),
            const Text(
              'Achievement Premium',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Detail achievement ini memerlukan langganan Premium. '
              'Berlangganan untuk membuka akses ke detailnya.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Buka halaman Premium melalui menu langganan di aplikasi.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockchainDetailCard extends StatelessWidget {
  const _BlockchainDetailCard({required this.block, required this.formatDate});

  final Block block;
  final String Function(int timestampMs) formatDate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hashValid = block.isHashValid && block.hash.startsWith('00');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.link_rounded, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Catatan Blockchain',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Indeks blok', value: '${block.index}'),
            _InfoRow(
              label: 'Waktu pencatatan',
              value: formatDate(block.timestampMs),
            ),
            _InfoRow(
              label: 'Validasi hash lokal',
              value: hashValid ? 'Valid' : 'Tidak valid',
            ),
            _InfoRow(label: 'Nonce', value: '${block.nonce}'),
            _HashRow(label: 'Hash blok', value: block.hash),
            _HashRow(label: 'Previous hash', value: block.prevHash),
            const SizedBox(height: 12),
            const Text(
              'Data blok',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(
              _formatData(block.data),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatData(String value) {
    try {
      final decoded = jsonDecode(value);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return value;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  const _HashRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 17), label: Text(label));
  }
}
