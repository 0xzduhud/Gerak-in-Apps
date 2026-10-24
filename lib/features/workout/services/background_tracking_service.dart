import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ============================================================================
// [PBI-8.5] Pencatatan di latar belakang — foreground service Android.
// Service menjaga proses tetap hidup agar sensor tidak dimatikan sistem saat
// layar mati/aplikasi di belakang. Penghitungan langkah tetap di
// WorkoutSessionProvider (isolate utama). Di web/iOS semua method no-op.
// ============================================================================

/// Titik masuk isolate layanan; wajib top-level.
@pragma('vm:entry-point')
void gerakinTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(_TrackingTaskHandler());
}

class _TrackingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class BackgroundTracking {
  BackgroundTracking._();

  static const int _serviceId = 4201;
  static bool _initialized = false;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gerakin_tracking',
        channelName: 'Pencatatan aktivitas',
        channelDescription: 'Tampil saat Gerak-in menghitung langkahmu.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  /// Memulai layanan. Kegagalan di sini tidak boleh menghentikan sesi.
  static Future<void> start({required String sportName}) async {
    if (!_supported) return;
    try {
      _init();
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.isRunningService) return;

      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: 'Gerak-in: $sportName',
        notificationText: 'Sesi berjalan, langkah dihitung di latar belakang.',
        callback: gerakinTrackingCallback,
      );
      if (result is ServiceRequestFailure) {
        debugPrint('Layanan latar belakang gagal dimulai: ${result.error}');
      }
    } catch (e) {
      debugPrint('Layanan latar belakang error: $e');
    }
  }

  /// Memperbarui teks notifikasi dengan langkah dan waktu.
  static Future<void> update({
    required int steps,
    required Duration elapsed,
  }) async {
    if (!_supported) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(
        notificationText: '$steps langkah • ${_fmt(elapsed)}',
      );
    } catch (_) {
      // pembaruan notifikasi bersifat kosmetik
    }
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // layanan sudah berhenti
    }
  }
}
// ===================== AKHIR [PBI-8.5] BackgroundTracking ===================