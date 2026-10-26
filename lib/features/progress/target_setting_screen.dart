import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/target_model.dart';
import 'progress_provider.dart';

// [PBI-10.2] Layar pengaturan target harian (langkah, durasi, kalori).
class TargetSettingScreen extends StatefulWidget {
  const TargetSettingScreen({super.key});

  @override
  State<TargetSettingScreen> createState() => _TargetSettingScreenState();
}

class _TargetSettingScreenState extends State<TargetSettingScreen> {
  late double _steps;
  late double _duration;
  late double _calories;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = context.read<ProgressProvider>().target;
    _steps = t.steps.toDouble();
    _duration = t.durationMinutes.toDouble();
    _calories = t.calories.toDouble();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await context.read<ProgressProvider>().saveTarget(
          DailyTarget(
            steps: _steps.round(),
            durationMinutes: _duration.round(),
            calories: _calories.round(),
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Target disimpan.' : 'Target gagal disimpan.'),
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  void _resetDefault() {
    setState(() {
      _steps = DailyTarget.defaultSteps.toDouble();
      _duration = DailyTarget.defaultDurationMinutes.toDouble();
      _calories = DailyTarget.defaultCalories.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atur target harian')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text(
              'Target ini dipakai untuk menghitung progres aktivitasmu '
              'setiap hari.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _TargetSlider(
              icon: Icons.directions_walk_rounded,
              label: 'Langkah',
              valueText: '${_steps.round()} langkah',
              value: _steps,
              min: DailyTarget.minSteps.toDouble(),
              max: DailyTarget.maxSteps.toDouble(),
              divisions: 58, // kelipatan 500
              onChanged: (v) => setState(() => _steps = v),
            ),
            _TargetSlider(
              icon: Icons.timer_rounded,
              label: 'Durasi aktif',
              valueText: '${_duration.round()} menit',
              value: _duration,
              min: DailyTarget.minDuration.toDouble(),
              max: DailyTarget.maxDuration.toDouble(),
              divisions: 47, // kelipatan 5
              onChanged: (v) => setState(() => _duration = v),
            ),
            _TargetSlider(
              icon: Icons.local_fire_department_rounded,
              label: 'Kalori',
              valueText: '${_calories.round()} kkal',
              value: _calories,
              min: DailyTarget.minCalories.toDouble(),
              max: DailyTarget.maxCalories.toDouble(),
              divisions: 39, // kelipatan 50
              onChanged: (v) => setState(() => _calories = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan target'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _saving ? null : _resetDefault,
              child: const Text('Kembalikan ke bawaan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetSlider extends StatelessWidget {
  const _TargetSlider({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
              Text(
                valueText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}