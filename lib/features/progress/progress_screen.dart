import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/target_model.dart';
import 'progress_provider.dart';
import 'target_setting_screen.dart';
import 'history_screen.dart';
import 'activity_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProgressProvider>(
      create: (_) => ProgressProvider()..load(),
      child: const _ProgressView(),
    );
  }
}

String _n(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  Future<void> _openTarget(BuildContext context) {
    final provider = context.read<ProgressProvider>();
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
    final p = context.watch<ProgressProvider>();
    final progress = p.progress;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: SafeArea(
        child: p.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: p.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    if (p.error != null) ...[
                      Text(
                        p.error!,
                        style: const TextStyle(color: AppColors.tertiary),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _OverallCard(progress: progress),
                    const SizedBox(height: 16),
                                        if (progress.activeCount == 0)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Belum ada target aktif. Atur target harian untuk '
                          'melihat progresmu.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    if (progress.duration.active)
                      _MetricTile(
                        icon: Icons.timer_rounded,
                        label: 'Durasi latihan',
                        metric: progress.duration,
                        text: '${_n(progress.duration.current)} / '
                            '${_n(progress.duration.target)} menit',
                      ),
                    if (progress.calories.active)
                      _MetricTile(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Kalori',
                        metric: progress.calories,
                        text: '${_n(progress.calories.current)} / '
                            '${_n(progress.calories.target)} kkal',
                      ),
                    if (progress.reps.active)
                      _MetricTile(
                        icon: Icons.repeat_rounded,
                        label: 'Repetisi',
                        metric: progress.reps,
                        text: '${_n(progress.reps.current)} / '
                            '${_n(progress.reps.target)} repetisi',
                      ),
                    if (progress.steps.active)
                      _MetricTile(
                        icon: Icons.directions_walk_rounded,
                        label: 'Langkah',
                        metric: progress.steps,
                        text: '${_n(progress.steps.current)} / '
                            '${_n(progress.steps.target)} langkah',
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => _openTarget(context),
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Atur target harian'),
                    ),
                    const HistorySection(),
                    ActivityChartSection(target: p.target),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.progress});

  final TargetProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.overallRatio * 100).floor();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: progress.allAchieved ? AppColors.secondary : AppColors.outline,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: progress.overallRatio,
                    strokeWidth: 8,
                    backgroundColor: AppColors.surfaceHigh,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.allAchieved
                      ? 'Target hari ini tercapai!'
                      : 'Progres hari ini',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    progress.activeCount == 0
                      ? 'Belum ada target aktif'
                      : '${progress.achievedCount} dari '
                          '${progress.activeCount} target tercapai',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.metric,
    required this.text,
  });

  final IconData icon;
  final String label;
  final MetricProgress metric;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (metric.achieved)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.secondary,
                )
              else
                Text(
                  '${metric.percent}%',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: metric.ratio,
              minHeight: 8,
              backgroundColor: AppColors.surfaceHigh,
              color: metric.achieved ? AppColors.secondary : AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}