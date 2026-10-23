import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 01:05.23, atau 1:02:03 jika lebih dari satu jam.
String formatStopwatch(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final cs = d.inMilliseconds.remainder(1000) ~/ 10;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}.${_two(cs)}';
}

/// 75 -> 01:15
String formatClock(int totalSeconds) =>
    '${_two(totalSeconds ~/ 60)}:${_two(totalSeconds % 60)}';

final ButtonStyle _outlinedStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColors.secondary,
  side: const BorderSide(color: AppColors.secondary),
  minimumSize: const Size.fromHeight(48),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

const TextStyle _bigDigits = TextStyle(
  fontSize: 44,
  fontWeight: FontWeight.bold,
  color: AppColors.textPrimary,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

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
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PBI-7.8: Stopwatch
// ---------------------------------------------------------------------------
class StopwatchPanel extends StatefulWidget {
  const StopwatchPanel({super.key});

  @override
  State<StopwatchPanel> createState() => _StopwatchPanelState();
}

class _StopwatchPanelState extends State<StopwatchPanel> {
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;

  void _start() {
    _sw.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  void _pause() {
    _sw.stop();
    _ticker?.cancel();
    setState(() {});
  }

  void _reset() {
    _sw
      ..stop()
      ..reset();
    _ticker?.cancel();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _sw.elapsed;
    final running = _sw.isRunning;
    final untouched = elapsed == Duration.zero && !running;

    return _PanelCard(
      icon: Icons.timer_outlined,
      title: 'Stopwatch',
      child: Column(
        children: [
          Center(child: Text(formatStopwatch(elapsed), style: _bigDigits)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: running
                    ? OutlinedButton.icon(
                        onPressed: _pause,
                        icon: const Icon(Icons.pause_rounded),
                        label: const Text('Jeda'),
                        style: _outlinedStyle,
                      )
                    : ElevatedButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          elapsed == Duration.zero ? 'Mulai' : 'Lanjut',
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: untouched ? null : _reset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset'),
                  style: _outlinedStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PBI-7.9: Timer interval (latihan, istirahat, ronde) + getar & bunyi
// ---------------------------------------------------------------------------
enum _Phase { idle, work, rest, done }

class IntervalTimerPanel extends StatefulWidget {
  const IntervalTimerPanel({
    super.key,
    this.initialWorkSeconds = 40,
    this.initialRestSeconds = 20,
    this.initialRounds = 3,
  });

  final int initialWorkSeconds;
  final int initialRestSeconds;
  final int initialRounds;

  @override
  State<IntervalTimerPanel> createState() => _IntervalTimerPanelState();
}

class _IntervalTimerPanelState extends State<IntervalTimerPanel> {
  late int _workSeconds = widget.initialWorkSeconds;
  late int _restSeconds = widget.initialRestSeconds;
  late int _rounds = widget.initialRounds;

  _Phase _phase = _Phase.idle;
  int _currentRound = 1;
  int _remainingMs = 0;
  int _phaseTotalMs = 0;
  int _lastCueSecond = -1;
  bool _running = false;

  Timer? _timer;
  DateTime _lastTick = DateTime.now();

  bool get _active => _phase == _Phase.work || _phase == _Phase.rest;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---- pengaturan (hanya bisa diubah saat belum jalan)
  void _changeWork(int delta) =>
      setState(() => _workSeconds = (_workSeconds + delta).clamp(5, 600).toInt());

  void _changeRest(int delta) =>
      setState(() => _restSeconds = (_restSeconds + delta).clamp(0, 300).toInt());

  void _changeRounds(int delta) =>
      setState(() => _rounds = (_rounds + delta).clamp(1, 20).toInt());

  // ---- kontrol
  void _start() {
    if (!_active) {
      _currentRound = 1;
      _beginPhase(_Phase.work);
      _cuePhaseChange();
    }
    _resume();
  }

  void _resume() {
    _running = true;
    _lastTick = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _phase = _Phase.idle;
      _currentRound = 1;
      _remainingMs = 0;
      _phaseTotalMs = 0;
    });
  }

  // ---- mesin fase
  void _beginPhase(_Phase phase) {
    _phase = phase;
    _phaseTotalMs =
        (phase == _Phase.work ? _workSeconds : _restSeconds) * 1000;
    _remainingMs = _phaseTotalMs;
    _lastCueSecond = -1;
  }

  void _onTick(Timer timer) {
    final now = DateTime.now();
    _remainingMs -= now.difference(_lastTick).inMilliseconds;
    _lastTick = now;

    if (_remainingMs <= 0) {
      _advance();
      return;
    }

    final sec = (_remainingMs / 1000).ceil();
    if (sec <= 3 && sec != _lastCueSecond) {
      _lastCueSecond = sec;
      _cueCountdown();
    }
    setState(() {});
  }

  void _advance() {
    if (_phase == _Phase.work) {
      if (_currentRound >= _rounds) {
        _finish();
        return;
      }
      if (_restSeconds > 0) {
        _beginPhase(_Phase.rest);
      } else {
        _currentRound++;
        _beginPhase(_Phase.work);
      }
    } else {
      _currentRound++;
      _beginPhase(_Phase.work);
    }
    _cuePhaseChange();
    setState(() {});
  }

  void _finish() {
    _timer?.cancel();
    _cueFinish();
    setState(() {
      _running = false;
      _phase = _Phase.done;
      _remainingMs = 0;
    });
  }

  // ---- penanda getaran dan bunyi
  void _cueCountdown() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  void _cuePhaseChange() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  Future<void> _cueFinish() async {
    for (var i = 0; i < 3; i++) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idle = _phase == _Phase.idle;
    final done = _phase == _Phase.done;
    final paused = _active && !_running;

    final seconds = idle
        ? _workSeconds
        : done
            ? 0
            : (_remainingMs / 1000).ceil();

    final phaseColor = switch (_phase) {
      _Phase.work => AppColors.primary,
      _Phase.rest => AppColors.secondary,
      _ => AppColors.textPrimary,
    };
    final phaseLabel = switch (_phase) {
      _Phase.idle => 'SIAP',
      _Phase.work => 'LATIHAN',
      _Phase.rest => 'ISTIRAHAT',
      _Phase.done => 'SELESAI',
    };
    final progress = done
        ? 1.0
        : (_active && _phaseTotalMs > 0)
            ? (1 - _remainingMs / _phaseTotalMs).clamp(0.0, 1.0).toDouble()
            : 0.0;

    return _PanelCard(
      icon: Icons.av_timer_rounded,
      title: 'Timer interval',
      child: Column(
        children: [
          _Stepper(
            label: 'Durasi latihan',
            value: '$_workSeconds dtk',
            onMinus: idle ? () => _changeWork(-5) : null,
            onPlus: idle ? () => _changeWork(5) : null,
          ),
          _Stepper(
            label: 'Durasi istirahat',
            value: '$_restSeconds dtk',
            onMinus: idle ? () => _changeRest(-5) : null,
            onPlus: idle ? () => _changeRest(5) : null,
          ),
          _Stepper(
            label: 'Jumlah ronde',
            value: '$_rounds',
            onMinus: idle ? () => _changeRounds(-1) : null,
            onPlus: idle ? () => _changeRounds(1) : null,
          ),
          const SizedBox(height: 16),
          Text(
            phaseLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: phaseColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(formatClock(seconds), style: _bigDigits),
          const SizedBox(height: 4),
          Text(
            _active
                ? 'Ronde $_currentRound / $_rounds'
                : done
                    ? '$_rounds ronde selesai'
                    : '$_rounds ronde',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: phaseColor,
              backgroundColor: AppColors.surfaceHigh,
            ),
          ),
          const SizedBox(height: 16),
          if (done)
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Ulangi'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _running
                      ? OutlinedButton.icon(
                          onPressed: _pause,
                          icon: const Icon(Icons.pause_rounded),
                          label: const Text('Jeda'),
                          style: _outlinedStyle,
                        )
                      : ElevatedButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(paused ? 'Lanjut' : 'Mulai'),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: idle ? null : _reset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset'),
                    style: _outlinedStyle,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        IconButton(
          onPressed: onMinus,
          color: AppColors.primary,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 64,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: onPlus,
          color: AppColors.primary,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}