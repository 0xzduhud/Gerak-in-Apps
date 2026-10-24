import 'package:flutter/foundation.dart';

import '../../data/models/target_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/target_repository.dart';

// [PBI-10.3] ProgressProvider — memuat target + total aktivitas hari ini,
// lalu menghitung pencapaiannya.
class ProgressProvider extends ChangeNotifier {
  ProgressProvider({
    TargetRepository? targets,
    ActivityRepository? activities,
    DateTime Function()? now,
  })  : _targets = targets ?? TargetRepository(),
        _activities = activities ?? ActivityRepository(),
        _now = now ?? DateTime.now;

  final TargetRepository _targets;
  final ActivityRepository _activities;
  final DateTime Function() _now;

  DailyTarget _target = const DailyTarget();
  DailyTotals _today = DailyTotals.empty;
  bool _loading = true;
  String? _error;
  bool _disposed = false;

  DailyTarget get target => _target;
  DailyTotals get today => _today;
  bool get loading => _loading;
  String? get error => _error;

  TargetProgress get progress => TargetProgress.from(_target, _today);

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _target = await _targets.load();
      _today = await _activities.totalsForDay(_now());
    } catch (e) {
      debugPrint('Gagal memuat progress: $e');
      _error = 'Data progres belum bisa dimuat.';
    }
    _loading = false;
    _notify();
  }

  /// Mengembalikan true jika berhasil disimpan.
  Future<bool> saveTarget(DailyTarget target) async {
    try {
      _target = await _targets.save(target);
      _notify();
      return true;
    } catch (e) {
      debugPrint('Gagal menyimpan target: $e');
      return false;
    }
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