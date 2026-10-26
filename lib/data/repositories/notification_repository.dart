import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_model.dart';

// ============================================================================
// [PBI-13.x] NotificationStore — penyimpanan daftar notifikasi
// Memakai shared_preferences di semua platform (daftar kecil, maks 200).
// ============================================================================
abstract class NotificationStore {
  Future<List<AppNotification>> load();
  Future<void> save(List<AppNotification> items);
}

class PrefsNotificationStore implements NotificationStore {
  static const String _key = 'notifications_v1';

  @override
  Future<List<AppNotification>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) =>
              AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((n) => n.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<AppNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((n) => n.toJson()).toList()),
    );
  }
}

class NotificationRepository {
  NotificationRepository({NotificationStore? store})
      : _store = store ?? PrefsNotificationStore();

  static const int maxItems = 200;

  final NotificationStore _store;

  /// Yang terlihat pengguna (tanpa yang sudah dihapus), terbaru di atas.
  Future<List<AppNotification>> all() async {
    final list = (await _store.load()).where((n) => !n.hidden).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Menambah hanya yang `id`-nya belum pernah ada (termasuk yang sudah
  /// dihapus). Mengembalikan jumlah yang benar-benar ditambahkan.
  Future<int> addNew(List<AppNotification> incoming) async {
    if (incoming.isEmpty) return 0;
    final current = await _store.load();
    final known = current.map((n) => n.id).toSet();
    var added = 0;
    for (final n in incoming) {
      if (known.add(n.id)) {
        current.add(n);
        added++;
      }
    }
    if (added == 0) return 0;
    current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _store.save(current.take(maxItems).toList());
    return added;
  }

  Future<void> markRead(String id) =>
      _update((n) => n.id == id ? n.copyWith(read: true) : n);

  Future<void> markAllRead() => _update((n) => n.copyWith(read: true));

  /// "Hapus" = disembunyikan, supaya pengingat yang sama tidak dibuat lagi.
  Future<void> delete(String id) =>
      _update((n) => n.id == id ? n.copyWith(hidden: true) : n);

  Future<void> clearAll() => _update((n) => n.copyWith(hidden: true));

    /// Menyembunyikan notifikasi jadwal yang sudah tidak berlaku (jadwal diubah
  /// jamnya, dihapus, atau sudah selesai). [validIds] = ID pengingat yang
  /// masih sah saat ini.
  Future<void> pruneSchedule(Set<String> validIds) async {
    final current = await _store.load();
    var changed = false;
    final next = current.map((n) {
      if (n.kind == AppNotification.kindSchedule &&
          !n.hidden &&
          !validIds.contains(n.id)) {
        changed = true;
        return n.copyWith(hidden: true);
      }
      return n;
    }).toList();
    if (changed) await _store.save(next);
  }

  Future<void> _update(AppNotification Function(AppNotification) f) async {
    final current = await _store.load();
    await _store.save(current.map(f).toList());
  }
}