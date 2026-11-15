import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/target_model.dart';
import '../progress/progress_provider.dart';
import '../progress/target_setting_screen.dart';

/// Halaman khusus untuk menampilkan rincian Daily Activity (Revisi Poin 1 & 2).
class DailyActivityDetailScreen extends StatelessWidget {
  const DailyActivityDetailScreen({super.key});

  static String _n(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _openTarget(BuildContext context, ProgressProvider provider) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<ProgressProvider>.value(
          value: provider,
          child: const TargetSettingScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProgressProvider>(
      create: (_) => ProgressProvider()..load(),
      child: Consumer<ProgressProvider>(
        builder: (context, p, _) {
          final progress = p.progress;

          return Scaffold(
            backgroundColor: AppColors.neutral,
            appBar: AppBar(
              title: const Text('Detail Daily Activity'),
            ),
            body: SafeArea(
              child: p.loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : RefreshIndicator(
                      onRefresh: p.load,
                      color: AppColors.primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        children: [
                          if (p.error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                p.error!,
                                style: const TextStyle(color: AppColors.tertiary),
                              ),
                            ),
                          ],

                          // 1. Kartu Donat Progress Keseluruhan
                          _OverallProgressCard(progress: progress),
                          const SizedBox(height: 20),

                          // 2. Baris Judul
                          const Text(
                            'Target & Capaian Hari Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3. Kartu Langkah
                          _DetailMetricTile(
                            icon: Icons.directions_walk_rounded,
                            iconColor: AppColors.primary,
                            label: 'Langkah Hari Ini',
                            currentText: '${_n(progress.steps.current)} langkah',
                            targetText: 'Target: ${_n(progress.steps.target)} langkah',
                            ratio: progress.steps.ratio,
                            percentage: progress.steps.percent,
                            isAchieved: progress.steps.achieved,
                          ),
                          const SizedBox(height: 12),

                          // 4. Kartu Durasi Aktif
                          _DetailMetricTile(
                            icon: Icons.timer_rounded,
                            iconColor: const Color(0xFFFFA726),
                            label: 'Durasi Aktif',
                            currentText: '${_n(progress.duration.current)} menit',
                            targetText: 'Target: ${_n(progress.duration.target)} menit',
                            ratio: progress.duration.ratio,
                            percentage: progress.duration.percent,
                            isAchieved: progress.duration.achieved,
                          ),
                          const SizedBox(height: 12),

                          // 5. Kartu Kalori
                          _DetailMetricTile(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: const Color(0xFFFF5252),
                            label: 'Kalori Terbakar',
                            currentText: '${_n(progress.calories.current)} kkal',
                            targetText: 'Target: ${_n(progress.calories.target)} kkal',
                            ratio: progress.calories.ratio,
                            percentage: progress.calories.percent,
                            isAchieved: progress.calories.achieved,
                          ),
                          const SizedBox(height: 18),

                          // 6. Tombol Atur Target
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _openTarget(context, p),
                            icon: const Icon(Icons.flag_rounded, color: AppColors.primary),
                            label: const Text(
                              'Atur Target Harian',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 7. Pesan Motivasi Harian
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFFFB300),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    progress.allAchieved
                                        ? 'Luar biasa! Semua target harianmu telah tercapai. Istirahat yang cukup dan pertahankan konsistensi besok!'
                                        : '${progress.achievedCount} dari 3 target harian tercapai. Terus bergerak, setiap langkah membawamu lebih dekat ke tubuh impian!',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.progress});

  final TargetProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.overallRatio * 100).floor();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: progress.allAchieved
              ? AppColors.secondary
              : AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 86,
                  height: 86,
                  child: CircularProgressIndicator(
                    value: progress.overallRatio,
                    strokeWidth: 9,
                    backgroundColor: AppColors.surfaceHigh,
                    color: progress.allAchieved
                        ? AppColors.secondary
                        : AppColors.primary,
                  ),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress Harian',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${progress.achievedCount} dari 3 target tercapai',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (progress.allAchieved ? AppColors.secondary : AppColors.primary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    progress.allAchieved ? 'Target Tercapai 🎉' : 'Sedang Berlangsung',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: progress.allAchieved
                          ? AppColors.secondary
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricTile extends StatelessWidget {
  const _DetailMetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.currentText,
    required this.targetText,
    required this.ratio,
    required this.percentage,
    required this.isAchieved,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String currentText;
  final String targetText;
  final double ratio;
  final int percentage;
  final bool isAchieved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAchieved ? iconColor.withValues(alpha: 0.5) : AppColors.outline,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      targetText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currentText,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAchieved ? Colors.greenAccent : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: AppColors.surfaceHigh,
              color: isAchieved ? Colors.greenAccent : iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
