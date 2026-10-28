import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/target_model.dart' show TargetProgress;
import '../community/community_provider.dart';

// Header sapaan dan ikon notifikasi.
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
          shape: const CircleBorder(side: BorderSide(color: AppColors.outline)),
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

// Daily Activity dan indikator progres target harian.
class DailyActivityCard extends StatelessWidget {
  const DailyActivityCard({
    super.key,
    this.durationMinutes = 0,
    this.calories = 0,
    this.reps = 0,
    this.sessions = 0,
    this.steps = 0,
    this.distanceKm = 0,
    this.progress,
  });

  final int durationMinutes;
  final int calories;
  final int reps;
  final int sessions;
  final int steps;
  final double distanceKm;

  /// Capaian terhadap target harian. null = indikator disembunyikan.
  final TargetProgress? progress;

  String get _summaryLine {
    if (sessions == 0 && steps == 0) return 'Belum ada latihan hari ini';
    return [
      if (sessions > 0) '$sessions sesi',
      if (steps > 0) '$steps langkah',
      if (distanceKm > 0) '${distanceKm.toStringAsFixed(1)} km',
    ].join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final showProgress = p != null && p.activeCount > 0;
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
              Icon(Icons.fitness_center_rounded, color: AppColors.neutral),
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
              _ActivityStat(value: '$durationMinutes', label: 'Menit latihan'),
              _ActivityStat(value: '$calories', label: 'Kalori (kkal)'),
              _ActivityStat(value: '$reps', label: 'Repetisi'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _summaryLine,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral),
          ),
          if (showProgress) ...[
            const SizedBox(height: 14),
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
                        : '${p.achievedCount} dari ${p.activeCount} '
                              'target tercapai',
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

// Card rekomendasi AI.
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

// Empat menu bulat di halaman Home.
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
        for (final item in items) Expanded(child: _RoundMenuButton(item: item)),
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

// Menampilkan maksimal tiga postingan komunitas terbaru.
class CommunityFeedCard extends StatefulWidget {
  const CommunityFeedCard({super.key, required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  State<CommunityFeedCard> createState() => _CommunityFeedCardState();
}

class _CommunityFeedCardState extends State<CommunityFeedCard> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final provider = Provider.of<CommunityProvider>(context, listen: false);

      if (provider.posts.isEmpty && !provider.isLoading) {
        provider.fetchPosts().catchError((Object error) {
          debugPrint('Gagal memuat postingan komunitas di Home: $error');
        });
      }
    });
  }

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
              TextButton(
                onPressed: widget.onSeeAll,
                child: const Text('Lihat semua'),
              ),
            ],
          ),
          Consumer<CommunityProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (provider.posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Belum ada postingan komunitas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              final recentPosts = provider.posts.take(3).toList();

              return Column(
                children: [
                  for (int i = 0; i < recentPosts.length; i++) ...[
                    _CommunityPostPreview(post: recentPosts[i]),
                    if (i < recentPosts.length - 1)
                      Divider(
                        height: 20,
                        color: AppColors.outline.withValues(alpha: 0.6),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CommunityPostPreview extends StatelessWidget {
  const _CommunityPostPreview({required this.post});

  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final fullName = post['full_name']?.toString().trim() ?? '';
    final username = post['username']?.toString().trim() ?? '';
    final displayName = fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? username
        : 'Pengguna';

    final avatarUrl = post['avatar_url']?.toString();
    final content = post['content']?.toString().trim() ?? '';
    final imageUrl = post['image_url']?.toString().trim() ?? '';
    final time = post['time']?.toString() ?? 'Baru saja';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceHigh,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSecondary,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 64,
                          width: double.infinity,
                          color: AppColors.surfaceHigh,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
