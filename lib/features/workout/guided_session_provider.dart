import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/activity_model.dart';
import '../../data/models/sport_model.dart';
import 'services/motion_detector.dart';
import 'services/step_detector.dart' show AccelSample;
import 'session_spec.dart';

enum GuidedPhase { ready, work, rest, finished }

// ============================================================================
// [PBI-7.x/9.x] GuidedSessionProvider — sesi set demi set (repetisi / berwaktu)
// dengan istirahat. Sensor (jika ada) hanya menambah hitungan repetisi.
// Waktu memakai jam yang bisa disuntikkan agar mudah diuji.
// ============================================================================
class GuidedSessionProvider extends ChangeNotifier {
  GuidedSessionProvider({
    required this.sport,
    required this.spec,
    DateTime Function()? now,
    VoidCallback? onCue,
  })  : _now = now ?? DateTime.now,
        _onCue = onCue,
        _detector =
            spec.motion == null ? null : MotionDetector(type: spec.motion!);

  final Sport sport;
  final SessionSpec spec;
  final DateTime Function() _now;
  final VoidCallback? _onCue;
  final MotionDetector? _detector;

  GuidedPhase _phase = GuidedPhase.ready;
  bool _paused = false;
  DateTime? _startedAt;
  DateTime? _resumedAt; // null saat jeda atau belum mulai
  Duration _banked = Duration.zero; // waktu aktif yang sudah terkumpul
  Duration _phaseEnd = Duration.zero; // batas fase (waktu aktif)
  int _setIndex = 0;
  int _setReps = 0;
  int _lastDetectorReps = 0;
  final List<int> _doneReps = [];
  bool _receivedSamples = false;
  int _lastNotifyMs = 0;
  StreamSubscription<GyroSample>? _gyroSub;
  StreamSubscription<AccelSample>? _accelSub;
  Timer? _ticker;

  GuidedPhase get phase => _phase;
  bool get paused => _paused;

  /// Nomor set yang sedang/akan dikerjakan (mulai dari 1).
  int get setNumber => _setIndex + 1;
  int get setReps => _setReps;
  List<int> get doneReps => List.unmodifiable(_doneReps);

  int get totalReps =>
      _doneReps.fold<int>(0, (a, b) => a + b) +
      (_phase == GuidedPhase.work ? _setReps : 0);

  Duration get elapsed {
    final r = _resumedAt;
    return r == null ? _banked : _banked + _now().difference(r);
  }

  /// Sisa detik hitung mundur (istirahat atau set berwaktu), dibulatkan ke atas.
  int get remainingSeconds {
    final ms = (_phaseEnd - elapsed).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  bool get hasCountdown =>
      _phase == GuidedPhase.rest ||
      (_phase == GuidedPhase.work && spec.kind == SessionKind.timed);

  /// 0..1: seberapa dekat rotasi dengan ambang hitung (hanya gyroscope).
  double get gauge {
    final d = _detector;
    final m = spec.motion;
    if (d == null || m == null || !m.usesGyroscope) return 0;
    return (d.excursion / d.profile.amplitudeRad).clamp(0.0, 1.0).toDouble();
  }

  /// true jika set sudah berjalan >= 5 detik tetapi sensor belum mengirim data.
  bool get noSensorData =>
      spec.motion != null &&
      _phase == GuidedPhase.work &&
      !_paused &&
      !_receivedSamples &&
      elapsed.inSeconds >= 5;

  void start({Stream<GyroSample>? gyro, Stream<AccelSample>? accel}) {
    if (_phase != GuidedPhase.ready) return;
    _startedAt = _now();
    _resumedAt = _startedAt;
    _banked = Duration.zero;
    _beginWork();
    _gyroSub = gyro?.listen(addGyro);
    _accelSub = accel?.listen(addAccel);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => tick());
    notifyListeners();
  }

  void _beginWork() {
    _phase = GuidedPhase.work;
    _setReps = 0;
    _lastDetectorReps = 0;
    _detector?.reset();
    if (spec.kind == SessionKind.timed) {
      _phaseEnd = elapsed + Duration(seconds: spec.targetSeconds ?? 30);
    }
  }

  // ---- sensor -------------------------------------------------------------
  void addGyro(GyroSample sample) {
    final d = _detector;
    if (d == null || _phase != GuidedPhase.work || _paused) return;
    _receivedSamples = true;
    d.addGyro(sample);
    _afterSensor(sample.timestampMs);
  }

  void addAccel(AccelSample sample) {
    final d = _detector;
    if (d == null || _phase != GuidedPhase.work || _paused) return;
    // Untuk squat/push-up accelerometer hanya pendukung.
    if (!(spec.motion?.usesGyroscope ?? true)) _receivedSamples = true;
    d.addAccel(sample);
    _afterSensor(sample.timestampMs);
  }

  void _afterSensor(int timestampMs) {
    final reps = _detector!.reps;
    final delta = reps - _lastDetectorReps;
    _lastDetectorReps = reps;
    if (delta != 0) _setReps = (_setReps + delta).clamp(0, 9999);
    // Sensor bisa 50x per detik; tampilan cukup ~10x per detik.
    if (delta != 0 || timestampMs - _lastNotifyMs >= 100) {
      _lastNotifyMs = timestampMs;
      notifyListeners();
    }
  }

  // ---- aksi pengguna ------------------------------------------------------
  /// Koreksi atau hitung manual. Hanya berlaku saat set sedang berjalan.
  void adjustReps(int delta) {
    if (_phase != GuidedPhase.work || _paused) return;
    _setReps = (_setReps + delta).clamp(0, 9999);
    notifyListeners();
  }

  void completeSet() {
    if (_phase != GuidedPhase.work) return;
    _doneReps.add(_setReps);
    if (_setIndex + 1 >= spec.sets) {
      _finishInternal();
      return;
    }
    _setIndex++;
    _phase = GuidedPhase.rest;
    _phaseEnd = elapsed + Duration(seconds: spec.restSeconds);
    notifyListeners();
  }

  void skipRest() {
    if (_phase != GuidedPhase.rest) return;
    _beginWork();
    notifyListeners();
  }

  /// Tambah/kurangi sisa istirahat (mis. +15 / -15 detik).
  void adjustRest(int deltaSeconds) {
    if (_phase != GuidedPhase.rest) return;
    _phaseEnd += Duration(seconds: deltaSeconds);
    notifyListeners();
  }

  void pause() {
    if (_phase == GuidedPhase.ready ||
        _phase == GuidedPhase.finished ||
        _paused) {
      return;
    }
    _banked = elapsed;
    _resumedAt = null;
    _paused = true;
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _resumedAt = _now();
    _paused = false;
    notifyListeners();
  }

  /// Akhiri latihan sekarang. Repetisi set yang sedang berjalan ikut dihitung.
  void finish() {
    if (_phase == GuidedPhase.ready || _phase == GuidedPhase.finished) return;
    if (_phase == GuidedPhase.work && _setReps > 0) _doneReps.add(_setReps);
    _finishInternal();
  }

  void _finishInternal() {
    _banked = elapsed;
    _resumedAt = null;
    _paused = false;
    _stopSensors();
    _phase = GuidedPhase.finished;
    notifyListeners();
  }

  /// Dipanggil berkala; juga bisa dipanggil langsung dalam tes.
  void tick() {
    if (_paused) return;
    if (_phase == GuidedPhase.rest && remainingSeconds <= 0) {
      _onCue?.call();
      _beginWork();
    } else if (_phase == GuidedPhase.work &&
        spec.kind == SessionKind.timed &&
        remainingSeconds <= 0) {
      _onCue?.call();
      completeSet();
      return; // completeSet sudah memberi tahu pendengar
    }
    notifyListeners();
  }

  /// Ringkasan untuk riwayat. null jika belum selesai, atau tidak ada hasil
  /// berarti (tanpa repetisi dan kurang dari 5 detik).
  ActivitySummary? toSummary() {
    if (_phase != GuidedPhase.finished) return null;
    final seconds = _banked.inSeconds;
    if (totalReps <= 0 && seconds < 5) return null;
    return ActivitySummary(
      startedAt: _startedAt ?? _now(),
      durationSeconds: seconds,
      steps: 0,
      distanceMeters: 0,
      calories: sport.kcalPerMinute * seconds / 60,
      sportId: sport.id,
      reps: totalReps,
      motionType: spec.motion?.name,
    );
  }

  void _stopSensors() {
    _ticker?.cancel();
    _ticker = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _accelSub?.cancel();
    _accelSub = null;
  }

  @override
  void dispose() {
    _stopSensors();
    super.dispose();
  }
}