import 'package:flutter/foundation.dart';

import '../../core/utils/reminder_planner.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/schedule_repository.dart';

// [PBI-13.x] NotificationProvider — membuat pengingat jatuh tempo lalu
// memuat daftar notifikasi.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    NotificationRepository? notifications,
    ScheduleRepository? schedules,
    DateTime Function()? now,
  })  : _repo = notifications ?? NotificationRepository(),
        _schedules = schedules ?? ScheduleRepository(),
        _now = now ?? DateTime.now;

  final NotificationRepository _repo;
  final ScheduleRepository _schedules;
  final DateTime Function() _now;

  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;
  bool _disposed = false;

  List<AppNotification> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.read).length;

    Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final schedules = await _schedules.all();
      // Buang pengingat lama milik jadwal yang diubah/dihapus/selesai.
      await _repo.pruneSchedule(
        schedules
            .where((s) => s.id != null && !s.done)
            .map(ReminderPlanner.notificationId)
            .toSet(),
      );
      await _repo.addNew(ReminderPlanner.due(schedules, _now().toUtc()));
      _items = await _repo.all();
    } catch (e) {
      debugPrint('Gagal memuat notifikasi: $e');
      _error = 'Notifikasi belum bisa dimuat.';
    }
    _loading = false;
    _notify();
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    await _repo.markRead(n.id);
    _items = await _repo.all();
    _notify();
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    _items = await _repo.all();
    _notify();
  }

  Future<void> delete(AppNotification n) async {
    await _repo.delete(n.id);
    _items = await _repo.all();
    _notify();
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    _items = await _repo.all();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}