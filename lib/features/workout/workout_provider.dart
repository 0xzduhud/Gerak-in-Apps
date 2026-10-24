import 'package:flutter/foundation.dart';

import 'dart:async';

import '../../data/models/activity_model.dart';
import '../../data/models/sport_model.dart';
import '../../data/repositories/sport_repository.dart';
import 'services/step_detector.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) => SportFilter(
    query: query ?? this.query,
    category: clearCategory ? null : (category ?? this.category),
    difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
  );

  List<Sport> apply(List<Sport> source) {
    final q = query.trim().toLowerCase();
    return source.where((s) {
      final matchQuery =
          q.isEmpty ||
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

// ============================================================================
// [PBI-7.5] SharedPrefsWorkoutPlanStore — penyimpanan pilihan sesi yang tahan
// restart aplikasi. Digabung di file ini; dipasang dari WorkoutListScreen
// (default WorkoutProvider tetap InMemory supaya tes lama tidak berubah).
// ============================================================================
class SharedPrefsWorkoutPlanStore implements WorkoutPlanStore {
  SharedPrefsWorkoutPlanStore({required SportRepository repository})
      : _repository = repository;

  static const _key = 'last_workout_plan';

  final SportRepository _repository;

  @override
  Future<void> save(WorkoutPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'sport_id': plan.sport.id,
        'target_type': plan.targetType.name,
        'target_value': plan.targetValue,
        'duration_minutes': plan.durationMinutes,
        'created_at': plan.createdAt.toIso8601String(),
      }),
    );
  }

  @override
  Future<WorkoutPlan?> loadLast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final sports = await _repository.loadAll();
      final sport = sports.where((s) => s.id == json['sport_id']).firstOrNull;
      if (sport == null) return null;

      return WorkoutPlan(
        sport: sport,
        targetType:
            TargetType.values.asNameMap()[json['target_type']] ??
            TargetType.bebas,
        targetValue: json['target_value'] as int,
        durationMinutes: json['duration_minutes'] as int,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
    } catch (_) {
      // Data tersimpan rusak: abaikan, jangan crash.
      return null;
    }
  }
}
// ===================== AKHIR [PBI-7.5] SharedPrefsWorkoutPlanStore ==========

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
    await _restoreLastPlan();
    _loading = false;
    notifyListeners();
  }

  /// Mengembalikan pilihan sesi terakhir (PBI-7.5).
  Future<void> _restoreLastPlan() async {
    try {
      final plan = await _store.loadLast();
      if (plan == null) return;
      _selected = plan.sport;
      _targetType = plan.targetType;
      _targetValue = plan.targetValue;
      _duration = plan.durationMinutes;
    } catch (_) {
      // Gagal memulihkan tidak boleh menghalangi daftar olahraga tampil.
    }
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

enum SessionState { idle, running, paused, finished }

/// State sesi aktivitas: mulai, jeda, lanjut, selesai, hitung langkah.
/// Sumber sampel sensor disuntikkan (PBI-8.1 menyambungkan sensors_plus),
/// sehingga logika ini bisa dites tanpa HP.
class WorkoutSessionProvider extends ChangeNotifier {
  WorkoutSessionProvider({
    StepDetector? detector,
    this.body = const UserBody(),
    DateTime Function()? now,
  }) : _detector = detector ?? StepDetector(),
       _now = now ?? DateTime.now;

  final StepDetector _detector;
  final UserBody body;
  final DateTime Function() _now;

  SessionState _state = SessionState.idle;
  DateTime? _startedAt;
  DateTime? _resumedAt;
  Duration _accumulated = Duration.zero;
  String? _sportId;
  ActivitySummary? _summary;
  StreamSubscription<AccelSample>? _subscription;
  Timer? _ticker;

  SessionState get state => _state;
  ActivitySummary? get summary => _summary;
  int get steps => _detector.steps;
  double get distanceMeters => ActivityMetrics.distanceMeters(steps, body);
  double get calories => ActivityMetrics.calories(distanceMeters, body);

  Duration get elapsed {
    final resumedAt = _resumedAt;
    if (_state == SessionState.running && resumedAt != null) {
      return _accumulated + _now().difference(resumedAt);
    }
    return _accumulated;
  }

  void start({Stream<AccelSample>? samples, String? sportId}) {
    if (_state == SessionState.running || _state == SessionState.paused) {
      return;
    }
    _detector.reset();
    _accumulated = Duration.zero;
    _summary = null;
    _sportId = sportId;
    _startedAt = _now();
    _resumedAt = _startedAt;
    _state = SessionState.running;
    _subscription?.cancel();
    _subscription = samples?.listen(addSample);
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (_state != SessionState.running) return;
    _freezeElapsed();
    _stopTicker();
    _state = SessionState.paused;
    notifyListeners();
  }

  void resume() {
    if (_state != SessionState.paused) return;
    _resumedAt = _now();
    _state = SessionState.running;
    _startTicker();
    notifyListeners();
  }

  ActivitySummary? finish() {
    if (_state != SessionState.running && _state != SessionState.paused) {
      return _summary;
    }
    _freezeElapsed();
    _stopTicker();
    _subscription?.cancel();
    _subscription = null;
    _state = SessionState.finished;
    final result = ActivitySummary(
      startedAt: _startedAt ?? _now(),
      durationSeconds: _accumulated.inSeconds,
      steps: steps,
      distanceMeters: distanceMeters,
      calories: calories,
      sportId: _sportId,
    );
    _summary = result;
    notifyListeners();
    return result;
  }

  void reset() {
    _stopTicker();
    _subscription?.cancel();
    _subscription = null;
    _detector.reset();
    _state = SessionState.idle;
    _accumulated = Duration.zero;
    _resumedAt = null;
    _startedAt = null;
    _summary = null;
    notifyListeners();
  }

  /// Sampel hanya diproses saat sesi berjalan (diabaikan saat jeda).
  void addSample(AccelSample sample) {
    if (_state != SessionState.running) return;
    if (_detector.addSample(sample) > 0) notifyListeners();
  }

  void _freezeElapsed() {
    final resumedAt = _resumedAt;
    if (resumedAt != null) {
      _accumulated += _now().difference(resumedAt);
      _resumedAt = null;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    _subscription?.cancel();
    super.dispose();
  }
}
