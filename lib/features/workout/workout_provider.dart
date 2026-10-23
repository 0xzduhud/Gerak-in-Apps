import 'package:flutter/foundation.dart';

import '../../data/models/sport_model.dart';
import '../../data/repositories/sport_repository.dart';

/// Search + filter kategori/kesulitan (PBI-7.3).
class SportFilter {
  const SportFilter({this.query = '', this.category, this.difficulty});

  final String query;
  final String? category;
  final Difficulty? difficulty;

  bool get isActive =>
      query.trim().isNotEmpty || category != null || difficulty != null;

  SportFilter copyWith({
    String? query,
    String? category,
    Difficulty? difficulty,
    bool clearCategory = false,
    bool clearDifficulty = false,
  }) =>
      SportFilter(
        query: query ?? this.query,
        category: clearCategory ? null : (category ?? this.category),
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      );

  List<Sport> apply(List<Sport> source) {
    final q = query.trim().toLowerCase();
    return source.where((s) {
      final matchQuery = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q) ||
          s.equipment.toLowerCase().contains(q);
      final matchCategory = category == null || s.category == category;
      final matchDifficulty = difficulty == null || s.difficulty == difficulty;
      return matchQuery && matchCategory && matchDifficulty;
    }).toList();
  }
}

/// Validasi pilihan sesi (PBI-7.5).
class WorkoutPlanValidator {
  WorkoutPlanValidator._();

  static const int minDuration = 1;
  static const int maxDuration = 180;

  /// Mengembalikan pesan error, atau null jika valid.
  static String? validate({
    required Sport? sport,
    required TargetType targetType,
    required int targetValue,
    required int durationMinutes,
  }) {
    if (sport == null) return 'Pilih jenis olahraga terlebih dahulu.';
    if (durationMinutes < minDuration || durationMinutes > maxDuration) {
      return 'Durasi harus $minDuration-$maxDuration menit.';
    }
    if (targetType != TargetType.bebas && targetValue <= 0) {
      return 'Target harus lebih dari 0.';
    }
    if (targetType == TargetType.kalori && targetValue > 5000) {
      return 'Target kalori terlalu besar.';
    }
    if (targetType == TargetType.repetisi && targetValue > 1000) {
      return 'Target repetisi terlalu besar.';
    }
    return null;
  }
}

/// Interface penyimpanan, supaya nanti bisa disambung ke SQLite/API
/// (Sprint 4 / PBI-8.6) tanpa mengubah provider.
abstract class WorkoutPlanStore {
  Future<void> save(WorkoutPlan plan);
  Future<WorkoutPlan?> loadLast();
}

class InMemoryWorkoutPlanStore implements WorkoutPlanStore {
  WorkoutPlan? _last;

  @override
  Future<void> save(WorkoutPlan plan) async => _last = plan;

  @override
  Future<WorkoutPlan?> loadLast() async => _last;
}

class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider({SportRepository? repository, WorkoutPlanStore? store})
      : _repository = repository ?? SportRepository(),
        _store = store ?? InMemoryWorkoutPlanStore();

  final SportRepository _repository;
  final WorkoutPlanStore _store;

  List<Sport> _all = [];
  bool _loading = false;
  String? _loadError;

  SportFilter _filter = const SportFilter();
  Sport? _selected;
  TargetType _targetType = TargetType.bebas;
  int _targetValue = 0;
  int _duration = 30;
  String? _error;

  bool get loading => _loading;
  String? get loadError => _loadError;
  SportFilter get filter => _filter;
  List<Sport> get sports => _filter.apply(_all);
  List<String> get categories => _all.map((s) => s.category).toSet().toList();
  Sport? get selected => _selected;
  TargetType get targetType => _targetType;
  int get targetValue => _targetValue;
  int get duration => _duration;
  String? get error => _error;
  int get estimatedKcal => _selected?.estimateKcal(_duration) ?? 0;

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _all = await _repository.loadAll();
    } catch (e) {
      _loadError = 'Gagal memuat data olahraga: $e';
    }
    _loading = false;
    notifyListeners();
  }

  void setQuery(String value) {
    _filter = _filter.copyWith(query: value);
    notifyListeners();
  }

  void setCategory(String? value) {
    _filter = value == null
        ? _filter.copyWith(clearCategory: true)
        : _filter.copyWith(category: value);
    notifyListeners();
  }

  void setDifficulty(Difficulty? value) {
    _filter = value == null
        ? _filter.copyWith(clearDifficulty: true)
        : _filter.copyWith(difficulty: value);
    notifyListeners();
  }

  void resetFilter() {
    _filter = const SportFilter();
    notifyListeners();
  }

    void selectSport(Sport sport) {
    if (_selected?.id != sport.id) {
      // Form dikembalikan ke default saat berganti olahraga.
      _targetType = TargetType.bebas;
      _targetValue = 0;
      _duration = 30;
    }
    _selected = sport;
    _error = null;
    notifyListeners();
  }

  void setTargetType(TargetType type) {
    _targetType = type;
    if (type == TargetType.bebas) _targetValue = 0;
    notifyListeners();
  }

  void setTargetValue(int value) {
    _targetValue = value;
    notifyListeners();
  }

  void setDuration(int minutes) {
    _duration = minutes;
    notifyListeners();
  }

  /// Validasi lalu simpan. Mengembalikan true jika berhasil.
  Future<bool> savePlan() async {
    final err = WorkoutPlanValidator.validate(
      sport: _selected,
      targetType: _targetType,
      targetValue: _targetValue,
      durationMinutes: _duration,
    );
    _error = err;
    if (err != null) {
      notifyListeners();
      return false;
    }
    await _store.save(
      WorkoutPlan(
        sport: _selected!,
        targetType: _targetType,
        targetValue: _targetValue,
        durationMinutes: _duration,
      ),
    );
    notifyListeners();
    return true;
  }
}