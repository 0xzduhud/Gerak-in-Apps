import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import 'activity_chart.dart';
import 'history_screen.dart';
import 'progress_provider.dart';

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

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: SafeArea(
        child: p.loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: p.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    if (p.error != null) ...[
                      Text(
                        p.error!,
                        style: const TextStyle(color: AppColors.tertiary),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Grafik aktivitas diletakkan di atas (Revisi 6 & Revisi Gap)
                    ActivityChartSection(target: p.target),
                    const SizedBox(height: 14),
                    // Riwayat diletakkan di bawah grafik
                    const HistorySection(),
                  ],
                ),
              ),
      ),
    );
  }
}
