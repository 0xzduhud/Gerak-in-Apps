import 'dart:math' as math;

/// Satu pembacaan akselerometer (m/s²) beserta waktunya (milidetik).
class AccelSample {
  const AccelSample(this.x, this.y, this.z, this.timestampMs);

  final double x;
  final double y;
  final double z;
  final int timestampMs;
}

/// Deteksi langkah dari akselerometer (PBI-8.2):
/// magnitudo -> buang gravitasi -> haluskan -> deteksi puncak.
/// Murni Dart, tidak bergantung pada plugin sensor.
class StepDetector {
  StepDetector({
    this.threshold = 0.7,
    this.minStepIntervalMs = 300,
    this.maxStepIntervalMs = 1500,
    this.warmupSteps = 4,
    this.baselineTau = 1.0,
    this.smoothTau = 0.08,
  });

  /// Tinggi puncak minimum (m/s²). Disetel ulang saat kalibrasi (PBI-8.8).
  final double threshold;

  /// Jarak minimum antar dua langkah.
  final int minStepIntervalMs;

  /// Jika jarak antar puncak lebih dari ini, rangkaian langkah dianggap putus.
  final int maxStepIntervalMs;

  /// Jumlah langkah beruntun yang dibutuhkan sebelum mulai dihitung.
  final int warmupSteps;

  /// Konstanta waktu (detik) untuk baseline gravitasi.
  final double baselineTau;

  /// Konstanta waktu (detik) untuk penghalus sinyal.
  final double smoothTau;

  int _steps = 0;
  int? _lastTs;
  double? _baseline;
  double _smooth = 0;
  double? _p1; // sinyal halus sampel sebelumnya
  double? _p2; // dua sampel sebelumnya
  int _p1Ts = 0;
  int _streak = 0;
  int? _lastPeakTs;

  int get steps => _steps;

  void reset() {
    _steps = 0;
    _lastTs = null;
    _baseline = null;
    _smooth = 0;
    _p1 = null;
    _p2 = null;
    _p1Ts = 0;
    _streak = 0;
    _lastPeakTs = null;
  }

  /// Memproses satu sampel. Mengembalikan jumlah langkah baru yang terhitung
  /// (0, 1, atau [warmupSteps] saat rangkaian langkah pertama terkonfirmasi).
  int addSample(AccelSample s) {
    final m = math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
    final lastTs = _lastTs;
    final baseline = _baseline;

    if (baseline == null || lastTs == null) {
      _baseline = m;
      _smooth = 0;
      _lastTs = s.timestampMs;
      return 0;
    }

    final dt = (s.timestampMs - lastTs) / 1000.0;
    if (dt <= 0) return 0;
    _lastTs = s.timestampMs;

    // Celah data terlalu besar (sensor sempat berhenti): mulai ulang filter.
    if (dt > 1.0) {
      _baseline = m;
      _smooth = 0;
      _p1 = null;
      _p2 = null;
      return 0;
    }

    final newBaseline = baseline + (dt / (baselineTau + dt)) * (m - baseline);
    _baseline = newBaseline;
    final dynamicPart = m - newBaseline;

    _smooth += (dt / (smoothTau + dt)) * (dynamicPart - _smooth);
    final current = _smooth;

    var added = 0;
    final p1 = _p1;
    final p2 = _p2;
    if (p1 != null &&
        p2 != null &&
        p1 > p2 &&
        p1 >= current &&
        p1 > threshold) {
      added = _onPeak(_p1Ts);
    }

    _p2 = p1;
    _p1 = current;
    _p1Ts = s.timestampMs;
    return added;
  }

  int _onPeak(int ts) {
    final lastPeak = _lastPeakTs;
    if (lastPeak != null && ts - lastPeak < minStepIntervalMs) return 0;

    final continuous = lastPeak != null && ts - lastPeak <= maxStepIntervalMs;
    _lastPeakTs = ts;
    _streak = continuous ? _streak + 1 : 1;

    if (_streak < warmupSteps) return 0;
    if (_streak == warmupSteps) {
      _steps += warmupSteps;
      return warmupSteps;
    }
    _steps += 1;
    return 1;
  }
}