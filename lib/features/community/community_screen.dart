import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'community_provider.dart';
import 'create_post_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const Color _primary = Color(0xFFE86524);
  static const Color _backgroundColor = Color(0xFF17172B);
  static const Color _surfaceColor = Color(0xFF22213D);
  static const Color _border = Color(0xFF343251);
  static const Color _likeColor = Color(0xFFFF334B);

  Color get _background => _backgroundColor;
  Color get _surface => _surfaceColor;

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

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Community',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  provider.setSearchQuery(value);
                  setState(() {});
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari anggota atau postingan...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: 20,
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
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: _surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: _primary),
                  ),
                ),
              ),
            ),
          ),

          // Activity Feed
          Expanded(
            child: RefreshIndicator(
              color: _primary,
              backgroundColor: _surface,
              onRefresh: () async {
                await context.read<CommunityProvider>().fetchPosts();
              },
              child: provider.isLoading && provider.posts.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _primary),
                    )
                  : filteredPosts.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
        },
        backgroundColor: _primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  // Membuka gambar dalam tampilan fullscreen.
  // Mendukung zoom dengan dua jari dan tombol tutup.
  void _showImageViewer(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // Ketuk area kosong untuk menutup gambar.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(dialogContext),
                ),
              ),

              // Gambar fullscreen dan dapat diperbesar.
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
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white38,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Tombol tutup.
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card postingan.
  Widget _buildPostCard(
    BuildContext context,
    CommunityProvider provider,
    Map<String, dynamic> post,
  ) {
    final String postId = post['id']?.toString() ?? '';
    final String postUserId = post['user_id']?.toString() ?? '';

    final String targetUserId = postUserId.isNotEmpty
        ? postUserId
        : (post['username']?.toString() ?? '');

    final String username = post['username']?.toString() ?? 'Pengguna';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header postingan.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: avatarUrl.isNotEmpty
                    ? () => _showImageViewer(context, avatarUrl)
                    : null,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _background,
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
                            color: _primary,
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
                    const SizedBox(height: 3),
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

              // Tombol follow.
              if (!isMe) ...[
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () {
                      provider.toggleFollow(targetUserId);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: _primary, width: 1.2),
                      backgroundColor: isFollowing
                          ? _primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Menu titik tiga.
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                color: _surface,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _border),
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
                              color: _primary,
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
                  }

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
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Teks postingan.
          if (content.isNotEmpty)
            Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),

          // Foto postingan: ketuk untuk membuka fullscreen.
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _showImageViewer(context, imageUrl);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  width: double.infinity,
                  color: _background,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 160,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white38,
                            size: 36,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Like dan komentar.
          Row(
            children: [
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
                        color: isLiked ? _likeColor : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$likesCount',
                        style: TextStyle(
                          color: isLiked ? _likeColor : Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _showCommentsBottomSheet(context, postId);
                },
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

  // Dialog konfirmasi hapus postingan.
  void _confirmDeletePost(
    BuildContext context,
    CommunityProvider provider,
    String postId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
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

  // Dialog laporan postingan.
  void _showReportDialog(
    BuildContext context,
    CommunityProvider provider,
    String postId,
  ) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
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
                fillColor: _background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary),
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
              backgroundColor: _primary,
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

  // Modal komentar.
  void _showCommentsBottomSheet(BuildContext context, String postId) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Consumer<CommunityProvider>(
          builder: (context, provider, child) {
            final postIndex = provider.posts.indexWhere(
              (post) => post['id'] == postId,
            );

            if (postIndex == -1) {
              return const SizedBox.shrink();
            }

            final post = provider.posts[postIndex];

            final List<dynamic> comments =
                (post['comments'] as List<dynamic>?) ?? [];

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
                    // Indikator modal.
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header komentar.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
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
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: _border, height: 1),

                    // Daftar komentar.
                    Flexible(
                      child: comments.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'Belum ada komentar.\nJadilah yang pertama berkomentar!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
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
                                  const Divider(color: _border, height: 16),
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

                                  commentUserId =
                                      item['user_id']?.toString() ?? '';

                                  username =
                                      item['username']?.toString() ??
                                      'Pengguna';

                                  final fullName =
                                      item['full_name']?.toString().trim() ??
                                      '';

                                  displayName = fullName.isNotEmpty
                                      ? fullName
                                      : username;

                                  avatarUrl =
                                      item['avatar_url']?.toString() ?? '';

                                  commentText =
                                      item['comment']?.toString() ?? '';
                                } else {
                                  commentId = '';
                                  commentUserId = '';
                                  username = 'Pengguna';
                                  displayName = 'Pengguna';
                                  avatarUrl = '';
                                  commentText = item.toString();
                                }

                                final String? currentUid =
                                    provider.currentUserId;

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
                                      backgroundColor: _primary.withValues(
                                        alpha: 0.2,
                                      ),
                                      backgroundImage: avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: avatarUrl.isEmpty
                                          ? Text(
                                              displayName.isNotEmpty
                                                  ? displayName[0].toUpperCase()
                                                  : 'P',
                                              style: const TextStyle(
                                                color: _primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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

                                    // Hapus komentar milik sendiri.
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
                                        onPressed: () {
                                          provider.deleteComment(commentId);
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                    ),

                    // Input komentar.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _background,
                        border: const Border(top: BorderSide(color: _border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
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
                                fillColor: _surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: _border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: _border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: _primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              color: _primary,
                            ),
                            onPressed: () {
                              final text = commentController.text.trim();

                              if (text.isNotEmpty) {
                                provider.addComment(postId, text);
                                commentController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      commentController.dispose();
    });
  }
}
