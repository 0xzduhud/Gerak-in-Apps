import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../data/models/sport_model.dart';
import '../workout_provider.dart';
import '../widgets/timer_widgets.dart';
import 'workout_session_screen.dart';

String _fmtKcal(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    final value = context.read<WorkoutProvider>().targetValue;
    _targetController = TextEditingController(text: value > 0 ? '$value' : '');
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  // PBI-7.7: buka video panduan di aplikasi/peramban YouTube.
  Future<void> _openVideo(Sport sport) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(sport.youtubeUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka YouTube.')),
        );
    }
  }

  void _onTypeChanged(TargetType type) {
    context.read<WorkoutProvider>().setTargetType(type);
    if (type == TargetType.bebas) _targetController.clear();
  }

  // PBI-7.5: validasi lalu simpan pilihan sesi.
  Future<void> _save() async {
    final provider = context.read<WorkoutProvider>();
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    final ok = await provider.savePlan();
    if (ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Pilihan sesi latihan tersimpan.')),
        );
    }
  }

    // PBI-8.3: validasi pilihan sesi, simpan, lalu buka layar sesi.
  Future<void> _startSession() async {
    final provider = context.read<WorkoutProvider>();
    FocusScope.of(context).unfocus();
    final ok = await provider.savePlan();
    final sport = provider.selected;
    if (!ok || sport == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutSessionScreen(sport: sport),
      ),
    );
  }

  String _targetLabel(TargetType type) => switch (type) {
        TargetType.kalori => 'Target kalori (kkal)',
        TargetType.repetisi => 'Target repetisi',
        TargetType.bebas => 'Target',
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final sport = provider.selected;

    if (sport == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail latihan')),
        body: const Center(
          child: Text(
            'Belum ada olahraga dipilih.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(sport.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _HeaderCard(sport: sport),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'Kesulitan',
                  value: sport.difficulty.label,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Kalori',
                  value: '~${_fmtKcal(sport.kcalPerMinute)} kkal/mnt',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.repeat_rounded,
                  label: 'Set × Repetisi',
                  value: '${sport.sets} × ${sport.reps}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.fitness_center_rounded,
                  label: 'Alat',
                  value: sport.equipment,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _openVideo(sport),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Tonton video panduan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              side: const BorderSide(color: AppColors.secondary),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ---- PBI-7.4: pilih target dan durasi
          const Text(
            'Atur sesi latihan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Jenis target',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in TargetType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: provider.targetType == type,
                  showCheckmark: false,
                  onSelected: (_) => _onTypeChanged(type),
                  selectedColor: AppColors.primary.withValues(alpha: 0.28),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: provider.targetType == type
                        ? AppColors.primary
                        : AppColors.outline,
                  ),
                  labelStyle: TextStyle(
                    color: provider.targetType == type
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (provider.targetType != TargetType.bebas) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (v) => provider.setTargetValue(int.tryParse(v) ?? 0),
              decoration: InputDecoration(
                labelText: _targetLabel(provider.targetType),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Durasi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${provider.duration} menit',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: provider.duration.clamp(5, 120).toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            label: '${provider.duration} menit',
            activeColor: AppColors.primary,
            onChanged: (v) => provider.setDuration(v.round()),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Estimasi pembakaran: ~${provider.estimatedKcal} kkal',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.error!,
              style: const TextStyle(color: AppColors.tertiary),
            ),
          ],
          const SizedBox(height: 18),
                    ElevatedButton.icon(
            onPressed: _startSession,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Mulai latihan'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Simpan pilihan sesi'),
          ),

          const SizedBox(height: 28),
          const StopwatchPanel(),
          const SizedBox(height: 14),
          const IntervalTimerPanel(),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon sementara pengganti gambar, bisa diganti nanti.
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(sport.icon, color: AppColors.primary, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sport.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sport.category} • ${sport.isPremium ? 'Premium' : 'Free'}',
                        style: TextStyle(
                          color: sport.isPremium
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              sport.description,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}