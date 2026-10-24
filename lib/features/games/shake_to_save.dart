import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Kartu "Goyangkan HP" untuk layar hasil game.
/// Skor baru dianggap setelah HP digoyang [requiredShakes] kali,
/// lalu [onShaken] dipanggil (simpan skor dan kembali ke Home).
///
/// Tombol cadangan hanya muncul di mode debug atau bila sensor tidak
/// tersedia (web/emulator), sehingga pada demo tampilannya hanya goyang.
class ShakeToSaveCard extends StatefulWidget {
  const ShakeToSaveCard({
    super.key,
    required this.onShaken,
    this.requiredShakes = 3,
  });

  final Future<void> Function() onShaken;
  final int requiredShakes;

  @override
  State<ShakeToSaveCard> createState() => _ShakeToSaveCardState();
}

class _ShakeToSaveCardState extends State<ShakeToSaveCard> {
  static const Color _primaryOrange = Color(0xFFE86524);
  static const Color _cardColor = Color(0xFF1E1E1E);
  static const Color _cardBorderColor = Color(0xFF2C2C2C);

  /// Batas percepatan (m/s^2) tanpa gravitasi yang dihitung sebagai goyangan.
  static const double _threshold = 12;
  static const Duration _minGap = Duration(milliseconds: 300);
  static const Duration _window = Duration(seconds: 2);

  StreamSubscription<UserAccelerometerEvent>? _sub;
  int _count = 0;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sensorOk = !kIsWeb;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      try {
        _sub = userAccelerometerEventStream().listen(
          _onEvent,
          onError: (_) {
            if (mounted) setState(() => _sensorOk = false);
          },
        );
      } catch (_) {
        _sensorOk = false;
      }
    }
  }

  void _onEvent(UserAccelerometerEvent e) {
    if (_done) return;
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitude < _threshold) return;

    final now = DateTime.now();
    final diff = now.difference(_lastShake);
    if (diff < _minGap) return;
    if (diff > _window) _count = 0;

    _lastShake = now;
    _count++;
    HapticFeedback.mediumImpact();
    if (mounted) setState(() {});

    if (_count >= widget.requiredShakes) _complete();
  }

  Future<void> _complete() async {
    if (_done) return;
    _done = true;
    await _sub?.cancel();
    if (mounted) setState(() {});
    await widget.onShaken();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showFallback = !_sensorOk || kDebugMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(
            _done ? Icons.check_circle_rounded : Icons.vibration_rounded,
            color: _primaryOrange,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            _done ? 'Skor tersimpan!' : 'Goyangkan HP untuk menyimpan skor',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.requiredShakes, (i) {
              final active = i < _count;
              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? _primaryOrange : _cardBorderColor,
                ),
              );
            }),
          ),
          if (showFallback && !_done) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _complete,
              child: const Text(
                'Simpan tanpa goyang (mode uji)',
                style: TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
