import '../../core/utils/timezone_converter.dart';

// ============================================================================
// [PBI-12.x] WorkoutSchedule — satu jadwal latihan
// `startAt` = jam dinding di zona `zoneCode` (bukan UTC).
// ============================================================================
class WorkoutSchedule {
  const WorkoutSchedule({
    this.id,
    required this.title,
    required this.startAt,
    this.zoneCode = 'WIB',
    this.durationMinutes = 30,
    this.note = '',
    this.done = false,
  });

  static const int minDuration = 5;
  static const int maxDuration = 240;

  final int? id;
  final String title;
  final DateTime startAt;
  final String zoneCode;
  final int durationMinutes;
  final String note;
  final bool done;

  AppTimeZone get zone => TimezoneConverter.byCode(zoneCode);

  /// Instan absolut (dipakai Sprint 13 untuk menjadwalkan notifikasi).
  DateTime get startUtc => TimezoneConverter.toUtc(startAt, zone);

  WorkoutSchedule copyWith({
    int? id,
    String? title,
    DateTime? startAt,
    String? zoneCode,
    int? durationMinutes,
    String? note,
    bool? done,
  }) =>
      WorkoutSchedule(
        id: id ?? this.id,
        title: title ?? this.title,
        startAt: startAt ?? this.startAt,
        zoneCode: zoneCode ?? this.zoneCode,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        note: note ?? this.note,
        done: done ?? this.done,
      );

  /// Pesan error validasi, atau null jika data sudah benar.
  String? validate() {
    if (title.trim().isEmpty) return 'Judul jadwal wajib diisi.';
    if (durationMinutes < minDuration || durationMinutes > maxDuration) {
      return 'Durasi harus $minDuration–$maxDuration menit.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'start_at': _wall(startAt).toIso8601String(),
        'zone_code': zoneCode,
        'duration_minutes': durationMinutes,
        'note': note,
        'done': done ? 1 : 0,
      };

  factory WorkoutSchedule.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['start_at']?.toString() ?? '');
    return WorkoutSchedule(
      id: (json['id'] as num?)?.toInt(),
      title: json['title']?.toString() ?? '',
      startAt: parsed == null ? DateTime.now() : _wall(parsed),
      zoneCode: json['zone_code']?.toString() ?? 'WIB',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      note: json['note']?.toString() ?? '',
      done: json['done'] == 1 || json['done'] == true,
    );
  }

  /// Buang flag UTC/lokal agar string yang disimpan selalu tanpa "Z".
  static DateTime _wall(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);
}