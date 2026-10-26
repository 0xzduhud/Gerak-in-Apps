import '../../data/models/notification_model.dart';
import '../../data/models/schedule_model.dart';
import 'timezone_converter.dart';

/// Satu alarm yang akan dibunyikan sistem di masa depan.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.fireAtUtc,
    required this.title,
    required this.body,
  });

  final int id; // = id jadwal
  final DateTime fireAtUtc;
  final String title;
  final String body;
}

// ============================================================================
// [PBI-13.x] ReminderPlanner — logika murni pengingat jadwal (mudah diuji)
// ============================================================================
class ReminderPlanner {
  ReminderPlanner._();

  static const int defaultLeadMinutes = 30;
  static const Duration maxAge = Duration(hours: 24);

  static DateTime reminderTimeUtc(
    WorkoutSchedule s, {
    int leadMinutes = defaultLeadMinutes,
  }) =>
      s.startUtc.subtract(Duration(minutes: leadMinutes));

  /// ID stabil: berubah jika jam jadwal diubah, sehingga pengingat baru dibuat.
  static String notificationId(WorkoutSchedule s) =>
      'schedule:${s.id}:${s.startUtc.toIso8601String()}';

  static String _title(WorkoutSchedule s) => 'Pengingat: ${s.title}';

  static String _body(WorkoutSchedule s) =>
      'Mulai pukul ${TimezoneConverter.formatTime(s.startAt)} '
      '${s.zone.code} • ${s.durationMinutes} menit';

  /// [Tahap A] Pengingat dalam aplikasi yang sudah jatuh tempo.
  static List<AppNotification> due(
    List<WorkoutSchedule> schedules,
    DateTime nowUtc, {
    int leadMinutes = defaultLeadMinutes,
  }) {
    final now = nowUtc.toUtc();
    final result = <AppNotification>[];
    for (final s in schedules) {
      if (s.id == null || s.done) continue;
      final remindAt = reminderTimeUtc(s, leadMinutes: leadMinutes);
      if (remindAt.isAfter(now)) continue;
      if (s.startUtc.isBefore(now.subtract(maxAge))) continue;
      result.add(
        AppNotification(
          id: notificationId(s),
          title: _title(s),
          body: _body(s),
          createdAt: remindAt,
        ),
      );
    }
    return result;
  }

  /// [Tahap B] Alarm sistem untuk waktu pengingat yang MASIH di masa depan,
  /// urut dari yang paling dekat. Jadwal yang pengingatnya sudah lewat tidak
  /// dibunyikan sistem (sudah ditangani pusat notifikasi dalam aplikasi).
  static List<PlannedReminder> upcoming(
    List<WorkoutSchedule> schedules,
    DateTime nowUtc, {
    int leadMinutes = defaultLeadMinutes,
  }) {
    final now = nowUtc.toUtc();
    final result = <PlannedReminder>[];
    for (final s in schedules) {
      if (s.id == null || s.done) continue;
      final remindAt = reminderTimeUtc(s, leadMinutes: leadMinutes);
      if (!remindAt.isAfter(now)) continue;
      result.add(
        PlannedReminder(
          id: s.id!,
          fireAtUtc: remindAt,
          title: _title(s),
          body: _body(s),
        ),
      );
    }
    result.sort((a, b) => a.fireAtUtc.compareTo(b.fireAtUtc));
    return result;
  }
}