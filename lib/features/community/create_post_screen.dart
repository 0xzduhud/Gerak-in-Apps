import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_provider.dart';

/// [CreatePostScreen] - Layar membuat atau mengedit postingan komunitas dengan kamera, galeri, dan Supabase Storage.
class CreatePostScreen extends StatefulWidget {
  /// Parameter opsional data postingan untuk mode Edit.
  final Map<String, dynamic>? post;

  const CreatePostScreen({super.key, this.post});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;

  static const Color _primary = Color(0xFFE86524);
  static const Color _background = Color(0xFF171312);
  static const Color _surface = Color(0xFF241F1D);
  static const Color _border = Color(0xFF332B28);

  bool get _isEditMode => widget.post != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _textController.text = widget.post!['content']?.toString() ?? '';
      _existingImageUrl = widget.post!['image_url']?.toString();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Memilih atau mengambil foto menggunakan ImageSource (kamera / galeri)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil gambar: $e')),
      );
    }
  }

  /// Mengunggah gambar ke bucket 'post-images' di Supabase Storage dan membuat atau memperbarui postingan
  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    final oldImageUrl = widget.post?['image_url']?.toString();
    final hasExistingImage =
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) ||
        (oldImageUrl != null && oldImageUrl.isNotEmpty);

    if (text.isEmpty && _selectedImage == null && !hasExistingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tuliskan sesuatu atau pilih foto terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<CommunityProvider>();

      if (_isEditMode) {
        final postId = widget.post!['id'].toString();

        // Cek apakah ada file gambar baru yang dipilih dari image_picker
        if (_selectedImage != null) {
          final fileExt = _selectedImage!.name.contains('.')
              ? _selectedImage!.name.split('.').last
              : 'jpg';
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}';

          // Upload file ke bucket 'post-images' di Supabase Storage menggunakan metode .upload()
          if (kIsWeb) {
            final bytes = await _selectedImage!.readAsBytes();
            await Supabase.instance.client.storage
                .from('post-images')
                .uploadBinary(
                  fileName,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: 'image/$fileExt',
                    upsert: true,
                  ),
                );
          } else {
            final file = File(_selectedImage!.path);
            await Supabase.instance.client.storage
                .from('post-images')
                .upload(
                  fileName,
                  file,
                  fileOptions: FileOptions(
                    contentType: 'image/$fileExt',
                    upsert: true,
                  ),
                );
          }

          // Ambil tautan publiknya menggunakan getPublicUrl
          final urlBaru = Supabase.instance.client.storage
              .from('post-images')
              .getPublicUrl(fileName);

          if (!mounted) return;
          // Panggil updatePost(postId, newContent, newImageUrl: urlBaru)
          await provider.updatePost(
            postId,
            text,
            newImageUrl: urlBaru,
          );
        } else {
          // Jika tidak ada gambar baru: Panggil updatePost dengan meneruskan teks yang diperbarui
          // dan URL gambar bawaan dari data post lama
          final fallbackImageUrl =
              _existingImageUrl ?? widget.post?['image_url']?.toString();
          await provider.updatePost(
            postId,
            text,
            newImageUrl: fallbackImageUrl,
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postingan berhasil diperbarui.')),
        );
      } else {
        // Mode baru: upload gambar jika ada dan eksekusi addPost
        String? publicImageUrl;
        if (_selectedImage != null) {
          final fileExt = _selectedImage!.name.contains('.')
              ? _selectedImage!.name.split('.').last
              : 'jpg';
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name}';

          // Upload file ke bucket 'post-images' di Supabase Storage menggunakan metode .upload()
          if (kIsWeb) {
            final bytes = await _selectedImage!.readAsBytes();
            await Supabase.instance.client.storage
                .from('post-images')
                .uploadBinary(
                  fileName,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: 'image/$fileExt',
                    upsert: true,
                  ),
                );
          } else {
            final file = File(_selectedImage!.path);
            await Supabase.instance.client.storage
                .from('post-images')
                .upload(
                  fileName,
                  file,
                  fileOptions: FileOptions(
                    contentType: 'image/$fileExt',
                    upsert: true,
                  ),
                );
          }

          publicImageUrl = Supabase.instance.client.storage
              .from('post-images')
              .getPublicUrl(fileName);
        }

        if (!mounted) return;
        await provider.addPost(text, imageUrl: publicImageUrl);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postingan berhasil dibagikan.')),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saat menyimpan postingan: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final errorMessage = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isEditMode ? 'Edit Postingan' : 'Buat Postingan',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Profil Singkat
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _surface,
                    child: const Icon(
                      Icons.person_rounded,
                      color: _primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.read<CommunityProvider>().currentUsername,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _isEditMode
                            ? 'Memperbarui postingan'
                            : 'Berbagi ke Komunitas',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // TextField multiline untuk konten teks
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: null,
                minLines: 5,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: _isEditMode
                      ? 'Perbarui pesan atau ceritamu...'
                      : 'Apa aktivitas olahraga atau tips sehatmu hari ini?',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              // Preview Gambar Baru yang Dipilih
              if (_selectedImage != null) ...[
                const SizedBox(height: 16),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: kIsWeb
                            ? Image.network(
                                _selectedImage!.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_existingImageUrl != null &&
                  _existingImageUrl!.isNotEmpty) ...[
                // Preview Gambar Lama (Mode Edit)
                const SizedBox(height: 16),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Image.network(
                          _existingImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 160,
                            color: _surface,
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
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _existingImageUrl = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              const Divider(color: _border),
              const SizedBox(height: 12),

              // Pilihan Gambar: Row berisi dua tombol: Ikon Kamera dan Ikon Galeri dari image_picker
              Row(
                children: [
                  // Tombol Kamera
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickImage(ImageSource.camera),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: _primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Kamera',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Tombol Galeri
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickImage(ImageSource.gallery),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              color: _primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Galeri',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Tombol Simpan / Bagikan
              ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Simpan Perubahan' : 'Bagikan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
