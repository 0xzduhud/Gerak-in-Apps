import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/theme.dart';
import '../../../data/models/sport_model.dart';
import '../services/motion_detector.dart';
import '../services/step_detector.dart' show AccelSample;
import 'workout_session_screen.dart' show AccelerometerService;
import '../../../data/models/activity_model.dart';
import '../../../data/repositories/activity_repository.dart';

// [PBI-9.1] GyroscopeService — pembungkus sensors_plus untuk gyroscope (rad/s).
class GyroscopeService {
  const GyroscopeService();

  Stream<GyroSample> samples({
    Duration interval = SensorInterval.gameInterval,
  }) {
    final clock = Stopwatch()..start();
    return gyroscopeEventStream(samplingPeriod: interval)
        .map((e) => GyroSample(e.x, e.y, e.z, clock.elapsedMilliseconds))
        .handleError((Object error) {
      // Perangkat tanpa gyroscope (mis. Edge desktop) tidak boleh crash.
      debugPrint('Gyroscope tidak tersedia: $error');
    });
  }
}

// [PBI-9.3] Mode latihan dengan penghitung repetisi.
// [PBI-9.5] Umpan balik: angka berdenyut + getar, serta bar rotasi langsung.

enum MotionSessionState { idle, running, finished }

class MotionSessionProvider extends ChangeNotifier {
  MotionSessionProvider({
    MotionType type = MotionType.squat,
    DateTime Function()? now,
  })  : _type = type,
        _detector = MotionDetector(type: type),
        _now = now ?? DateTime.now;

  final DateTime Function() _now;

  MotionType _type;
  MotionDetector _detector;
  MotionSessionState _state = MotionSessionState.idle;
  DateTime? _startedAt;
  Duration _finalElapsed = Duration.zero;
  bool _receivedSamples = false;
  int _lastNotifyMs = 0;
  StreamSubscription<GyroSample>? _gyroSub;
  StreamSubscription<AccelSample>? _accelSub;
  Timer? _ticker;

  MotionType get type => _type;
  MotionSessionState get state => _state;
  int get reps => _detector.reps;
  int get rejectedReps => _detector.rejectedReps;

  /// 0..1: seberapa dekat rotasi dengan ambang hitung.
  double get gauge {
    if (!_type.usesGyroscope) return 0;
    final amplitude = _detector.profile.amplitudeRad;
    return (_detector.excursion / amplitude).clamp(0.0, 1.0).toDouble();
  }

  Duration get elapsed => _state == MotionSessionState.running
      ? _now().difference(_startedAt ?? _now())
      : _finalElapsed;

  /// true jika sesi sudah berjalan >= 3 detik tetapi belum ada data sensor.
  bool get noSensorData =>
      _state == MotionSessionState.running &&
      !_receivedSamples &&
      elapsed.inSeconds >= 3;

  void selectType(MotionType type) {
    if (_state != MotionSessionState.idle || type == _type) return;
    _type = type;
    _detector = MotionDetector(type: type);
    notifyListeners();
  }

  /// Berikan [gyro] untuk squat/push-up atau [accel] untuk lompat.
  void start({Stream<GyroSample>? gyro, Stream<AccelSample>? accel}) {
    if (_state == MotionSessionState.running) return;
    _detector.reset();
    _receivedSamples = false;
    _lastNotifyMs = 0;
    _finalElapsed = Duration.zero;
    _startedAt = _now();
    _state = MotionSessionState.running;
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _gyroSub = gyro?.listen(addGyro);
    _accelSub = accel?.listen(addAccel);
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    notifyListeners();
  }

  void addGyro(GyroSample sample) {
    if (_state != MotionSessionState.running) return;
    _receivedSamples = true;
    final added = _detector.addGyro(sample);
    _maybeNotify(sample.timestampMs, force: added > 0);
  }

  void addAccel(AccelSample sample) {
    if (_state != MotionSessionState.running) return;
    // Untuk squat/push-up accelerometer hanya pendukung; yang menentukan
    // "ada data sensor" adalah gyroscope.
    if (!_type.usesGyroscope) _receivedSamples = true;
    final added = _detector.addAccel(sample);
    _maybeNotify(sample.timestampMs, force: added > 0);
  }

  // Sensor bisa 50x per detik; tampilan cukup ~10x per detik.
  void _maybeNotify(int timestampMs, {required bool force}) {
    if (force || timestampMs - _lastNotifyMs >= 100) {
      _lastNotifyMs = timestampMs;
      notifyListeners();
    }
  }

  void finish() {
    if (_state != MotionSessionState.running) return;
    _finalElapsed = _now().difference(_startedAt ?? _now());
    _stopSensors();
    _state = MotionSessionState.finished;
    notifyListeners();
  }

    /// Ringkasan untuk disimpan ke riwayat. null jika sesi belum selesai
  /// atau tidak ada repetisi yang terhitung.
  ActivitySummary? toSummary() {
    if (_state != MotionSessionState.finished || reps <= 0) return null;
    return ActivitySummary(
      startedAt: _startedAt ?? _now(),
      durationSeconds: _finalElapsed.inSeconds,
      steps: 0,
      distanceMeters: 0,
      calories: 0,
      reps: reps,
      motionType: _type.name,
    );
  }

  void reset() {
    _stopSensors();
    _detector.reset();
    _state = MotionSessionState.idle;
    _finalElapsed = Duration.zero;
    _startedAt = null;
    _receivedSamples = false;
    notifyListeners();
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

String _fmt(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
}

// [PBI-9.x] Akhiri sesi gerakan lalu simpan jika ada repetisi.
Future<void> _finishAndSave(
  BuildContext context,
  MotionSessionProvider session,
) async {
  final messenger = ScaffoldMessenger.of(context);
  session.finish();
  final summary = session.toSummary();
  if (summary == null) return; // 0 repetisi: tidak disimpan
  try {
    await ActivityRepository().save(summary);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${summary.reps} repetisi tersimpan.')),
      );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Gagal menyimpan hasil: $e')));
  }
}

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

class MotionModeScreen extends StatelessWidget {
  const MotionModeScreen({
    super.key,
    this.sport,
    this.initialType,
    this.gyroscope = const GyroscopeService(),
    this.accelerometer = const AccelerometerService(),
  });

  final Sport? sport;
  final MotionType? initialType;
  final GyroscopeService gyroscope;
  final AccelerometerService accelerometer;

  @override
  Widget build(BuildContext context) {
    final type = initialType ??
        MotionType.fromSportId(sport?.id) ??
        MotionType.squat;
    return ChangeNotifierProvider<MotionSessionProvider>(
      create: (_) => MotionSessionProvider(type: type),
      child: _MotionView(gyroscope: gyroscope, accelerometer: accelerometer),
    );
  }
}

class _MotionView extends StatelessWidget {
  const _MotionView({required this.gyroscope, required this.accelerometer});

  final GyroscopeService gyroscope;
  final AccelerometerService accelerometer;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<MotionSessionProvider>();
    final type = session.type;
    final state = session.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Mode deteksi gerakan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            SegmentedButton<MotionType>(
              segments: [
                for (final t in MotionType.values)
                  ButtonSegment<MotionType>(value: t, label: Text(t.label)),
              ],
              selected: {type},
              showSelectedIcon: false,
              onSelectionChanged: state == MotionSessionState.idle
                  ? (selection) => session.selectType(selection.first)
                  : null,
            ),
            const SizedBox(height: 24),
            Center(child: _RepCounter(reps: session.reps)),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'repetisi ${type.label.toLowerCase()}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            if (type.usesGyroscope) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: session.gauge,
                  minHeight: 10,
                  backgroundColor: AppColors.surfaceHigh,
                  color: session.gauge >= 1
                      ? AppColors.secondary
                      : AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bar penuh = gerakan cukup dalam untuk dihitung.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              switch (state) {
                MotionSessionState.idle => 'Siap dimulai',
                MotionSessionState.running =>
                  'Sedang berjalan • ${_fmt(session.elapsed)}',
                MotionSessionState.finished =>
                  'Selesai • ${session.reps} repetisi dalam '
                      '${_fmt(session.elapsed)}',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _HintCard(_placementHint(type)),
            if (kIsWeb || session.noSensorData) ...[
              const SizedBox(height: 10),
              _HintCard(
                kIsWeb
                    ? 'Di browser/PC sensor gerak biasanya tidak tersedia. '
                        'Uji fitur ini di HP Android.'
                    : 'Belum ada data sensor. Pastikan HP punya '
                        '${type.usesGyroscope ? 'gyroscope' : 'accelerometer'}.',
              ),
            ],
            if (state == MotionSessionState.finished) ...[
              const SizedBox(height: 10),
              const _HintCard(
                'Hasil disimpan ke riwayat jika ada repetisi yang terhitung.',
              ),
            ],

            if (state == MotionSessionState.finished &&
                type.usesGyroscope &&
                session.rejectedReps > 0) ...[
              const SizedBox(height: 10),
              _HintCard(
                '${session.rejectedReps} gerakan ditolak karena HP hanya '
                'berputar tanpa badan bergerak. Jika itu repetisi asli, '
                'ambang minAccelMs2 perlu diturunkan.',
              ),
            ],
             const SizedBox(height: 24),
            _Controls(gyroscope: gyroscope, accelerometer: accelerometer),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.gyroscope, required this.accelerometer});

  final GyroscopeService gyroscope;
  final AccelerometerService accelerometer;

  @override
  Widget build(BuildContext context) {
    final session = context.read<MotionSessionProvider>();
    final state = context.select<MotionSessionProvider, MotionSessionState>(
      (s) => s.state,
    );

    switch (state) {
      case MotionSessionState.idle:
        return ElevatedButton.icon(
          onPressed: () {
            if (session.type.usesGyroscope) {
              // [PBI-9.4] gyroscope menghitung, accelerometer mengonfirmasi.
              session.start(
                gyro: gyroscope.samples(),
                accel: accelerometer.samples(),
              );
            } else {
              session.start(accel: accelerometer.samples());
            }
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Mulai'),
        );
      case MotionSessionState.running:
        return ElevatedButton.icon(
          onPressed: () => _finishAndSave(context, session),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Selesai'),
        );
      case MotionSessionState.finished:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: session.reset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Ulangi'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Tutup'),
              ),
            ),
          ],
        );
    }
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
        width: 200,
        height: 200,
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
            fontSize: 84,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
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