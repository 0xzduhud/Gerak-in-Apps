import '../../data/models/sport_model.dart';
import 'services/motion_detector.dart';

/// Jenis tampilan sesi untuk satu olahraga.
enum SessionKind {
  /// Kardio berjarak: waktu, langkah, jarak, kalori.
  distance,

  /// Set demi set dengan hitungan repetisi.
  reps,

  /// Set demi set dengan hitung mundur.
  timed,
}

// ============================================================================
// [PBI-7.x] SessionSpec — pengaturan sesi yang diturunkan dari data olahraga.
// Logika murni (tanpa Flutter) agar mudah diuji.
// ============================================================================
class SessionSpec {
  const SessionSpec({
    required this.kind,
    required this.sets,
    required this.restSeconds,
    this.targetReps,
    this.targetSeconds,
    this.motion,
    this.perSide = false,
  });

  static const int maxSets = 10;
  static const int maxReps = 100;
  static const int minSeconds = 10;
  static const int maxSeconds = 300;
  static const int minRest = 15;
  static const int maxRest = 300;

  final SessionKind kind;
  final int sets;
  final int restSeconds;
  final int? targetReps; // jenis reps
  final int? targetSeconds; // jenis timed
  final MotionType? motion; // != null: repetisi dihitung sensor
  final bool perSide; // "per sisi": target berlaku untuk tiap sisi

  bool get autoCount => motion != null;

  /// Aturan membaca teks `reps` pada data olahraga:
  /// - memuat "menit"  -> kardio (jarak)
  /// - memuat "detik"  -> berwaktu, angka pertama = durasi per set
  /// - selain itu      -> repetisi, angka terakhir = target per set
  factory SessionSpec.fromSport(Sport sport) {
    final text = sport.reps.toLowerCase();
    final numbers = RegExp(r'\d+')
        .allMatches(text)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    final sets = sport.sets.clamp(1, maxSets);
    final motion = MotionType.fromSportId(sport.id);

    if (text.contains('menit')) {
      return const SessionSpec(
        kind: SessionKind.distance,
        sets: 1,
        restSeconds: 0,
      );
    }
    if (text.contains('detik')) {
      final seconds = numbers.isEmpty ? 30 : numbers.first;
      return SessionSpec(
        kind: SessionKind.timed,
        sets: sets,
        restSeconds: 30,
        targetSeconds: seconds.clamp(minSeconds, maxSeconds),
        motion: motion,
      );
    }
    final target = numbers.isEmpty ? 10 : numbers.last;
    return SessionSpec(
      kind: SessionKind.reps,
      sets: sets,
      restSeconds: 60,
      targetReps: target.clamp(1, maxReps),
      motion: motion,
      perSide: text.contains('per sisi'),
    );
  }

  SessionSpec copyWith({
    int? sets,
    int? targetReps,
    int? targetSeconds,
    int? restSeconds,
  }) =>
      SessionSpec(
        kind: kind,
        sets: (sets ?? this.sets).clamp(1, maxSets),
        restSeconds: (restSeconds ?? this.restSeconds).clamp(minRest, maxRest),
        targetReps: targetReps == null
            ? this.targetReps
            : targetReps.clamp(1, maxReps),
        targetSeconds: targetSeconds == null
            ? this.targetSeconds
            : targetSeconds.clamp(minSeconds, maxSeconds),
        motion: motion,
        perSide: perSide,
      );
}