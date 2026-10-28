import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'community_provider.dart';
import 'create_post_screen.dart';

const Color _kPrimary = Color(0xFFE86524);
const Color _kBorder = Color(0x1FFFFFFF);
const Color _kLikeColor = Color(0xFFFF334B);

/// Warna latar dan kartu diambil dari tema, memakai context yang diberikan
/// pemanggil (bukan context milik State), supaya aman dipakai di dalam
/// dialog dan lembar yang dibangun ulang.
Color _backgroundOf(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;
Color _surfaceOf(BuildContext context) => Theme.of(context).colorScheme.surface;

/// [CommunityScreen] - Layar komunitas Gerak-in. Warna latar, kartu, dan
/// dialog mengikuti tema aplikasi, sama seperti halaman Profile.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<CommunityProvider>().fetchPosts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final filteredPosts = provider.filteredPosts;
    final bool isSearching = provider.searchQuery.trim().isNotEmpty;
    final surface = _surfaceOf(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Community',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: SizedBox(
              height: 44.0,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => provider.setSearchQuery(val),
                style: const TextStyle(color: Colors.white, fontSize: 14.0),
                decoration: InputDecoration(
                  hintText: 'Cari anggota atau postingan...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14.0,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: 20.0,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.white38,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: const BorderSide(color: _kPrimary),
                  ),
                ),
              ),
            ),
          ),

          // 2. Activity Feed
          Expanded(
            child: RefreshIndicator(
              color: _kPrimary,
              backgroundColor: surface,
              onRefresh: () async {
                await context.read<CommunityProvider>().fetchPosts();
              },
              child: provider.isLoading && provider.posts.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPrimary),
                    )
                  : filteredPosts.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSearching
                                    ? Icons.search_off_rounded
                                    : Icons.forum_outlined,
                                color: Colors.white24,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isSearching
                                    ? 'Tidak ada postingan yang sesuai dengan "${provider.searchQuery}".'
                                    : 'Belum ada postingan di komunitas.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(top: 4, bottom: 84),
                      itemCount: filteredPosts.length,
                      itemBuilder: (context, index) {
                        final post = filteredPosts[index];
                        return _buildPostCard(context, provider, post);
                      },
                    ),
            ),
          ),
        ],
      ),
      // FAB oranye dengan ikon pensil untuk navigasi ke CreatePostScreen
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
        },
        backgroundColor: _kPrimary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  /// Membuka foto di tengah layar: latar gelap, bisa di-zoom dengan dua jari,
  /// ditutup dengan mengetuk area gelap atau tombol X.
  void _showImageViewer(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Ketuk area kosong untuk menutup.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(dialogContext),
                ),
              ),
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(color: _kPrimary),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white38,
                              size: 48,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membangun Card Feed Postingan
  Widget _buildPostCard(
    BuildContext context,
    CommunityProvider provider,
    Map<String, dynamic> post,
  ) {
    final surface = _surfaceOf(context);
    final background = _backgroundOf(context);

    final String postId = post['id']?.toString() ?? '';
    final String postUserId = post['user_id']?.toString() ?? '';
    final String targetUserId = postUserId.isNotEmpty
        ? postUserId
        : (post['username']?.toString() ?? '');
    final String username = post['username']?.toString() ?? 'Pengguna';

    // Tampilkan nama lengkap; kalau belum diisi, pakai username.
    final String rawFullName = post['full_name']?.toString().trim() ?? '';
    final bool hasFullName = rawFullName.isNotEmpty;
    final String displayName = hasFullName ? rawFullName : username;

    final String content = post['content']?.toString() ?? '';
    final String imageUrl = post['image_url']?.toString() ?? '';
    final String avatarUrl = post['avatar_url']?.toString() ?? '';
    final String time = formatTimeAgo(post['created_at']?.toString() ?? '');
    final int likesCount = post['likesCount'] as int? ?? 0;
    final bool isLiked = post['isLiked'] as bool? ?? false;
    final List<dynamic> comments = (post['comments'] as List<dynamic>?) ?? [];

    final String? currentUid = provider.currentUserId;
    final bool isMe =
        (currentUid != null && postUserId == currentUid) ||
        username == provider.currentUsername ||
        username == 'Saya';
    final bool isFollowing = provider.isFollowing(targetUserId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: foto profil, nama, waktu post, tombol Follow & menu titik tiga
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: avatarUrl.isNotEmpty
                    ? () => _showImageViewer(context, avatarUrl)
                    : null,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: background,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kPrimary,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasFullName ? '@$username  •  $time' : time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol Follow (garis luar oranye) jika bukan milik user sendiri
              if (!isMe) ...[
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () => provider.toggleFollow(targetUserId),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: _kPrimary, width: 1.2),
                      backgroundColor: isFollowing
                          ? _kPrimary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // PopupMenuButton (titik tiga) di sudut kanan
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                color: surface,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _kBorder),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreatePostScreen(post: post),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDeletePost(context, provider, postId);
                  } else if (value == 'report') {
                    _showReportDialog(context, provider, postId);
                  }
                },
                itemBuilder: (BuildContext context) {
                  if (isMe) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: _kPrimary,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Hapus',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  } else {
                    return [
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(
                              Icons.report_problem_outlined,
                              color: Colors.orangeAccent,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Laporkan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Body: Teks konten
          if (content.isNotEmpty)
            Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),

          // Body: Gambar (ketuk untuk dibuka di tengah layar)
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showImageViewer(context, imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  width: double.infinity,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 180,
                        color: background,
                        child: const Center(
                          child: CircularProgressIndicator(color: _kPrimary),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 160,
                      color: background,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white38,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Footer: ikon Like (merah jika di-like) + jumlah, dan ikon Comment + jumlah
          Row(
            children: [
              // Ikon Like
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => provider.toggleLike(postId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isLiked ? _kLikeColor : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$likesCount',
                        style: TextStyle(
                          color: isLiked ? _kLikeColor : Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Ikon Comment (membuka lembar komentar)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showCommentsBottomSheet(context, postId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 19,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${comments.length}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dialog konfirmasi hapus postingan
  void _confirmDeletePost(
    BuildContext context,
    CommunityProvider provider,
    String postId,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceOf(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Text(
          'Hapus Postingan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Apakah kamu yakin ingin menghapus postingan ini? Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deletePost(postId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Postingan berhasil dihapus.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog formulir laporan postingan
  void _showReportDialog(
    BuildContext context,
    CommunityProvider provider,
    String postId,
  ) {
    final TextEditingController reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceOf(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Text(
          'Laporkan Postingan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Berikan alasan mengapa postingan ini perlu dilaporkan:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Contoh: Spam, pelecehan, misinformasi...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: _backgroundOf(ctx),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              provider.reportPost(postId, reason);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Laporan berhasil dikirim. Terima kasih!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Kirim Laporan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Membuka lembar komentar. Isinya ada di widget [_CommentsSheet] supaya
  /// punya siklus hidup dan context sendiri.
  void _showCommentsBottomSheet(BuildContext context, String postId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(postId: postId),
    );
  }
}

/// Lembar komentar sebuah postingan.
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postId});

  final String postId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _send(CommunityProvider provider) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await provider.addComment(widget.postId, text);
      if (!mounted) return;
      _controller.clear();
    } catch (error) {
      _showMessage('Gagal mengirim komentar: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(CommunityProvider provider, String commentId) async {
    try {
      await provider.deleteComment(commentId);
    } catch (error) {
      _showMessage('Gagal menghapus komentar: ${_errorText(error)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final surface = _surfaceOf(context);
    final background = _backgroundOf(context);

    final postIndex = provider.posts.indexWhere(
      (p) => p['id'] == widget.postId,
    );
    if (postIndex == -1) return const SizedBox.shrink();

    final post = provider.posts[postIndex];
    final List<dynamic> comments = (post['comments'] as List<dynamic>?) ?? [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle drag indicator
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Text(
                    'Komentar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${comments.length})',
                    style: const TextStyle(fontSize: 14, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Divider(color: _kBorder, height: 1),

            // Daftar komentar
            Flexible(
              child: comments.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Belum ada komentar.\nJadilah yang pertama berkomentar!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: comments.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: _kBorder, height: 16),
                      itemBuilder: (context, index) {
                        final item = comments[index];
                        final String username;
                        final String displayName;
                        final String avatarUrl;
                        final String commentText;
                        final String commentId;
                        final String commentUserId;

                        if (item is Map) {
                          commentId = item['id']?.toString() ?? '';
                          commentUserId = item['user_id']?.toString() ?? '';
                          username = item['username']?.toString() ?? 'Pengguna';
                          final fullName =
                              item['full_name']?.toString().trim() ?? '';
                          displayName = fullName.isNotEmpty
                              ? fullName
                              : username;
                          avatarUrl = item['avatar_url']?.toString() ?? '';
                          commentText = item['comment']?.toString() ?? '';
                        } else {
                          commentId = '';
                          commentUserId = '';
                          username = 'Pengguna';
                          displayName = 'Pengguna';
                          avatarUrl = '';
                          commentText = item.toString();
                        }

                        final String? currentUid = provider.currentUserId;
                        final bool isMyComment =
                            (currentUid != null &&
                                commentUserId == currentUid) ||
                            username == provider.currentUsername ||
                            username == 'Saya';

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _kPrimary.withValues(alpha: 0.2),
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: avatarUrl.isEmpty
                                  ? Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: _kPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    commentText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Ikon tempat sampah hanya jika komentar dibuat oleh pengguna yang login
                            if (isMyComment && commentId.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                splashRadius: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                tooltip: 'Hapus Komentar',
                                onPressed: () => _delete(provider, commentId),
                              ),
                          ],
                        );
                      },
                    ),
            ),

            // Input komentar di bagian bawah
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: background,
                border: const Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(provider),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Tulis komentar...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: _kPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kPrimary,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: _kPrimary,
                          ),
                          onPressed: () => _send(provider),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
