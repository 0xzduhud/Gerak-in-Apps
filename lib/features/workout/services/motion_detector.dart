import 'dart:math' as math;

import 'step_detector.dart' show AccelSample;

// [PBI-9.2] MotionDetector — deteksi gerakan olahraga + hitung repetisi.
// Murni Dart (tanpa plugin), jadi logikanya bisa dites tanpa HP.
//
// Squat & push-up (gyroscope): kecepatan sudut diintegralkan jadi sudut, lalu
// diukur seberapa jauh HP berputar dari posisi acuan (norma vektor, jadi arah
// dan orientasi HP tidak berpengaruh). Satu repetisi = HP berputar melewati
// ambang amplitudo lalu kembali ke dekat posisi acuan dalam rentang waktu yang
// masuk akal. Drift dikurangi dengan (1) estimasi bias saat HP diam dan
// (2) penambatan ulang acuan saat HP berhenti sejenak di dekat acuan.
//
// Lompat (accelerometer): fase melayang disusul hentakan pendaratan.
// Ambang di MotionProfile adalah perkiraan awal; disetel lewat uji HP (9.6).

/// Satu pembacaan gyroscope: kecepatan sudut (rad/s) dan waktunya (ms).
class GyroSample {
  const GyroSample(this.x, this.y, this.z, this.timestampMs);

  final double x;
  final double y;
  final double z;
  final int timestampMs;
}

enum MotionType {
  squat,
  pushUp,
  jump;

  String get label => switch (this) {
        MotionType.squat => 'Squat',
        MotionType.pushUp => 'Push-up',
        MotionType.jump => 'Lompat',
      };

  /// Lompat memakai accelerometer; yang lain memakai gyroscope.
  bool get usesGyroscope => this != MotionType.jump;

  /// Cocokkan id olahraga di sports_seed.json dengan jenis gerakan.
  static MotionType? fromSportId(String? id) => switch (id) {
        'squat' => MotionType.squat,
        'push-up' => MotionType.pushUp,
        'jumping-jack' => MotionType.jump,
        _ => null,
      };
}

/// Ambang deteksi untuk gerakan berbasis rotasi.
class MotionProfile {
  const MotionProfile({
    required this.amplitudeRad,
    required this.releaseRad,
    required this.minRepMs,
    required this.maxRepMs,
    this.minAccelMs2 = 0,
  });

  /// Rotasi minimum (rad) dari posisi acuan agar dihitung sebagai gerakan.
  final double amplitudeRad;

  /// Rotasi (rad) di bawah mana HP dianggap sudah kembali ke posisi acuan.
  final double releaseRad;

  /// Durasi repetisi tercepat dan terlama (ms). Di luar rentang = diabaikan.
  final int minRepMs;
  final int maxRepMs;

  /// [PBI-9.4] Gerakan accelerometer minimum (m/s², di luar gravitasi) yang
  /// harus terjadi selama repetisi. 0 = filter dimatikan.
  final double minAccelMs2;

  static const MotionProfile squat = MotionProfile(
    amplitudeRad: 0.45, // sekitar 26 derajat
    releaseRad: 0.18,
    minRepMs: 800,
    maxRepMs: 6000,
    minAccelMs2: 0.3,
  );

  static const MotionProfile pushUp = MotionProfile(
    amplitudeRad: 0.20, // sekitar 11 derajat
    releaseRad: 0.08,
    minRepMs: 500,
    maxRepMs: 5000,
    minAccelMs2: 0.25,
  );

  static MotionProfile forType(MotionType type) => switch (type) {
        MotionType.squat => squat,
        MotionType.pushUp => pushUp,
        MotionType.jump => squat, // tidak dipakai; lompat memakai accelerometer
      };
}

enum _Phase { rest, peak }

class MotionDetector {
  MotionDetector({required this.type, MotionProfile? profile, this.fuse = true})
      : profile = profile ?? MotionProfile.forType(type);

  final MotionType type;
  final MotionProfile profile;

  /// [PBI-9.4] true = repetisi gyroscope harus dikonfirmasi accelerometer.
  final bool fuse;

  // Konstanta lompat (accelerometer, m/s²)
  static const double freefallMs2 = 4.0;
  static const double impactMs2 = 14.0;
  static const int minFlightMs = 80;
  static const int maxLandingGapMs = 300;
  static const int minJumpIntervalMs = 400;

  // Konstanta gyroscope
  static const double stillRadPerSec = 0.06;
  static const double slowRadPerSec = 0.25;
  static const int dwellMs = 100;
  static const double biasTauSec = 2.0;
  static const double anchorTauSec = 3.0;
  static const double maxGapSec = 0.5;
  // [PBI-9.4] Penggabungan accelerometer
  static const int accelWindowMs = 2000;
  static const double accelBaselineTauSec = 1.0;
  static const double maxAccelGapSec = 1.0;

  int _reps = 0;

  // Gyroscope
  int? _lastGyroTs;
  double _biasX = 0, _biasY = 0, _biasZ = 0;
  double _angX = 0, _angY = 0, _angZ = 0;
  double _refX = 0, _refY = 0, _refZ = 0;
  _Phase _phase = _Phase.rest;
  int? _excursionStartMs;
  double _excursion = 0;
  int? _slowSinceMs;

  // Lompat
  int? _freefallStartMs;
  int? _lastFreefallMs;
  int _lastFlightMs = 0;
  int? _lastJumpMs;
// [PBI-9.4] Pelacak gerakan accelerometer untuk squat/push-up
  double? _accelBaseline;
  int? _accelLastTs;
  double _accelPeak = 0;
  int _accelPeakTs = -1000000;
  int _accelSamples = 0;
  int _rejected = 0;
  int get reps => _reps;
  int get rejectedReps => _rejected;

  /// Rotasi saat ini dari posisi acuan (rad). Untuk umpan balik visual.
  double get excursion => _excursion;

  bool get inRep => _phase == _Phase.peak;

  void reset() {
    _reps = 0;
    _lastGyroTs = null;
    _biasX = _biasY = _biasZ = 0;
    _angX = _angY = _angZ = 0;
    _refX = _refY = _refZ = 0;
    _phase = _Phase.rest;
    _excursionStartMs = null;
    _excursion = 0;
    _slowSinceMs = null;
    _freefallStartMs = null;
    _lastFreefallMs = null;
    _lastFlightMs = 0;
    _lastJumpMs = null;
    _accelBaseline = null;
    _accelLastTs = null;
    _accelPeak = 0;
    _accelPeakTs = -1000000;
    _accelSamples = 0;
    _rejected = 0;
  }

  void _snapReference() {
    _refX = _angX;
    _refY = _angY;
    _refZ = _angZ;
    _phase = _Phase.rest;
    _excursionStartMs = null;
    _excursion = 0;
    _slowSinceMs = null;
  }

  /// Mengembalikan 1 jika sebuah repetisi baru selesai, selain itu 0.
  /// Diabaikan untuk gerakan lompat.
  int addGyro(GyroSample s) {
    if (!type.usesGyroscope) return 0;

    final last = _lastGyroTs;
    _lastGyroTs = s.timestampMs;
    if (last == null) return 0;
    final dt = (s.timestampMs - last) / 1000.0;
    if (dt <= 0) return 0;
    if (dt > maxGapSec) {
      // Sensor sempat berhenti: jangan mengintegralkan celah itu.
      _snapReference();
      return 0;
    }

    // Estimasi bias saat HP diam.
    var cx = s.x - _biasX;
    var cy = s.y - _biasY;
    var cz = s.z - _biasZ;
    if (math.sqrt(cx * cx + cy * cy + cz * cz) < stillRadPerSec) {
      final k = dt / (biasTauSec + dt);
      _biasX += (s.x - _biasX) * k;
      _biasY += (s.y - _biasY) * k;
      _biasZ += (s.z - _biasZ) * k;
      cx = s.x - _biasX;
      cy = s.y - _biasY;
      cz = s.z - _biasZ;
    }

    _angX += cx * dt;
    _angY += cy * dt;
    _angZ += cz * dt;

    final dx = _angX - _refX;
    final dy = _angY - _refY;
    final dz = _angZ - _refZ;
    final e = math.sqrt(dx * dx + dy * dy + dz * dz);
    _excursion = e;

    final ts = s.timestampMs;
    switch (_phase) {
      case _Phase.rest:
        if (e < profile.releaseRad) {
          // Dekat acuan: tambatkan pelan-pelan agar drift tidak menumpuk.
          final k = dt / (anchorTauSec + dt);
          _refX += (_angX - _refX) * k;
          _refY += (_angY - _refY) * k;
          _refZ += (_angZ - _refZ) * k;
          _excursionStartMs = null;
          // HP berhenti sejenak di dekat acuan: tambatkan penuh (hapus drift).
          if (math.sqrt(cx * cx + cy * cy + cz * cz) < slowRadPerSec) {
            final since = _slowSinceMs;
            if (since == null) {
              _slowSinceMs = ts;
            } else if (ts - since >= dwellMs) {
              _refX = _angX;
              _refY = _angY;
              _refZ = _angZ;
              _excursion = 0;
              _slowSinceMs = ts;
            }
          } else {
            _slowSinceMs = null;
          }
        } else {
          _slowSinceMs = null;
          _excursionStartMs ??= ts;
          if (e >= profile.amplitudeRad) {
            _phase = _Phase.peak;
          } else if (ts - _excursionStartMs! > profile.maxRepMs) {
            // Berputar pelan tanpa mencapai amplitudo: anggap drift.
            _snapReference();
          }
        }
        return 0;
      case _Phase.peak:
        final start = _excursionStartMs ?? ts;
        if (e <= profile.releaseRad) {
          final duration = ts - start;
          // Acuan sengaja tidak digeser di sini: HP masih di tengah gerakan.
          _phase = _Phase.rest;
          _excursionStartMs = null;
          if (duration >= profile.minRepMs && duration <= profile.maxRepMs) {
            if (_motionConfirmed(ts)) {
              _reps++;
              return 1;
            }
            _rejected++;
          }
          return 0;
        }
        if (ts - start > profile.maxRepMs) {
          // Tertahan terlalu lama (mis. HP diputar lalu dibiarkan).
          _snapReference();
        }
        return 0;
    }
  }

  /// Hanya untuk lompat. Mengembalikan 1 jika satu lompatan baru mendarat.
  /// Lompat: mengembalikan 1 jika satu lompatan baru mendarat.
  /// Squat/push-up: hanya mencatat gerakan untuk filter [PBI-9.4], selalu 0.
  int addAccel(AccelSample s) {
    if (type != MotionType.jump) {
      _trackMotion(s);
      return 0;
    }

    final m = math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
    final ts = s.timestampMs;

    if (m < freefallMs2) {
      _freefallStartMs ??= ts;
      _lastFreefallMs = ts;
      return 0;
    }

    // Keluar dari fase melayang: catat lamanya.
    final start = _freefallStartMs;
    final lastFree = _lastFreefallMs;
    if (start != null && lastFree != null) {
      _lastFlightMs = lastFree - start;
      _freefallStartMs = null;
    }

    if (m >= impactMs2 && lastFree != null) {
      final sinceFlight = ts - lastFree;
      final recentJump =
          _lastJumpMs != null && ts - _lastJumpMs! < minJumpIntervalMs;
      if (_lastFlightMs >= minFlightMs &&
          sinceFlight <= maxLandingGapMs &&
          !recentJump) {
        _lastFlightMs = 0;
        _lastJumpMs = ts;
        _reps++;
        return 1;
      }
    }
    return 0;
  }

  // [PBI-9.4] Magnitudo accelerometer tidak berubah saat HP hanya diputar,
  // tetapi berubah saat badan benar-benar naik-turun. Simpan puncak
  // penyimpangannya dalam jendela waktu terakhir.
  void _trackMotion(AccelSample s) {
    _accelSamples++;
    final m = math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
    final last = _accelLastTs;
    final base = _accelBaseline;
    if (base == null || last == null) {
      _accelBaseline = m;
      _accelLastTs = s.timestampMs;
      return;
    }
    final dt = (s.timestampMs - last) / 1000.0;
    if (dt <= 0) return;
    _accelLastTs = s.timestampMs;
    if (dt > maxAccelGapSec) {
      _accelBaseline = m;
      return;
    }
    final newBase = base + (dt / (accelBaselineTauSec + dt)) * (m - base);
    _accelBaseline = newBase;
    final d = (m - newBase).abs();
    if (d >= _accelPeak || s.timestampMs - _accelPeakTs > accelWindowMs) {
      _accelPeak = d;
      _accelPeakTs = s.timestampMs;
    }
  }

  bool _motionConfirmed(int ts) {
    // Tanpa data accelerometer sama sekali, jangan menolak apa pun.
    if (!fuse || profile.minAccelMs2 <= 0 || _accelSamples == 0) return true;
    return ts - _accelPeakTs <= accelWindowMs &&
        _accelPeak >= profile.minAccelMs2;
  }
}