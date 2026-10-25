import 'package:flutter/foundation.dart';

import '../../core/utils/timezone_converter.dart';
import '../../data/models/schedule_model.dart';
import '../../data/repositories/schedule_repository.dart';

// [PBI-12.x] ScheduleProvider — daftar jadwal + zona waktu tampilan.
class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider({ScheduleRepository? repository})
      : _repo = repository ?? ScheduleRepository();

  final ScheduleRepository _repo;

  List<WorkoutSchedule> _items = [];
  AppTimeZone _displayZone = TimezoneConverter.wib;
  bool _loading = true;
  String? _error;
  bool _disposed = false;

  List<WorkoutSchedule> get items => _items;
  AppTimeZone get displayZone => _displayZone;
  bool get loading => _loading;
  String? get error => _error;

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
  }

  /// true jika berhasil. Pesan gagal ada di [lastSaveError].
  String? lastSaveError;

  Future<bool> save(WorkoutSchedule schedule) async {
    lastSaveError = schedule.validate();
    if (lastSaveError != null) return false;
    try {
      await _repo.save(schedule);
      _items = await _repo.all();
      _notify();
      return true;
    } catch (e) {
      debugPrint('Gagal menyimpan jadwal: $e');
      lastSaveError = 'Jadwal gagal disimpan.';
      return false;
    }
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
  }

  Future<void> toggleDone(WorkoutSchedule schedule) async {
    await save(schedule.copyWith(done: !schedule.done));
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