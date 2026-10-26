import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mengonversi created_at menjadi waktu relatif.
String formatTimeAgo(String timestamp) {
  if (timestamp.isEmpty) return 'Baru saja';

  try {
    final date = DateTime.parse(timestamp).toLocal();
    final diff = DateTime.now().difference(date);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari yang lalu';
    if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} minggu yang lalu';
    }
    if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} bulan yang lalu';
    }

    return '${(diff.inDays / 365).floor()} tahun yang lalu';
  } catch (_) {
    return 'Baru saja';
  }
}

class CommunityProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> posts = [];
  List<String> following = [];

  bool isLoading = false;
  String searchQuery = '';

  String? _cachedProfileId;
  String? _cachedAuthUserId;

  /// ID profil public.users, bukan ID Supabase Auth.
  String? get currentProfileId => _cachedProfileId;

  /// Dipertahankan untuk kompatibilitas dengan UI lama.
  String? get currentUserId =>
      _cachedProfileId ?? _supabase.auth.currentUser?.id;

  String? get currentAuthUserId => _supabase.auth.currentUser?.id;

  List<Map<String, dynamic>> get filteredPosts {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) return posts;

    return posts.where((post) {
      final content = (post['content']?.toString() ?? '').toLowerCase();
      final username = (post['username']?.toString() ?? '').toLowerCase();
      final fullName = (post['full_name']?.toString() ?? '').toLowerCase();

      return content.contains(query) ||
          username.contains(query) ||
          fullName.contains(query);
    }).toList();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  /// Mengambil ID profil public.users berdasarkan akun Auth aktif.
  Future<String> getCurrentProfileId() async {
    final authUser = _supabase.auth.currentUser;

    if (authUser == null) {
      _cachedProfileId = null;
      _cachedAuthUserId = null;
      throw Exception('Silakan login terlebih dahulu.');
    }

    // Cache hanya digunakan jika akun Auth masih sama.
    if (_cachedProfileId != null && _cachedAuthUserId == authUser.id) {
      return _cachedProfileId!;
    }

    final profile = await _supabase
        .from('users')
        .select('id')
        .eq('auth_user_id', authUser.id)
        .maybeSingle();

    if (profile == null || profile['id'] == null) {
      _cachedProfileId = null;
      _cachedAuthUserId = null;

      throw Exception(
        'Profil belum terhubung dengan akun login. '
        'Pastikan users.auth_user_id sesuai dengan ID akun Supabase Auth.',
      );
    }

    _cachedProfileId = profile['id'].toString();
    _cachedAuthUserId = authUser.id;

    debugPrint('Community: Auth ID = ${authUser.id}');
    debugPrint('Community: Profile ID = $_cachedProfileId');

    return _cachedProfileId!;
  }

  String get currentUsername {
    final user = _supabase.auth.currentUser;

    if (user == null) return 'Saya';

    final metadataUsername = user.userMetadata?['username']?.toString();

    if (metadataUsername != null && metadataUsername.trim().isNotEmpty) {
      return metadataUsername;
    }

    final email = user.email;

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Saya';
  }

  String? get currentUserAvatar {
    return _supabase.auth.currentUser?.userMetadata?['avatar_url']?.toString();
  }

  /// Mengambil postingan dan status interaksi dari Supabase.
  Future<void> fetchPosts() async {
    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    try {
      String? profileId;

      if (_supabase.auth.currentUser != null) {
        profileId = await getCurrentProfileId();
      } else {
        _cachedProfileId = null;
        _cachedAuthUserId = null;
      }

      final response = await _supabase
          .from('posts')
          .select(
            '*, '
            'users!posts_user_id_fkey('
            'full_name, username, photo_url, auth_user_id'
            '), '
            'post_likes(user_id), '
            'post_comments(id, post_id, user_id, content, created_at)',
          )
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final rawPosts = List<Map<String, dynamic>>.from(
        (response as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      // Kumpulkan ID profil penulis komentar.
      final commentUserIds = <String>{};

      for (final post in rawPosts) {
        final comments = (post['post_comments'] as List<dynamic>?) ?? [];

        for (final item in comments) {
          if (item is Map && item['user_id'] != null) {
            commentUserIds.add(item['user_id'].toString());
          }
        }
      }

      // Ambil informasi profil penulis komentar.
      final profileNames = <String, Map<String, dynamic>>{};

      if (commentUserIds.isNotEmpty) {
        final userResponse = await _supabase
            .from('users')
            .select('id, full_name, username, photo_url')
            .inFilter('id', commentUserIds.toList());

        for (final item in userResponse as List) {
          final user = Map<String, dynamic>.from(item as Map);
          final id = user['id']?.toString();

          if (id != null) {
            profileNames[id] = user;
          }
        }
      }

      final parsedPosts = <Map<String, dynamic>>[];

      for (final map in rawPosts) {
        final likes = (map['post_likes'] as List<dynamic>?) ?? [];
        final comments = (map['post_comments'] as List<dynamic>?) ?? [];

        final postUserId = map['user_id']?.toString() ?? '';
        final userRelation = map['users'];

        String username = 'Pengguna';
        String fullName = '';
        String? avatarUrl;
        String? postAuthUserId;

        if (userRelation is Map) {
          final name = userRelation['username']?.toString();
          final fullNameValue = userRelation['full_name']?.toString();

          if (name != null && name.trim().isNotEmpty) {
            username = name;
          }

          if (fullNameValue != null && fullNameValue.trim().isNotEmpty) {
            fullName = fullNameValue.trim();
          }

          avatarUrl = userRelation['photo_url']?.toString();
          postAuthUserId = userRelation['auth_user_id']?.toString();
        }

        // Pertahankan username untuk kompatibilitas UI lama.
        // Nama lengkap disimpan terpisah untuk tampilan card.
        if (profileId != null && postUserId == profileId) {
          avatarUrl ??= currentUserAvatar;
        }

        final parsedComments = comments.map((item) {
          final comment = Map<String, dynamic>.from(item as Map);
          final commentUserId = comment['user_id']?.toString() ?? '';
          final commentProfile = profileNames[commentUserId];

          String commentUsername =
              commentProfile?['username']?.toString() ?? 'Pengguna';

          if (profileId != null && commentUserId == profileId) {
            commentUsername = currentUsername;
          }

          return <String, dynamic>{
            'id': comment['id']?.toString() ?? '',
            'user_id': commentUserId,
            'username': commentUsername,
            'full_name': commentProfile?['full_name']?.toString() ?? '',
            'avatar_url': commentProfile?['photo_url']?.toString(),
            'comment': comment['content']?.toString() ?? '',
            'created_at': comment['created_at']?.toString(),
          };
        }).toList();

        final isLiked =
            profileId != null &&
            likes.any(
              (like) => like is Map && like['user_id']?.toString() == profileId,
            );

        final createdAt = map['created_at']?.toString() ?? '';

        parsedPosts.add(<String, dynamic>{
          'id': map['id']?.toString() ?? '',
          'user_id': postUserId,
          'auth_user_id': postAuthUserId,
          'username': username,
          'full_name': fullName,
          'avatar_url': avatarUrl,
          'content': map['content']?.toString() ?? '',
          'image_url': map['image_url']?.toString(),
          'created_at': createdAt,
          'time': formatTimeAgo(createdAt),
          'likesCount': likes.length,
          'isLiked': isLiked,
          'comments': parsedComments,
        });
      }

      posts = parsedPosts;

      // Muat status follow menggunakan ID Auth.
      // Daftar following tetap berisi ID profil untuk kebutuhan UI.
      following = [];

      final authUserId = _supabase.auth.currentUser?.id;

      if (authUserId != null) {
        final followResponse = await _supabase
            .from('user_follows')
            .select('following_id')
            .eq('followers_id', authUserId);

        final followedAuthIds = (followResponse as List)
            .map((item) => item['following_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        if (followedAuthIds.isNotEmpty) {
          final followedProfiles = await _supabase
              .from('users')
              .select('id, auth_user_id')
              .inFilter('auth_user_id', followedAuthIds);

          following = (followedProfiles as List)
              .map((item) => item['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetchPosts Community: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Menambahkan postingan ke Supabase menggunakan ID profil.
  Future<void> addPost(String content, {String? imageUrl}) async {
    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) {
      throw Exception('Isi postingan tidak boleh kosong.');
    }

    final profileId = await getCurrentProfileId();

    final payload = <String, dynamic>{
      'user_id': profileId,
      'content': trimmedContent,
    };

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      payload['image_url'] = imageUrl.trim();
    }

    await _supabase.from('posts').insert(payload);

    try {
      await fetchPosts();
    } catch (e) {
      debugPrint('Postingan berhasil disimpan, tetapi feed gagal dimuat: $e');
    }
  }

  /// Memperbarui postingan milik pengguna yang sedang login.
  Future<void> updatePost(
    String postId,
    String newContent, {
    String? newImageUrl,
  }) async {
    if (newContent.trim().isEmpty) {
      throw Exception('Postingan tidak boleh kosong.');
    }

    final profileId = await getCurrentProfileId();

    final payload = <String, dynamic>{'content': newContent.trim()};

    if (newImageUrl != null) {
      payload['image_url'] = newImageUrl;
    }

    final result = await _supabase
        .from('posts')
        .update(payload)
        .eq('id', postId)
        .eq('user_id', profileId)
        .select('id');

    if ((result as List).isEmpty) {
      throw Exception('Postingan tidak ditemukan atau kamu bukan pemiliknya.');
    }

    await fetchPosts();
  }

  /// Menghapus postingan milik pengguna yang sedang login.
  Future<void> deletePost(String postId) async {
    final profileId = await getCurrentProfileId();

    final result = await _supabase
        .from('posts')
        .delete()
        .eq('id', postId)
        .eq('user_id', profileId)
        .select('id');

    if ((result as List).isEmpty) {
      throw Exception('Postingan tidak ditemukan atau tidak dapat dihapus.');
    }

    posts.removeWhere((post) => post['id']?.toString() == postId);
    notifyListeners();
  }

  /// Like/unlike menggunakan ID profil.
  Future<void> toggleLike(String postId) async {
    final index = posts.indexWhere((post) => post['id']?.toString() == postId);

    if (index == -1) {
      throw Exception('Postingan tidak ditemukan.');
    }

    final profileId = await getCurrentProfileId();

    final existing = await _supabase
        .from('post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', profileId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', profileId);
    } else {
      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': profileId,
      });
    }

    final likeRows = await _supabase
        .from('post_likes')
        .select('user_id')
        .eq('post_id', postId);

    final isLikedNow = (likeRows as List).any(
      (row) => row['user_id']?.toString() == profileId,
    );

    final currentIndex = posts.indexWhere(
      (post) => post['id']?.toString() == postId,
    );

    if (currentIndex != -1) {
      posts[currentIndex]['isLiked'] = isLikedNow;
      posts[currentIndex]['likesCount'] = likeRows.length;
      notifyListeners();
    }
  }

  /// Menambahkan komentar menggunakan ID profil.
  Future<void> addComment(String postId, String comment) async {
    final trimmedComment = comment.trim();

    if (trimmedComment.isEmpty) {
      throw Exception('Komentar tidak boleh kosong.');
    }

    final index = posts.indexWhere((post) => post['id']?.toString() == postId);

    if (index == -1) {
      throw Exception('Postingan tidak ditemukan.');
    }

    final profileId = await getCurrentProfileId();

    final inserted = await _supabase
        .from('post_comments')
        .insert({
          'post_id': postId,
          'user_id': profileId,
          'content': trimmedComment,
        })
        .select('id, post_id, user_id, content, created_at')
        .single();

    final comments = posts[index]['comments'];

    if (comments is List) {
      comments.add(<String, dynamic>{
        'id': inserted['id']?.toString() ?? '',
        'user_id': profileId,
        'username': currentUsername,
        'full_name': '',
        'avatar_url': currentUserAvatar,
        'comment': inserted['content']?.toString() ?? trimmedComment,
        'created_at': inserted['created_at']?.toString(),
      });
    }

    notifyListeners();
  }

  /// Menghapus komentar milik pengguna yang sedang login.
  Future<void> deleteComment(String commentId) async {
    final profileId = await getCurrentProfileId();

    final result = await _supabase
        .from('post_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', profileId)
        .select('id');

    if ((result as List).isEmpty) {
      throw Exception('Komentar tidak ditemukan atau kamu bukan pemiliknya.');
    }

    for (final post in posts) {
      final comments = post['comments'];

      if (comments is List) {
        comments.removeWhere(
          (item) => item is Map && item['id']?.toString() == commentId,
        );
      }
    }

    notifyListeners();
  }

  /// Melaporkan postingan.
  Future<void> reportPost(String postId, String reason) async {
    if (reason.trim().isEmpty) {
      throw Exception('Alasan laporan tidak boleh kosong.');
    }

    final profileId = await getCurrentProfileId();

    await _supabase.from('post_reports').insert({
      'post_id': postId,
      'reporter_id': profileId,
      'reason': reason.trim(),
    });
  }

  /// Follow/unfollow.
  ///
  /// Parameter targetUserId adalah ID profil public.users.
  /// Tabel user_follows menyimpan ID Auth pada kedua kolomnya.
  Future<void> toggleFollow(String targetUserId) async {
    final profileId = await getCurrentProfileId();
    final authUserId = _supabase.auth.currentUser?.id;

    if (authUserId == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    if (targetUserId.isEmpty) {
      throw Exception('ID pengguna yang akan diikuti tidak valid.');
    }

    if (targetUserId == profileId) {
      throw Exception('Kamu tidak dapat mengikuti akun sendiri.');
    }

    // Cari akun Auth yang terhubung dengan profil target.
    final targetProfile = await _supabase
        .from('users')
        .select('id, auth_user_id')
        .eq('id', targetUserId)
        .maybeSingle();

    if (targetProfile == null) {
      throw Exception('Profil pengguna yang akan diikuti tidak ditemukan.');
    }

    final targetAuthId = targetProfile['auth_user_id']?.toString();

    if (targetAuthId == null || targetAuthId.isEmpty) {
      throw Exception(
        'Akun ini belum terhubung dengan Supabase Auth, '
        'sehingga belum dapat diikuti.',
      );
    }

    if (targetAuthId == authUserId) {
      throw Exception('Kamu tidak dapat mengikuti akun sendiri.');
    }

    final existing = await _supabase
        .from('user_follows')
        .select('followers_id')
        .eq('followers_id', authUserId)
        .eq('following_id', targetAuthId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('user_follows')
          .delete()
          .eq('followers_id', authUserId)
          .eq('following_id', targetAuthId);

      following.remove(targetUserId);
    } else {
      await _supabase.from('user_follows').insert({
        'followers_id': authUserId,
        'following_id': targetAuthId,
      });

      if (!following.contains(targetUserId)) {
        following.add(targetUserId);
      }
    }

    notifyListeners();
  }

  /// Memeriksa status follow berdasarkan ID profil target.
  bool isFollowing(String targetUserId) {
    return following.contains(targetUserId);
  }
}
