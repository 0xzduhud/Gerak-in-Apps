import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

String _two(int n) => n.toString().padLeft(2, '0');

// ============================================================================
// [PBI-7.9] Beeper — nada pendek. Android: ToneGenerator lewat MethodChannel
// (MainActivity.kt). Platform lain: SystemSound sebagai cadangan.
// Dipakai sebagai penanda akhir istirahat dan akhir set berwaktu.
// ============================================================================
class Beeper {
  Beeper._();

  static const MethodChannel _channel = MethodChannel('gerakin/beep');

  static Future<void> beep({int durationMs = 150}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('beep', {'durationMs': durationMs});
        return;
      } catch (_) {
        // jatuh ke cadangan di bawah
      }
    }
    SystemSound.play(SystemSoundType.alert);
  }
}

/// 01:05.23, atau 1:02:03 jika lebih dari satu jam.
String formatStopwatch(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final cs = d.inMilliseconds.remainder(1000) ~/ 10;
  return h > 0
      ? '$h:${_two(m)}:${_two(s)}'
      : '${_two(m)}:${_two(s)}.${_two(cs)}';
}

/// 75 -> 01:15
String formatClock(int totalSeconds) =>
    '${_two(totalSeconds ~/ 60)}:${_two(totalSeconds % 60)}';