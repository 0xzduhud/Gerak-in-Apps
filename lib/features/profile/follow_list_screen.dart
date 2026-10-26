import 'package:flutter/material.dart';

import '../../data/repositories/profile_repository.dart';

enum FollowListKind { followers, following }

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key, required this.kind});

  final FollowListKind kind;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final ProfileRepository _repository = ProfileRepository();

  bool _loading = true;
  String? _error;
  List<FollowUser> _users = [];

  bool get _isFollowers => widget.kind == FollowListKind.followers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] true dipakai saat tarik-untuk-memuat-ulang.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final users = _isFollowers
          ? await _repository.fetchFollowers()
          : await _repository.fetchFollowing();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } on ProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Daftar gagal dimuat. Coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isFollowers ? 'Followers' : 'Following',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ),
        ],
      );
    }

    if (_users.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            _isFollowers ? Icons.people_outline : Icons.person_add_alt_outlined,
            size: 44,
            color: Colors.white38,
          ),
          const SizedBox(height: 12),
          Text(
            _isFollowers
                ? 'Belum ada yang mengikutimu.'
                : 'Kamu belum mengikuti siapa pun.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _users[index];
        final initial = user.displayName.isEmpty
            ? '?'
            : user.displayName.characters.first.toUpperCase();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFD9EEE7),
            foregroundImage: user.photoUrl == null
                ? null
                : NetworkImage(user.photoUrl!),
            onForegroundImageError: user.photoUrl == null ? null : (_, __) {},
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF16856B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('@${user.username}'),
        );
      },
    );
  }
}
