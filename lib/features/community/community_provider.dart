import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fungsi helper untuk mengonversi data created_at (timestamp ISO string)
/// menjadi format waktu relatif (misal: "5m yang lalu", "2 jam yang lalu").
String formatTimeAgo(String timestamp) {
  if (timestamp.isEmpty) return 'Baru saja';
  try {
    final date = DateTime.parse(timestamp).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari yang lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu yang lalu';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} bulan yang lalu';
    return '${(diff.inDays / 365).floor()} tahun yang lalu';
  } catch (_) {
    return 'Baru saja';
  }
}

/// [CommunityProvider] - Pengelola state komunitas terintegrasi dengan Supabase.
class CommunityProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Daftar postingan di feed komunitas.
  List<Map<String, dynamic>> posts = [];

  /// Daftar user ID atau username yang di-follow oleh user saat ini.
  List<String> following = [];

  /// Status loading saat memuat data.
  bool isLoading = false;

  /// Kueri pencarian teks.
  String searchQuery = '';

  /// Getter postingan yang difilter berdasarkan teks konten atau username.
  List<Map<String, dynamic>> get filteredPosts {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return posts;
    return posts.where((post) {
      final content = (post['content']?.toString() ?? '').toLowerCase();
      final username = (post['username']?.toString() ?? '').toLowerCase();
      return content.contains(query) || username.contains(query);
    }).toList();
  }

  /// Mengubah kata kunci pencarian dan memberitahu listeners.
  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  /// ID pengguna saat ini dari Supabase Auth.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Username pengguna saat ini dari Supabase Auth metadata / email.
  String get currentUsername {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Saya';
    final metadataUsername = user.userMetadata?['username']?.toString();
    if (metadataUsername != null && metadataUsername.isNotEmpty) {
      return metadataUsername;
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Saya';
  }

  /// Avatar URL pengguna saat ini dari metadata Supabase Auth jika ada.
  String? get currentUserAvatar {
    final user = _supabase.auth.currentUser;
    return user?.userMetadata?['avatar_url']?.toString();
  }

  /// Data dummy awal sebagai fallback jika Supabase belum terhubung / tabel kosong.
  static final List<Map<String, dynamic>> _dummyPosts = [
    {
      'id': '1',
      'user_id': 'user_1',
      'username': 'alex_runner',
      'content':
          'Selesai lari pagi 5 km mengelilingi GBK! Udara pagi ini segar banget, tetap konsisten kawan-kawan! 🏃‍♂️🔥',
      'image_url':
          'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=800',
      'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      'time': '15m yang lalu',
      'likesCount': 12,
      'isLiked': false,
      'comments': <Map<String, dynamic>>[
        {
          'id': 'c1',
          'user_id': 'user_3',
          'username': 'budi_workout',
          'comment': 'Mantap Alex! Terus konsisten!',
        },
        {
          'id': 'c2',
          'user_id': 'user_2',
          'username': 'sarah_fit',
          'comment': 'Pace berapa tadi bro?',
        },
      ],
    },
    {
      'id': '2',
      'user_id': 'user_2',
      'username': 'sarah_fit',
      'content':
          'Hari ini fokus latihan otot kaki (leg day). Squat 4 set dan lunges bikin paha berasa terbakar tapi puas banget! 💪🏋️‍♀️',
      'image_url':
          'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=800',
      'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'time': '1 jam yang lalu',
      'likesCount': 28,
      'isLiked': true,
      'comments': <Map<String, dynamic>>[
        {
          'id': 'c3',
          'user_id': 'user_1',
          'username': 'alex_runner',
          'comment': 'Jangan lupa stretching setelahnya kak Sarah!',
        },
      ],
    },
    {
      'id': '3',
      'user_id': 'user_3',
      'username': 'budi_workout',
      'content':
          'Tips nutrisi: pastikan asupan protein tercukupi setelah latihan beban agar proses recovery dan perbaikan otot optimal. 🥗🍳',
      'image_url': null,
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'time': '3 jam yang lalu',
      'likesCount': 45,
      'isLiked': false,
      'comments': <Map<String, dynamic>>[
        {
          'id': 'c4',
          'user_id': 'user_2',
          'username': 'sarah_fit',
          'comment': 'Terima kasih infonya mas Budi, sangat bermanfaat!',
        },
        {
          'id': 'c5',
          'user_id': 'user_1',
          'username': 'alex_runner',
          'comment': 'Biasa konsumsi protein dari apa saja mas?',
        },
      ],
    },
  ];

  CommunityProvider() {
    posts = List.from(_dummyPosts);
  }

  /// Mengambil data postingan dari tabel 'posts' dengan relasi users(username, avatar_url)
  Future<void> fetchPosts() async {
    isLoading = true;
    notifyListeners();

    try {
      final uid = currentUserId;

      // Query ke tabel posts menggunakan relasi users(username, avatar_url)
      dynamic response;
      try {
        response = await _supabase
            .from('posts')
            .select('*, users(username, avatar_url), post_likes(*), post_comments(*)')
            .order('created_at', ascending: false);
      } catch (relationError) {
        debugPrint('Catatan: Query relasi users/likes gagal ($relationError), mencoba fallback...');
        try {
          response = await _supabase
              .from('posts')
              .select('*, users(username, avatar_url)')
              .order('created_at', ascending: false);
        } catch (_) {
          // Fallback tanpa relasi tabel users jika foreign key belum terpasang
          response = await _supabase
              .from('posts')
              .select('*')
              .order('created_at', ascending: false);
        }
      }

      final List<dynamic> data = response as List<dynamic>;

      if (data.isNotEmpty) {
        posts = data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final likesList = (map['post_likes'] as List<dynamic>?) ?? [];
          final commentsList = (map['post_comments'] as List<dynamic>?) ?? [];

          final bool isLiked = uid != null &&
              likesList.any((l) => (l is Map ? l['user_id']?.toString() : null) == uid);

          final List<Map<String, dynamic>> parsedComments = commentsList.map((c) {
            if (c is Map) {
              return <String, dynamic>{
                'id': c['id']?.toString() ?? '',
                'user_id': c['user_id']?.toString() ?? '',
                'username': c['username']?.toString() ?? 'Pengguna',
                'comment': c['comment']?.toString() ?? '',
                'created_at': c['created_at']?.toString(),
              };
            }
            return <String, dynamic>{
              'id': '',
              'user_id': '',
              'username': 'Pengguna',
              'comment': c.toString(),
            };
          }).toList();

          // Ambil username asli dari relasi tabel users.
          // Jika belum ada relasi, ambil sementara datanya dari Supabase Auth Metadata.
          String uname = 'Pengguna';
          String? avatarUrl;
          final userRel = map['users'];
          if (userRel is Map) {
            final relUname = userRel['username']?.toString();
            if (relUname != null && relUname.isNotEmpty) {
              uname = relUname;
            }
            final relAvatar = userRel['avatar_url']?.toString();
            if (relAvatar != null && relAvatar.isNotEmpty) {
              avatarUrl = relAvatar;
            }
          }

          if (uname == 'Pengguna') {
            final postUname = map['username']?.toString();
            if (postUname != null && postUname.isNotEmpty) {
              uname = postUname;
            } else if (map['user_id'] != null && map['user_id'] == uid) {
              // Ambil sementara datanya dari Supabase Auth Metadata
              uname = currentUsername;
            }
          }

          final createdAtStr = map['created_at']?.toString() ?? '';

          return <String, dynamic>{
            'id': map['id']?.toString() ?? '',
            'user_id': map['user_id']?.toString() ?? '',
            'username': uname,
            'avatar_url': avatarUrl,
            'content': map['content']?.toString() ?? '',
            'image_url': map['image_url']?.toString(),
            'created_at': createdAtStr,
            'time': formatTimeAgo(createdAtStr),
            'likesCount': likesList.length,
            'isLiked': isLiked,
            'comments': parsedComments,
          };
        }).toList();
      }

      // Ambil data user_follows jika pengguna login
      if (uid != null) {
        try {
          final followRes = await _supabase
              .from('user_follows')
              .select('following_id')
              .eq('follower_id', uid);

          following = (followRes as List<dynamic>)
              .map((f) => f['following_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
        } catch (e) {
          debugPrint('Info: user_follows fetch ignored: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetchPosts Supabase: $e');
      if (posts.isEmpty) {
        posts = List.from(_dummyPosts);
      }
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Menambahkan postingan baru ke tabel 'posts'.
  /// Payload HANYA mengirimkan key user_id, content, dan image_url.
  /// Kolom created_at diisi otomatis oleh Supabase.
  Future<void> addPost(String content, {String? imageUrl}) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Sesi pengguna tidak valid atau belum login.');
      }

      final payload = <String, dynamic>{
        'user_id': userId,
        'content': content.trim(),
      };
      if (imageUrl != null && imageUrl.isNotEmpty) {
        payload['image_url'] = imageUrl;
      }

      final inserted =
          await _supabase.from('posts').insert(payload).select().single();

      final createdAtStr = inserted['created_at']?.toString() ?? DateTime.now().toIso8601String();

      final newPost = <String, dynamic>{
        'id': inserted['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': userId,
        'username': currentUsername,
        'content': content.trim(),
        'image_url': imageUrl,
        'created_at': createdAtStr,
        'time': formatTimeAgo(createdAtStr),
        'likesCount': 0,
        'isLiked': false,
        'comments': <Map<String, dynamic>>[],
      };

      posts.insert(0, newPost);
      notifyListeners();
    } catch (e) {
      debugPrint('Error inserting post to Supabase: $e');
      rethrow;
    }
  }

  /// Mengupdate postingan di tabel 'posts' dan memperbarui state lokal.
  /// Payload HANYA mengirimkan key content dan image_url (jika tidak null).
  Future<void> updatePost(
    String postId,
    String newContent, {
    String? newImageUrl,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Sesi pengguna tidak valid atau belum login.');
      }

      final payload = <String, dynamic>{
        'content': newContent.trim(),
      };
      if (newImageUrl != null) {
        payload['image_url'] = newImageUrl;
      }

      await _supabase.from('posts').update(payload).eq('id', postId);

      // Cari index postingan di state posts dan perbarui nilainya secara lokal
      final index = posts.indexWhere(
        (p) => p['id']?.toString() == postId.toString(),
      );
      if (index != -1) {
        final updatedPost = Map<String, dynamic>.from(posts[index]);
        updatedPost['content'] = newContent.trim();
        if (newImageUrl != null) {
          updatedPost['image_url'] = newImageUrl;
        }
        posts[index] = updatedPost;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating post in Supabase: $e');
      rethrow;
    }
  }

  /// Menghapus postingan dari tabel 'posts' dan memori lokal.
  Future<void> deletePost(String postId) async {
    try {
      posts.removeWhere((p) => p['id']?.toString() == postId.toString());
      notifyListeners();

      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      debugPrint('Error deleting post in Supabase: $e');
      rethrow;
    }
  }

  /// Mengubah status like di memori dan menyinkronkannya ke tabel 'post_likes'.
  Future<void> toggleLike(String postId) async {
    final index = posts.indexWhere(
      (p) => p['id']?.toString() == postId.toString(),
    );
    if (index == -1) return;

    final post = posts[index];
    final bool currentIsLiked = post['isLiked'] as bool? ?? false;
    final int currentLikes = post['likesCount'] as int? ?? 0;

    // Pembaruan optimistik
    post['isLiked'] = !currentIsLiked;
    post['likesCount'] =
        !currentIsLiked ? currentLikes + 1 : (currentLikes > 0 ? currentLikes - 1 : 0);
    notifyListeners();

    final uid = currentUserId;
    if (uid == null) return;

    try {
      if (!currentIsLiked) {
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': uid,
        });
      } else {
        await _supabase.from('post_likes').delete().match({
          'post_id': postId,
          'user_id': uid,
        });
      }
    } catch (e) {
      debugPrint('Error toggleLike in Supabase: $e');
      rethrow;
    }
  }

  /// Menambahkan komentar di memori dan menyinkronkannya ke tabel 'post_comments'.
  Future<void> addComment(String postId, String comment) async {
    if (comment.trim().isEmpty) return;

    final index = posts.indexWhere((p) => p['id'].toString() == postId.toString());
    if (index == -1) return;

    final uid = currentUserId;
    final uname = currentUsername;
    final commentId = DateTime.now().millisecondsSinceEpoch.toString();

    final commentMap = <String, dynamic>{
      'id': commentId,
      'user_id': uid ?? 'user_me',
      'username': uname,
      'comment': comment.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    final commentsList = posts[index]['comments'];
    if (commentsList is List) {
      commentsList.add(commentMap);
    }
    notifyListeners();

    try {
      final commentPayload = <String, dynamic>{
        'post_id': postId,
        'comment': comment.trim(),
        'username': uname,
      };
      if (uid != null) {
        commentPayload['user_id'] = uid;
      }

      final inserted = await _supabase
          .from('post_comments')
          .insert(commentPayload)
          .select()
          .single();

      commentMap['id'] = inserted['id']?.toString() ?? commentId;
      notifyListeners();
    } catch (e) {
      debugPrint('Error addComment in Supabase: $e');
      rethrow;
    }
  }

  /// Menghapus komentar dari tabel 'post_comments' dan dari memori lokal.
  Future<void> deleteComment(String commentId) async {
    try {
      for (final post in posts) {
        final commentsList = post['comments'];
        if (commentsList is List) {
          commentsList.removeWhere((c) {
            if (c is Map) {
              return c['id']?.toString() == commentId.toString();
            }
            return false;
          });
        }
      }
      notifyListeners();

      await _supabase.from('post_comments').delete().eq('id', commentId);
    } catch (e) {
      debugPrint('Error deleting comment in Supabase: $e');
      rethrow;
    }
  }

  /// Melaporkan postingan dengan alasan ke tabel 'post_reports'.
  Future<void> reportPost(String postId, String reason) async {
    final uid = currentUserId;
    try {
      final payload = <String, dynamic>{
        'post_id': postId,
        'reason': reason.trim(),
      };
      if (uid != null) {
        payload['user_id'] = uid;
      }
      await _supabase.from('post_reports').insert(payload);
    } catch (e) {
      debugPrint('Error reporting post in Supabase: $e');
      rethrow;
    }
  }

  /// Mengubah status follow di memori dan menyinkronkannya ke tabel 'user_follows'.
  Future<void> toggleFollow(String targetUserId) async {
    final isCurrentlyFollowing = following.contains(targetUserId);

    // Pembaruan optimistik
    if (isCurrentlyFollowing) {
      following.remove(targetUserId);
    } else {
      following.add(targetUserId);
    }
    notifyListeners();

    final uid = currentUserId;
    if (uid == null) return;

    try {
      if (!isCurrentlyFollowing) {
        await _supabase.from('user_follows').insert({
          'follower_id': uid,
          'following_id': targetUserId,
        });
      } else {
        await _supabase.from('user_follows').delete().match({
          'follower_id': uid,
          'following_id': targetUserId,
        });
      }
    } catch (e) {
      debugPrint('Error toggleFollow in Supabase: $e');
      rethrow;
    }
  }

  /// Cek apakah targetUserId sedang di-follow.
  bool isFollowing(String targetUserId) {
    return following.contains(targetUserId);
  }
}
