import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/target_model.dart';
import '../../data/repositories/activity_repository.dart';
import 'chart_data.dart';

const List<String> _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

// ============================================================================
// [PBI-10.6] Grafik mingguan  •  [PBI-10.7] Grafik bulanan + pengalih
// ============================================================================
class ActivityChartSection extends StatefulWidget {
  const ActivityChartSection({super.key, required this.target});

  /// Target harian, dipakai untuk menggambar garis target.
  final DailyTarget target;

  @override
  State<ActivityChartSection> createState() => _ActivityChartSectionState();
}

class _ActivityChartSectionState extends State<ActivityChartSection> {
  final ActivityRepository _activities = ActivityRepository();

  ChartRange _range = ChartRange.weekly;
  ChartMetric _metric = ChartMetric.steps;
  List<DayBucket> _buckets = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final window = windowFor(_range, DateTime.now());
      final items = await _activities.history(
        from: window.start,
        to: window.end,
      );
      if (!mounted) return;
      setState(() {
        _buckets = buildBuckets(items, window);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat grafik: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Grafik belum bisa dimuat.';
        _loading = false;
      });
    }
  }

  double get _targetValue => switch (_metric) {
        ChartMetric.steps => widget.target.steps.toDouble(),
        ChartMetric.duration => widget.target.durationMinutes.toDouble(),
        ChartMetric.calories => widget.target.calories.toDouble(),
      };

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final values = [for (final b in _buckets) b.valueOf(_metric)];
    final labels = [
      for (final b in _buckets)
        _range == ChartRange.weekly
            ? _weekdays[b.date.weekday - 1]
            : (b.date.day == 1 || b.date.day % 5 == 0 ? '${b.date.day}' : ''),
    ];
    final todayIndex = _buckets.indexWhere((b) => b.date == todayDate);

    // Rata-rata dihitung sampai hari ini saja (hari depan belum terjadi).
    final elapsed = _buckets.where((b) => !b.date.isAfter(todayDate)).length;
    final total = values.fold<double>(0, (s, v) => s + v);
    final average = elapsed == 0 ? 0.0 : total / elapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Grafik aktivitas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Pengalih mingguan / bulanan (PBI-10.7)
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Mingguan'),
              selected: _range == ChartRange.weekly,
              onSelected: (_) {
                if (_range == ChartRange.weekly) return;
                _range = ChartRange.weekly;
                _load();
              },
            ),
            ChoiceChip(
              label: const Text('Bulanan'),
              selected: _range == ChartRange.monthly,
              onSelected: (_) {
                if (_range == ChartRange.monthly) return;
                _range = ChartRange.monthly;
                _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final m in ChartMetric.values)
              ChoiceChip(
                label: Text(m.label),
                selected: _metric == m,
                onSelected: (_) => setState(() => _metric = m),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _loading
              ? const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? SizedBox(
                      height: 190,
                      child: Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.tertiary),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 190,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _BarChartPainter(
                              values: values,
                              labels: labels,
                              target: _targetValue,
                              todayIndex: todayIndex,
                              barColor: AppColors.primary,
                              todayColor: AppColors.secondary,
                              axisColor: AppColors.outline,
                              textColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Total: ${formatNumber(total)} ${_metric.unit}   •   '
                          'Rata-rata/hari: ${formatNumber(average)} ${_metric.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Garis putus-putus = target harian',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.target,
    required this.todayIndex,
    required this.barColor,
    required this.todayColor,
    required this.axisColor,
    required this.textColor,
  });

  final List<double> values;
  final List<String> labels;
  final double target;
  final int todayIndex;
  final Color barColor;
  final Color todayColor;
  final Color axisColor;
  final Color textColor;

  static const double _bottomPad = 22;
  static const double _topPad = 16;

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    bool centered = true,
    double fontSize = 10,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centered ? x - tp.width / 2 : x - tp.width, y));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final chartH = size.height - _bottomPad - _topPad;
    final base = _topPad + chartH;
    final peak = values.fold<double>(0, math.max);
    final maxV = math.max(peak, target) * 1.15;
    final maxY = maxV <= 0 ? 1.0 : maxV;

    // Garis dasar
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, base), Offset(size.width, base), axis);

    // Garis target (putus-putus)
    if (target > 0) {
      final ty = base - (target / maxY) * chartH;
      final dash = Paint()
        ..color = textColor
        ..strokeWidth = 1;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, ty),
          Offset(math.min(x + 6, size.width), ty),
          dash,
        );
        x += 11;
      }
      _drawText(
        canvas,
        'Target ${formatNumber(target)}',
        size.width,
        ty - 13,
        centered: false,
      );
    }

    // Batang + label
    final n = values.length;
    final slot = size.width / n;
    final barW = math.min(slot * 0.6, 28.0);
    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final v = values[i];
      if (v > 0) {
        final h = math.max((v / maxY) * chartH, 2.0);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, base - h, barW, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = i == todayIndex ? todayColor : barColor,
        );
      }
      if (labels[i].isNotEmpty) {
        _drawText(canvas, labels[i], cx, base + 6);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) => true;
}