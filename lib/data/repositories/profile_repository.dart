import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error dengan pesan berbahasa Indonesia yang aman ditampilkan ke pengguna.
class ProfileException implements Exception {
  final String message;

  ProfileException(this.message);

  @override
  String toString() => message;
}

class UserProfile {
  final String username;
  final String email;
  final String? fullName;
  final String? photoUrl;

  const UserProfile({
    required this.username,
    required this.email,
    required this.fullName,
    required this.photoUrl,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    String? clean(dynamic value) {
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    }

    return UserProfile(
      username: clean(map['username']) ?? '',
      email: clean(map['email']) ?? '',
      fullName: clean(map['full_name']),
      photoUrl: clean(map['photo_url']),
    );
  }
}

class FollowCounts {
  final int followers;
  final int following;

  const FollowCounts({required this.followers, required this.following});
}

class ProfileOverview {
  final UserProfile profile;
  final FollowCounts counts;

  const ProfileOverview({required this.profile, required this.counts});
}

/// Pengguna di daftar followers atau following.
class FollowUser {
  final String username;
  final String? fullName;
  final String? photoUrl;

  const FollowUser({
    required this.username,
    required this.fullName,
    required this.photoUrl,
  });

  String get displayName =>
      (fullName != null && fullName!.isNotEmpty) ? fullName! : username;

  factory FollowUser.fromMap(Map<String, dynamic> map) {
    String? clean(dynamic value) {
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    }

    return FollowUser(
      username: clean(map['username']) ?? 'pengguna',
      fullName: clean(map['full_name']),
      photoUrl: clean(map['photo_url']),
    );
  }
}

class ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _bucket = 'avatars';
  static const int _maxPhotoBytes = 2 * 1024 * 1024;
  static const Duration _timeout = Duration(seconds: 20);
  static const Duration _uploadTimeout = Duration(seconds: 40);

  static const Map<String, String> _mimeByExtension = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// Profil terbaru beserta jumlah followers dan following.
  Future<ProfileOverview> fetchOverview() async {
    final data = await _call({'action': 'get'});
    final profile = data['profile'];

    if (profile is! Map) {
      throw ProfileException('Respons server tidak valid.');
    }

    return ProfileOverview(
      profile: UserProfile.fromMap(Map<String, dynamic>.from(profile)),
      counts: FollowCounts(
        followers: (data['followers_count'] as num?)?.toInt() ?? 0,
        following: (data['following_count'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Mengubah nama lengkap. Username tidak bisa diubah.
  Future<UserProfile> updateFullName(String fullName) async {
    final data = await _call({'action': 'update_name', 'full_name': fullName});
    return _profileFrom(data);
  }

  /// Mengunggah foto ke Storage lalu menyimpan alamatnya di profil.
  Future<UserProfile> updatePhoto(XFile file) async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      throw ProfileException('Sesi login berakhir. Silakan login kembali.');
    }

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw ProfileException('File foto kosong atau tidak bisa dibaca.');
    }
    if (bytes.length > _maxPhotoBytes) {
      throw ProfileException('Ukuran foto maksimal 2 MB.');
    }

    final extension = _detectExtension(bytes);
    if (extension == null) {
      throw ProfileException('Format foto harus JPG, PNG, atau WebP.');
    }

    final path =
        '${authUser.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

    try {
      await _supabase.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeByExtension[extension],
              upsert: false,
            ),
          )
          .timeout(_uploadTimeout);
    } on StorageException catch (error) {
      throw ProfileException(_storageMessage(error));
    } on TimeoutException {
      throw ProfileException('Unggah foto terlalu lama. Coba lagi.');
    } catch (_) {
      throw ProfileException(
        'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
      );
    }

    final data = await _call({'action': 'update_photo', 'path': path});
    return _profileFrom(data);
  }

  Future<UserProfile> removePhoto() async {
    final data = await _call({'action': 'remove_photo'});
    return _profileFrom(data);
  }

  /// Pengguna yang mengikuti saya.
  Future<List<FollowUser>> fetchFollowers() => _fetchUsers('list_followers');

  /// Pengguna yang saya ikuti.
  Future<List<FollowUser>> fetchFollowing() => _fetchUsers('list_following');

  Future<List<FollowUser>> _fetchUsers(String action) async {
    final data = await _call({'action': action});
    final items = data['items'];

    if (items is! List) return [];

    return items
        .whereType<Map>()
        .map((item) => FollowUser.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  UserProfile _profileFrom(Map<String, dynamic> data) {
    final profile = data['profile'];
    if (profile is! Map) {
      throw ProfileException('Respons server tidak valid.');
    }
    return UserProfile.fromMap(Map<String, dynamic>.from(profile));
  }

  /// Mengenali jenis gambar dari isi file, bukan dari nama file.
  String? _detectExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  String _storageMessage(StorageException error) {
    final code = error.statusCode?.toString();

    if (code == '401' || code == '403') {
      return 'Izin unggah foto ditolak. Pastikan bucket avatars sudah dibuat.';
    }
    if (code == '404') {
      return 'Tempat penyimpanan foto belum tersedia (bucket avatars).';
    }
    if (code == '413') {
      return 'Ukuran foto terlalu besar. Maksimal 2 MB.';
    }
    return 'Gagal mengunggah foto. Coba lagi.';
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    if (_supabase.auth.currentSession == null) {
      throw ProfileException('Sesi login berakhir. Silakan login kembali.');
    }

    try {
      final response = await _supabase.functions
          .invoke('profile', body: body)
          .timeout(_timeout);

      final data = response.data;
      if (data is Map && data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }

      throw ProfileException(
        _messageFrom(data) ?? 'Respons server tidak valid.',
      );
    } on ProfileException {
      rethrow;
    } on FunctionException catch (error) {
      throw ProfileException(
        _messageFrom(error.details) ??
            'Server sedang bermasalah (${error.status}). Coba lagi nanti.',
      );
    } on TimeoutException {
      throw ProfileException('Server terlalu lama merespons. Coba lagi.');
    } catch (_) {
      throw ProfileException(
        'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
      );
    }
  }

  String? _messageFrom(dynamic details) {
    if (details is Map && details['message'] is String) {
      final text = (details['message'] as String).trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
