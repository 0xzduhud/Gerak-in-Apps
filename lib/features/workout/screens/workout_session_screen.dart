import '../services/background_tracking_service.dart';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/theme.dart';
import '../../../data/models/sport_model.dart';
import '../services/step_detector.dart';
import '../workout_provider.dart';
import '../../../data/repositories/activity_repository.dart';

import 'dart:async';

String _fmtDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String _fmtDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(2)} km';

// ============================================================================
// [PBI-8.1] AccelerometerService — pembungkus sensors_plus
// Digabung di file ini agar tidak menambah file baru. Boleh dipindah ke
// services/accelerometer_service.dart bila nanti dipakai layar lain (Sprint 9).
// ============================================================================
class AccelerometerService {
  const AccelerometerService();

  /// Mengubah event accelerometer menjadi [AccelSample] untuk [StepDetector].
  /// Waktu memakai Stopwatch (monotonik), bukan jam dinding.
  Stream<AccelSample> samples({
    Duration interval = SensorInterval.gameInterval,
  }) {
    final clock = Stopwatch()..start();
    return accelerometerEventStream(samplingPeriod: interval)
        .map((e) => AccelSample(e.x, e.y, e.z, clock.elapsedMilliseconds))
        .handleError((Object error) {
          // Perangkat tanpa sensor (mis. Edge desktop) tidak boleh membuat app crash.
          debugPrint('Accelerometer tidak tersedia: $error');
        });
  }
}
// ===================== AKHIR [PBI-8.1] AccelerometerService =================

class WorkoutSessionScreen extends StatelessWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.sport,
    this.accelerometer = const AccelerometerService(),
  });

  final Sport sport;
  final AccelerometerService accelerometer;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WorkoutSessionProvider>(
      create: (_) => WorkoutSessionProvider(),
      child: _BackgroundGuard(
        child: _SessionView(sport: sport, accelerometer: accelerometer),
      ),
    );
  }
}

// ============================================================================
// [PBI-8.5] _BackgroundGuard — memperbarui notifikasi layanan tiap 5 detik dan
// memastikan layanan berhenti saat layar sesi ditutup.
// ============================================================================
class _BackgroundGuard extends StatefulWidget {
  const _BackgroundGuard({required this.child});

  final Widget child;

  @override
  State<_BackgroundGuard> createState() => _BackgroundGuardState();
}

class _BackgroundGuardState extends State<_BackgroundGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final session = context.read<WorkoutSessionProvider>();
      if (session.state == SessionState.running) {
        BackgroundTracking.update(
          steps: session.steps,
          elapsed: session.elapsed,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    BackgroundTracking.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
// ===================== AKHIR [PBI-8.5] _BackgroundGuard =====================

class _SessionView extends StatelessWidget {
  const _SessionView({required this.sport, required this.accelerometer});

  final Sport sport;
  final AccelerometerService accelerometer;

  Future<bool?> _confirmLeave(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Akhiri sesi?'),
        content: const Text('Sesi yang sedang berjalan akan dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjutkan sesi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
  }

  String _stateLabel(SessionState state) => switch (state) {
    SessionState.idle => 'Siap dimulai',
    SessionState.running => 'Sedang berjalan',
    SessionState.paused => 'Dijeda',
    SessionState.finished => 'Sesi selesai',
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<WorkoutSessionProvider>();
    final state = session.state;
    final active =
        state == SessionState.running || state == SessionState.paused;

    final showNoStepHint =
        state == SessionState.running &&
        session.steps == 0 &&
        session.elapsed.inSeconds >= 15;

    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context);
        if (leave == true && context.mounted) {
          context.read<WorkoutSessionProvider>().reset();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(sport.name)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      // Stopwatch sesi
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _fmtDuration(session.elapsed),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neutral,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _stateLabel(state),
                              style: const TextStyle(color: AppColors.neutral),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Langkah real-time
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.directions_walk_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${session.steps}',
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'langkah',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.straighten_rounded,
                              value: _fmtDistance(session.distanceMeters),
                              label: 'Jarak',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.local_fire_department_rounded,
                              value: session.calories.toStringAsFixed(1),
                              label: 'Kalori (kkal)',
                            ),
                          ),
                        ],
                      ),
                      if (kIsWeb && state != SessionState.finished) ...[
                        const SizedBox(height: 16),
                        const _HintCard(
                          'Sensor gerak tidak tersedia di web desktop. '
                          'Jalankan di HP Android untuk menghitung langkah.',
                        ),
                      ],
                      if (showNoStepHint) ...[
                        const SizedBox(height: 16),
                        const _HintCard(
                          'Belum ada langkah terdeteksi. Bawa HP saat berjalan '
                          'dan pastikan perangkat memiliki sensor gerak.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Controls(sport: sport, accelerometer: accelerometer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.sport, required this.accelerometer});

  final Sport sport;
  final AccelerometerService accelerometer;

  // PBI-8.6: akhiri sesi lalu simpan hasilnya ke database lokal.
  Future<void> _finishAndSave(
    BuildContext context,
    WorkoutSessionProvider session,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary = session.finish();
    unawaited(BackgroundTracking.stop()); // PBI-8.5
    // Sesi yang langsung dihentikan (tanpa waktu dan langkah) tidak disimpan.
    if (summary == null ||
        (summary.durationSeconds == 0 && summary.steps == 0)) {
      return;
    }
    try {
      await ActivityRepository().save(summary);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Hasil sesi tersimpan.')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Gagal menyimpan hasil sesi: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<WorkoutSessionProvider>();
    final state = context.select<WorkoutSessionProvider, SessionState>(
      (s) => s.state,
    );

    switch (state) {
      case SessionState.idle:
        return ElevatedButton.icon(
          onPressed: () async {
            // PBI-8.5: nyalakan layanan latar belakang dulu, lalu mulai sesi.
            await BackgroundTracking.start(sportName: sport.name);
            if (!context.mounted) return;
            session.start(samples: accelerometer.samples(), sportId: sport.id);
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Mulai'),
        );
      case SessionState.running:
      case SessionState.paused:
        final paused = state == SessionState.paused;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: paused ? session.resume : session.pause,
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(paused ? 'Lanjut' : 'Jeda'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _finishAndSave(context, session),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Selesai'),
              ),
            ),
          ],
        );
      case SessionState.finished:
        return ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Tutup'),
        );
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            label,
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

class _HintCard extends StatelessWidget {
  const _HintCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
