import '../../data/models/activity_model.dart';

// ============================================================================
// [PBI-10.6/10.7] Data grafik: jendela waktu + penjumlahan per hari
// ============================================================================
enum ChartRange { weekly, monthly }

/// Urutan = urutan chip di layar. Durasi dulu karena berlaku untuk semua jenis
/// latihan; langkah hanya bermakna untuk kardio.
enum ChartMetric { duration, reps, calories, steps, sessions }

extension ChartMetricX on ChartMetric {
  String get label => switch (this) {
        ChartMetric.duration => 'Durasi',
        ChartMetric.reps => 'Repetisi',
        ChartMetric.calories => 'Kalori',
        ChartMetric.steps => 'Langkah',
        ChartMetric.sessions => 'Sesi',
      };

  String get unit => switch (this) {
        ChartMetric.duration => 'mnt',
        ChartMetric.reps => 'repetisi',
        ChartMetric.calories => 'kkal',
        ChartMetric.steps => 'langkah',
        ChartMetric.sessions => 'sesi',
      };
}

/// Total aktivitas dalam satu hari.
class DayBucket {
  const DayBucket({
    required this.date,
    this.steps = 0,
    this.minutes = 0,
    this.calories = 0,
    this.reps = 0,
    this.sessions = 0,
  });

  final DateTime date;
  final double steps;
  final double minutes;
  final double calories;
  final double reps;
  final double sessions;

  double valueOf(ChartMetric metric) => switch (metric) {
        ChartMetric.duration => minutes,
        ChartMetric.reps => reps,
        ChartMetric.calories => calories,
        ChartMetric.steps => steps,
        ChartMetric.sessions => sessions,
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
  final reps = List<double>.filled(window.days, 0);
  final sessions = List<double>.filled(window.days, 0);

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
    reps[i] += a.reps;
    sessions[i] += 1;
  }

  return List<DayBucket>.generate(
    window.days,
    (i) => DayBucket(
      date: DateTime(window.start.year, window.start.month, window.start.day + i),
      steps: steps[i],
      minutes: seconds[i] / 60.0,
      calories: calories[i],
      reps: reps[i],
      sessions: sessions[i],
    ),
  );
}

/// Ringkasan keseluruhan satu rentang (untuk strip di atas grafik).
class ChartSummary {
  const ChartSummary({
    this.sessions = 0,
    this.minutes = 0,
    this.calories = 0,
    this.reps = 0,
    this.steps = 0,
  });

  final double sessions;
  final double minutes;
  final double calories;
  final double reps;
  final double steps;
}

ChartSummary summarize(Iterable<DayBucket> buckets) {
  var sessions = 0.0, minutes = 0.0, calories = 0.0, reps = 0.0, steps = 0.0;
  for (final b in buckets) {
    sessions += b.sessions;
    minutes += b.minutes;
    calories += b.calories;
    reps += b.reps;
    steps += b.steps;
  }
  return ChartSummary(
    sessions: sessions,
    minutes: minutes,
    calories: calories,
    reps: reps,
    steps: steps,
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