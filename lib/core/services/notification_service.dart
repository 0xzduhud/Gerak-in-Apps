import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/schedule_model.dart';
import '../utils/reminder_planner.dart';

/// Antarmuka agar provider mudah diuji tanpa plugin asli.
abstract class ReminderScheduler {
  /// Meminta izin notifikasi (dialog hanya muncul jika belum diizinkan).
  Future<bool> ensurePermission();

  /// false hanya jika platform mendukung tetapi izin dimatikan pengguna.
  Future<bool> isEnabled();

  /// Menyamakan alarm sistem dengan daftar jadwal terbaru.
  Future<void> sync(List<WorkoutSchedule> schedules);
}

// ============================================================================
// [PBI-13B] NotificationService — notifikasi sistem terjadwal (khusus Android)
// Di platform lain (web, dll.) semua fungsi aman dipanggil dan tidak berbuat apa-apa.
// ============================================================================
class NotificationService implements ReminderScheduler {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _maxScheduled = 50;
  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'schedule_reminder',
      'Pengingat jadwal',
      channelDescription: 'Pengingat sebelum jadwal workout dimulai',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Panggil sekali saat aplikasi mulai. Tidak pernah melempar error.
  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Gagal init notifikasi: $e');
    }
  }

  @override
  Future<bool> ensurePermission() async {
    if (!supported) return true;
    if (!_ready) return false;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> isEnabled() async {
    if (!supported) return true;
    if (!_ready) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  /// Membuka pengaturan notifikasi aplikasi di sistem Android.
  Future<void> openSettings() async {
    if (!supported || !_ready) return;
    await _android?.openAppNotificationSettings();
  }

  @override
  Future<void> sync(List<WorkoutSchedule> schedules) async {
    if (!supported || !_ready) return;
    final planned = ReminderPlanner.upcoming(
      schedules,
      DateTime.now().toUtc(),
    ).take(_maxScheduled);

    // Sederhana dan aman: hapus semua alarm lama, pasang ulang yang terbaru.
    await _plugin.cancelAll();
    for (final r in planned) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.fireAtUtc, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}