// ============================================================================
// [PBI-13.x] AppNotification — satu entri di pusat notifikasi dalam aplikasi
// `id` unik dan stabil (dipakai untuk mencegah pengingat dobel).
// `hidden` = sudah dihapus pengguna; tetap disimpan agar tidak muncul lagi.
// ============================================================================
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.kind = kindSchedule,
    this.read = false,
    this.hidden = false,
  });

  static const String kindSchedule = 'schedule';
  static const String kindSystem = 'system';

  final String id;
  final String title;
  final String body;
  final DateTime createdAt; // UTC
  final String kind;
  final bool read;
  final bool hidden;

  AppNotification copyWith({bool? read, bool? hidden}) => AppNotification(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        kind: kind,
        read: read ?? this.read,
        hidden: hidden ?? this.hidden,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'created_at': createdAt.toUtc().toIso8601String(),
        'kind': kind,
        'read': read,
        'hidden': hidden,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['created_at']?.toString() ?? '');
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: (parsed ?? DateTime.now()).toUtc(),
      kind: json['kind']?.toString() ?? kindSchedule,
      read: json['read'] == true,
      hidden: json['hidden'] == true,
    );
  }
}