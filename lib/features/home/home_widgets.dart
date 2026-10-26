import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/target_model.dart' show TargetProgress;

// PBI-6.3: header sapaan (kiri) + ikon notifikasi (kanan)
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greeting,
    required this.name,
    required this.onNotificationTap,
  });

  final String greeting;
  final String name;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.outline),
          ),
          child: IconButton(
            tooltip: 'Notifikasi',
            onPressed: onNotificationTap,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}

// PBI-6.4: kerangka card Daily Activity
// PBI-6.4: kerangka card Daily Activity
// PBI-10.8: indikator progres target harian (opsional, tampil jika [progress] ada)
class DailyActivityCard extends StatelessWidget {
  const DailyActivityCard({
    super.key,
    this.steps = 0,
    this.calories = 0,
    this.distanceKm = 0,
    this.progress,
  });

  final int steps;
  final int calories;
  final double distanceKm;

  /// Capaian terhadap target harian. null = indikator disembunyikan.
  final TargetProgress? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: AppColors.neutral),
              SizedBox(width: 8),
              Text(
                'Daily Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ActivityStat(value: '$steps', label: 'Langkah'),
              _ActivityStat(value: '$calories', label: 'Kalori (kcal)'),
              _ActivityStat(
                value: distanceKm.toStringAsFixed(1),
                label: 'Jarak (km)',
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: p.overallRatio,
                minHeight: 8,
                backgroundColor: const Color(0x33171132),
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (p.allAchieved)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.neutral,
                    ),
                  ),
                Expanded(
                  child: Text(
                    p.allAchieved
                        ? 'Target hari ini tercapai!'
                        : '${p.achievedCount} dari 3 target tercapai',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral,
                    ),
                  ),
                ),
                Text(
                  '${(p.overallRatio * 100).floor()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}

// PBI-6.5: kerangka card rekomendasi AI
class AiRecommendationCard extends StatelessWidget {
  const AiRecommendationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rekomendasi hari ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Saran olahraga atau istirahat akan muncul di sini '
                  'berdasarkan riwayat dan targetmu.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// PBI-6.6: empat menu bulat
class HomeMenuItem {
  const HomeMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class RoundMenuRow extends StatelessWidget {
  const RoundMenuRow({super.key, required this.items});

  final List<HomeMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Expanded(child: _RoundMenuButton(item: item)),
      ],
    );
  }
}

class _RoundMenuButton extends StatelessWidget {
  const _RoundMenuButton({required this.item});

  final HomeMenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Icon(item.icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PBI-6.8: kerangka card Community feed
class CommunityFeedCard extends StatelessWidget {
  const CommunityFeedCard({super.key, required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Komunitas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(onPressed: onSeeAll, child: const Text('Lihat semua')),
            ],
          ),
          const _FeedPlaceholder(),
          const _FeedPlaceholder(),
          const SizedBox(height: 8),
          const Text(
            'Postingan terbaru dari komunitas akan tampil di sini.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceHigh,
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bar(widthFactor: 0.45),
                SizedBox(height: 8),
                _Bar(widthFactor: 0.9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}