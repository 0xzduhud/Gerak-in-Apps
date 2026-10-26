import 'package:flutter/foundation.dart';

import '../../core/services/notification_service.dart';
import '../../core/utils/timezone_converter.dart';
import '../../data/models/schedule_model.dart';
import '../../data/repositories/schedule_repository.dart';

// [PBI-12.x] ScheduleProvider — daftar jadwal + zona waktu tampilan.
// [PBI-13B] Setiap perubahan jadwal menyamakan alarm notifikasi sistem.
class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider({
    ScheduleRepository? repository,
    ReminderScheduler? scheduler,
  })  : _repo = repository ?? ScheduleRepository(),
        _scheduler = scheduler ?? NotificationService.instance;

  final ScheduleRepository _repo;
  final ReminderScheduler _scheduler;

  List<WorkoutSchedule> _items = [];
  AppTimeZone _displayZone = TimezoneConverter.wib;
  bool _loading = true;
  String? _error;
  bool _notificationsEnabled = true;
  bool _disposed = false;

  List<WorkoutSchedule> get items => _items;
  AppTimeZone get displayZone => _displayZone;
  bool get loading => _loading;
  String? get error => _error;

  /// false = pengguna mematikan izin notifikasi (tampilkan peringatan).
  bool get notificationsEnabled => _notificationsEnabled;

  void setDisplayZone(AppTimeZone zone) {
    _displayZone = zone;
    _notify();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _items = await _repo.all();
    } catch (e) {
      debugPrint('Gagal memuat jadwal: $e');
      _error = 'Jadwal belum bisa dimuat.';
    }
    _loading = false;
    _notify();
    await _syncReminders(askPermission: false);
  }

  String? lastSaveError;

  /// true jika berhasil. Pesan gagal ada di [lastSaveError].
  Future<bool> save(
    WorkoutSchedule schedule, {
    bool askPermission = true,
  }) async {
    lastSaveError = schedule.validate();
    if (lastSaveError != null) return false;
    try {
      await _repo.save(schedule);
      _items = await _repo.all();
      _notify();
    } catch (e) {
      debugPrint('Gagal menyimpan jadwal: $e');
      lastSaveError = 'Jadwal gagal disimpan.';
      return false;
    }
    await _syncReminders(askPermission: askPermission);
    return true;
  }

  Future<void> delete(WorkoutSchedule schedule) async {
    if (schedule.id == null) return;
    try {
      await _repo.delete(schedule.id!);
      _items = await _repo.all();
    } catch (e) {
      debugPrint('Gagal menghapus jadwal: $e');
    }
    _notify();
    await _syncReminders(askPermission: false);
  }

  Future<void> toggleDone(WorkoutSchedule schedule) async {
    await save(schedule.copyWith(done: !schedule.done), askPermission: false);
  }

  /// Kegagalan notifikasi tidak boleh menggagalkan penyimpanan jadwal.
  Future<void> _syncReminders({required bool askPermission}) async {
    try {
      if (askPermission) await _scheduler.ensurePermission();
      _notificationsEnabled = await _scheduler.isEnabled();
      await _scheduler.sync(_items);
    } catch (e) {
      debugPrint('Gagal menyamakan pengingat: $e');
    }
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