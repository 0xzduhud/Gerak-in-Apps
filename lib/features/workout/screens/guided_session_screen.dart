import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../data/models/sport_model.dart';
import '../../../data/repositories/activity_repository.dart';
import '../guided_session_provider.dart';
import '../services/motion_detector.dart';
import '../session_spec.dart';
import '../widgets/timer_widgets.dart';
import 'motion_mode_screen.dart' show GyroscopeService;
import 'workout_session_screen.dart' show AccelerometerService;

String _placementHint(MotionType type) => switch (type) {
      MotionType.squat =>
        'Taruh HP di saku paha atau pegang di depan dada, lalu squat dengan '
            'gerakan penuh. Berdiri tegak sebentar di antara repetisi.',
      MotionType.pushUp =>
        'Taruh HP di punggung atas atau tahan di bawah dada. Turunkan badan '
            'sampai siku menekuk, lalu dorong kembali.',
      MotionType.jump =>
        'Taruh HP di saku celana atau genggam erat, lalu melompatlah sampai '
            'kedua kaki meninggalkan lantai.',
    };

// [PBI-7.x] Layar sesi untuk olahraga berbasis repetisi atau waktu.
class GuidedSessionScreen extends StatelessWidget {
  const GuidedSessionScreen({
    super.key,
    required this.sport,
    required this.spec,
    this.gyroscope = const GyroscopeService(),
    this.accelerometer = const AccelerometerService(),
  });

  final Sport sport;
  final SessionSpec spec;
  final GyroscopeService gyroscope;
  final AccelerometerService accelerometer;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GuidedSessionProvider>(
      create: (_) => GuidedSessionProvider(
        sport: sport,
        spec: spec,
        onCue: () {
          unawaited(Beeper.beep());
          HapticFeedback.heavyImpact();
        },
      ),
      child: _GuidedView(gyroscope: gyroscope, accelerometer: accelerometer),
    );
  }
}

class _GuidedView extends StatefulWidget {
  const _GuidedView({required this.gyroscope, required this.accelerometer});

  final GyroscopeService gyroscope;
  final AccelerometerService accelerometer;

  @override
  State<_GuidedView> createState() => _GuidedViewState();
}

class _GuidedViewState extends State<_GuidedView> {
  bool _saved = false;

  Future<void> _save(GuidedSessionProvider s) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary = s.toSummary();
    if (summary == null) return;
    try {
      await ActivityRepository().save(summary);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Hasil sesi tersimpan.')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gagal menyimpan hasil: $e')));
    }
  }

  Future<void> _finishNow(GuidedSessionProvider s) async {
    s.finish();
    _saved = true;
    await _save(s);
  }

  Future<bool> _confirmFinish() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Akhiri latihan?'),
        content: const Text('Hasil sampai saat ini akan disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Lanjutkan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
    return yes == true;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GuidedSessionProvider>();

    // Sesi selesai secara alami (set terakhir): simpan sekali.
    if (s.phase == GuidedPhase.finished && !_saved) {
      _saved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _save(s);
      });
    }

    final active = s.phase == GuidedPhase.work || s.phase == GuidedPhase.rest;

    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmFinish() && context.mounted) {
          await _finishNow(s);
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(s.sport.name)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      _Header(s: s),
                      const SizedBox(height: 16),
                      ..._body(s),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Controls(
                  s: s,
                  gyroscope: widget.gyroscope,
                  accelerometer: widget.accelerometer,
                  onFinish: () async {
                    if (await _confirmFinish()) await _finishNow(s);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(GuidedSessionProvider s) {
    final spec = s.spec;
    switch (s.phase) {
      case GuidedPhase.ready:
        return [
          _InfoCard(
            title: '${spec.sets} set',
            lines: [
              if (spec.kind == SessionKind.reps)
                'Target ${spec.targetReps} repetisi per set'
                    '${spec.perSide ? ' (per sisi)' : ''}',
              if (spec.kind == SessionKind.timed)
                '${spec.targetSeconds} detik per set',
              'Istirahat ${spec.restSeconds} detik antar set',
            ],
          ),
          const SizedBox(height: 12),
          _HintCard(
            spec.motion != null
                ? _placementHint(spec.motion!)
                : spec.kind == SessionKind.reps
                    ? 'Repetisi dicatat dengan tombol +1 setiap kali kamu '
                        'selesai satu repetisi.'
                    : 'Tiap set berjalan dengan hitung mundur. Tekan Mulai '
                        'saat siap.',
          ),
          if (kIsWeb && spec.motion != null) ...[
            const SizedBox(height: 10),
            const _HintCard(
              'Di browser/PC sensor gerak biasanya tidak tersedia. '
              'Gunakan tombol +1/−1, atau uji di HP Android.',
            ),
          ],
        ];

      case GuidedPhase.work:
        return [
          if (spec.kind == SessionKind.timed) ...[
            Center(
              child: Text(
                formatClock(s.remainingSeconds),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Center(
              child: Text(
                'sisa waktu set',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (spec.motion != null) ...[
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '${s.setReps} lompatan terhitung',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ] else ...[
            Center(child: _RepCounter(reps: s.setReps)),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'target ${spec.targetReps} repetisi'
                '${spec.perSide ? ' per sisi' : ''}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (spec.motion?.usesGyroscope ?? false) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: s.gauge,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceHigh,
                  color: s.gauge >= 1 ? AppColors.secondary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bar penuh = gerakan cukup dalam untuk dihitung.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            _RepButtons(s: s),
          ],
          if (s.noSensorData) ...[
            const SizedBox(height: 12),
            const _HintCard(
              'Belum ada data sensor. Gunakan tombol +1/−1 untuk '
              'mencatat repetisi.',
            ),
          ],
          if (s.doneReps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DoneSets(reps: s.doneReps, showReps: spec.kind == SessionKind.reps),
          ],
        ];

      case GuidedPhase.rest:
        return [
          Center(
            child: Text(
              formatClock(s.remainingSeconds),
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
          const Center(
            child: Text(
              'istirahat',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => s.adjustRest(-15),
                child: const Text('−15 dtk'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => s.adjustRest(15),
                child: const Text('+15 dtk'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Berikutnya: set ${s.setNumber} dari ${spec.sets}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DoneSets(reps: s.doneReps, showReps: spec.kind == SessionKind.reps),
        ];

      case GuidedPhase.finished:
        final secs = s.elapsed.inSeconds;
        final kcal = s.sport.kcalPerMinute * secs / 60;
        return [
          Row(
            children: [
              if (spec.kind == SessionKind.reps || s.totalReps > 0) ...[
                Expanded(
                  child: _StatBox(
                    icon: Icons.repeat_rounded,
                    value: '${s.totalReps}',
                    label: 'Repetisi',
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _StatBox(
                  icon: Icons.timer_outlined,
                  value: formatClock(secs),
                  label: 'Durasi',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  icon: Icons.local_fire_department_rounded,
                  value: kcal.toStringAsFixed(1),
                  label: 'Kalori (kkal)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DoneSets(reps: s.doneReps, showReps: spec.kind == SessionKind.reps),
          const SizedBox(height: 12),
          const _HintCard('Hasil disimpan ke riwayat.'),
        ];
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.s});

  final GuidedSessionProvider s;

  @override
  Widget build(BuildContext context) {
    final label = switch (s.phase) {
      GuidedPhase.ready => 'Siap dimulai',
      GuidedPhase.work =>
        'Set ${s.setNumber} dari ${s.spec.sets}${s.paused ? ' • Dijeda' : ''}',
      GuidedPhase.rest =>
        'Istirahat${s.paused ? ' • Dijeda' : ''}',
      GuidedPhase.finished => 'Sesi selesai',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
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
            formatClock(s.elapsed.inSeconds),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.neutral)),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.s,
    required this.gyroscope,
    required this.accelerometer,
    required this.onFinish,
  });

  final GuidedSessionProvider s;
  final GyroscopeService gyroscope;
  final AccelerometerService accelerometer;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    switch (s.phase) {
      case GuidedPhase.ready:
        return ElevatedButton.icon(
          onPressed: () {
            final m = s.spec.motion;
            if (m == null) {
              s.start();
            } else if (m.usesGyroscope) {
              // [PBI-9.4] gyroscope menghitung, accelerometer mengonfirmasi.
              s.start(
                gyro: gyroscope.samples(),
                accel: accelerometer.samples(),
              );
            } else {
              s.start(accel: accelerometer.samples());
            }
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Mulai'),
        );

      case GuidedPhase.work:
      case GuidedPhase.rest:
        final resting = s.phase == GuidedPhase.rest;
        final lastSet = s.setNumber >= s.spec.sets;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: s.paused ? s.resume : s.pause,
                    icon: Icon(
                      s.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(s.paused ? 'Lanjut' : 'Jeda'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: resting ? s.skipRest : s.completeSet,
                    icon: Icon(
                      resting
                          ? Icons.skip_next_rounded
                          : Icons.check_rounded,
                    ),
                    label: Text(
                      resting
                          ? 'Lewati istirahat'
                          : lastSet
                              ? 'Selesai latihan'
                              : 'Selesai set',
                    ),
                  ),
                ),
              ],
            ),
            TextButton(onPressed: onFinish, child: const Text('Akhiri latihan')),
          ],
        );

      case GuidedPhase.finished:
        return ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Tutup'),
        );
    }
  }
}

/// Tombol hitung repetisi. Olahraga manual: +1 besar. Olahraga bersensor:
/// tombol koreksi kecil.
class _RepButtons extends StatelessWidget {
  const _RepButtons({required this.s});

  final GuidedSessionProvider s;

  @override
  Widget build(BuildContext context) {
    final auto = s.spec.autoCount;
    return Row(
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 56)),
          onPressed: () => s.adjustReps(-1),
          child: const Text('−1'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: auto
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => s.adjustReps(1),
                  child: const Text('+1 (koreksi)'),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                  onPressed: () => s.adjustReps(1),
                  child: const Text(
                    '+1 repetisi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Angka repetisi yang berdenyut dan memicu getar tiap kali bertambah.
class _RepCounter extends StatefulWidget {
  const _RepCounter({required this.reps});

  final int reps;

  @override
  State<_RepCounter> createState() => _RepCounterState();
}

class _RepCounterState extends State<_RepCounter> {
  bool _pulse = false;

  @override
  void didUpdateWidget(covariant _RepCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reps > oldWidget.reps) {
      HapticFeedback.mediumImpact();
      _pulse = true;
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _pulse = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pulse ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 180,
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(
            color: _pulse ? AppColors.secondary : AppColors.primary,
            width: 6,
          ),
        ),
        child: Text(
          '${widget.reps}',
          style: const TextStyle(
            fontSize: 76,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _DoneSets extends StatelessWidget {
  const _DoneSets({required this.reps, required this.showReps});

  final List<int> reps;
  final bool showReps;

  @override
  Widget build(BuildContext context) {
    if (reps.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < reps.length; i++)
          Chip(
            label: Text(
              showReps ? 'Set ${i + 1}: ${reps[i]}' : 'Set ${i + 1} selesai',
            ),
            backgroundColor: AppColors.surfaceHigh,
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (final l in lines)
            Text(l, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
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
      padding: const EdgeInsets.all(14),
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
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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