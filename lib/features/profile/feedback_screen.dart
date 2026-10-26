import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/feedback_repository.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final FeedbackRepository _repository = FeedbackRepository();
  final TextEditingController _kesanController = TextEditingController();
  final TextEditingController _saranController = TextEditingController();

  int _rating = 0;
  bool _submitting = false;
  bool _loadingEntries = true;
  String? _entriesError;
  List<FeedbackEntry> _entries = [];
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  /// [silent] true dipakai saat tarik-untuk-memuat-ulang, supaya daftar
  /// tidak berkedip diganti indikator loading.
  Future<void> _loadEntries({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingEntries = true;
        _entriesError = null;
      });
    }

    try {
      final items = await _repository.fetchAll();
      if (!mounted) return;
      setState(() {
        _entries = items;
        _loadingEntries = false;
        _entriesError = null;
      });
    } on FeedbackException catch (error) {
      if (!mounted) return;
      if (silent) {
        _showMessage(error.message);
      } else {
        setState(() {
          _entriesError = error.message;
          _loadingEntries = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (silent) {
        _showMessage('Daftar gagal dimuat. Coba lagi.');
      } else {
        setState(() {
          _entriesError = 'Daftar gagal dimuat. Coba lagi.';
          _loadingEntries = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final kesan = _kesanController.text.trim();
    final saran = _saranController.text.trim();

    if (kesan.isEmpty || saran.isEmpty) {
      _showMessage('Kesan dan saran wajib diisi.');
      return;
    }
    if (_rating < 1) {
      _showMessage('Pilih penilaian 1 sampai 5 bintang.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final entry = await _repository.submit(
        saran: saran,
        kesan: kesan,
        rating: _rating,
      );
      if (!mounted) return;

      setState(() {
        _entries = [entry, ..._entries];
        _entriesError = null;
        _kesanController.clear();
        _saranController.clear();
        _rating = 0;
      });
      _showMessage('Terima kasih! Saran dan kesanmu sudah terkirim.');
    } on FeedbackException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Gagal mengirim. Coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmDelete(FeedbackEntry entry) async {
    if (_deletingIds.contains(entry.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus kiriman?'),
        content: const Text(
          'Saran dan kesan ini akan dihapus dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(entry.id));

    try {
      await _repository.delete(entry.id);
      if (!mounted) return;
      setState(() {
        _entries = _entries.where((e) => e.id != entry.id).toList();
      });
      _showMessage('Kiriman berhasil dihapus.');
    } on FeedbackException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Gagal menghapus. Coba lagi.');
    } finally {
      if (mounted) setState(() => _deletingIds.remove(entry.id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saran dan Kesan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadEntries(silent: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Mata kuliah Pemrograman Aplikasi Mobile',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              _buildForm(),
              const SizedBox(height: 28),
              const Text(
                'Saran dan kesan pengguna',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._buildEntries(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kesan', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _kesanController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Tulis kesanmu selama mengikuti mata kuliah ini...',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Saran', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _saranController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Tulis saran untuk pengembangan ke depan...',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Penilaian',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  _StarRating(
                    rating: _rating,
                    size: 36,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _rating = value),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rating == 0 ? 'Belum dipilih' : '$_rating dari 5',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Mengirim...' : 'Kirim'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kirimanmu akan terlihat oleh pengguna lain.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEntries() {
    if (_loadingEntries) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_entriesError != null) {
      return [
        Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.redAccent),
            title: Text(_entriesError!),
            trailing: TextButton(
              onPressed: _loadEntries,
              child: const Text('Coba lagi'),
            ),
          ),
        ),
      ];
    }

    if (_entries.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Belum ada kiriman. Jadilah yang pertama mengirim '
            'saran dan kesan.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ];
    }

    return [
      for (final entry in _entries)
        _EntryCard(
          entry: entry,
          deleting: _deletingIds.contains(entry.id),
          onDelete: entry.isMine ? () => _confirmDelete(entry) : null,
        ),
    ];
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.deleting,
    required this.onDelete,
  });

  final FeedbackEntry entry;
  final bool deleting;

  /// Null jika kiriman bukan milik pengguna yang sedang login.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt);
    final initial = entry.username.isEmpty
        ? '?'
        : entry.username.characters.first.toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFD9EEE7),
                  foregroundImage: entry.photoUrl == null
                      ? null
                      : NetworkImage(entry.photoUrl!),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF16856B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (entry.isMine) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE86524)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Kamu',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFE86524),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  deleting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: onDelete,
                        ),
              ],
            ),
            if (entry.rating != null && entry.rating! > 0) ...[
              const SizedBox(height: 10),
              _StarRating(rating: entry.rating!, size: 18),
            ],
            if (entry.kesan.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Kesan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE86524),
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(entry.kesan),
              ),
            ],
            if (entry.saran.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Saran',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE86524),
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(entry.saran),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bintang 1 sampai 5. Bisa diketuk jika [onChanged] diisi, selain itu hanya tampilan.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.size, this.onChanged});

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < rating;
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? const Color(0xFFFFB300) : Colors.white38,
        );

        if (onChanged == null) return star;

        return GestureDetector(
          onTap: () => onChanged!(index + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(padding: const EdgeInsets.all(2), child: star),
        );
      }),
    );
  }
}
