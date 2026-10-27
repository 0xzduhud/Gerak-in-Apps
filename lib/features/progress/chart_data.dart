import '../../data/models/activity_model.dart';

// ============================================================================
// [PBI-10.6/10.7] Data grafik: jendela waktu + penjumlahan per hari
// ============================================================================
enum ChartRange { weekly, monthly }

enum ChartMetric { steps, duration, calories }

extension ChartMetricX on ChartMetric {
  String get label => switch (this) {
        ChartMetric.steps => 'Langkah',
        ChartMetric.duration => 'Durasi',
        ChartMetric.calories => 'Kalori',
      };

  String get unit => switch (this) {
        ChartMetric.steps => 'langkah',
        ChartMetric.duration => 'mnt',
        ChartMetric.calories => 'kkal',
      };
}

/// Total aktivitas dalam satu hari.
class DayBucket {
  const DayBucket({
    required this.date,
    this.steps = 0,
    this.minutes = 0,
    this.calories = 0,
  });

  final DateTime date;
  final double steps;
  final double minutes;
  final double calories;

  double valueOf(ChartMetric metric) => switch (metric) {
        ChartMetric.steps => steps,
        ChartMetric.duration => minutes,
        ChartMetric.calories => calories,
      };
}

/// Rentang tanggal yang digambar: [days] hari berurutan mulai [start].
class ChartWindow {
  const ChartWindow({required this.start, required this.days});

  final DateTime start;
  final int days;

  DateTime get end => DateTime(start.year, start.month, start.day + days - 1);
}

/// Mingguan = 7 hari terakhir (sampai hari ini).
/// Bulanan = seluruh hari pada bulan berjalan.
ChartWindow windowFor(ChartRange range, DateTime now) {
  switch (range) {
    case ChartRange.weekly:
      return ChartWindow(
        start: DateTime(now.year, now.month, now.day - 6),
        days: 7,
      );
    case ChartRange.monthly:
      return ChartWindow(
        start: DateTime(now.year, now.month, 1),
        days: DateTime(now.year, now.month + 1, 0).day,
      );
  }
}

/// Menjumlahkan aktivitas per hari. Aktivitas di luar jendela diabaikan.
List<DayBucket> buildBuckets(
  Iterable<ActivitySummary> items,
  ChartWindow window,
) {
  final steps = List<double>.filled(window.days, 0);
  final seconds = List<double>.filled(window.days, 0);
  final calories = List<double>.filled(window.days, 0);

  final startUtc = DateTime.utc(
    window.start.year,
    window.start.month,
    window.start.day,
  );
  for (final a in items) {
    final dayUtc = DateTime.utc(
      a.startedAt.year,
      a.startedAt.month,
      a.startedAt.day,
    );
    final i = dayUtc.difference(startUtc).inDays;
    if (i < 0 || i >= window.days) continue;
    steps[i] += a.steps;
    seconds[i] += a.durationSeconds;
    calories[i] += a.calories;
  }

  return List<DayBucket>.generate(
    window.days,
    (i) => DayBucket(
      date: DateTime(window.start.year, window.start.month, window.start.day + i),
      steps: steps[i],
      minutes: seconds[i] / 60.0,
      calories: calories[i],
    ),
  );
}

/// 12345 -> "12.345"
String formatNumber(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}