import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/services/secure_storage_service.dart';
import '../../data/repositories/profile_repository.dart';
import '../premium/premium_screen.dart';
import 'feedback_screen.dart';
import 'follow_list_screen.dart';

const Color _kPrimary = Color(0xFFE86524);
const Color _kGreen = Color(0xFF16856B);
const Color _kOnPrimary = Color(0xFF24110A);
const Color _kRed = Color(0xFFFF5252);

// Garis tepi tipis dan warna tint (versi transparan) untuk latar lencana ikon.
const Color _kBorder = Color(0x1FFFFFFF);
const Color _kPrimaryTint = Color(0x26E86524);
const Color _kRedTint = Color(0x26FF5252);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user, required this.onLogout});

  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _PhotoAction { gallery, camera, remove }

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final ProfileRepository _profileRepository = ProfileRepository();
  final ImagePicker _picker = ImagePicker();

  bool _biometricEnabled = false;
  bool _loadingBiometricSetting = true;
  bool _processingBiometric = false;

  FollowCounts? _counts;
  bool _savingPhoto = false;
  bool _savingName = false;

  String? _clean(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  String? get _fullName => _clean(widget.user['full_name']);
  String? get _photoUrl => _clean(widget.user['photo_url']);

  String get _displayName {
    final username = _clean(widget.user['username']);
    return _fullName ?? username ?? 'Pengguna';
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadOverview();
  }

  /// Memuat profil terbaru dan jumlah followers/following.
  /// Kalau gagal, layar tetap memakai data dari saat login.
  Future<void> _loadOverview() async {
    try {
      final overview = await _profileRepository.fetchOverview();
      if (!mounted) return;
      setState(() {
        _applyProfile(overview.profile);
        _counts = overview.counts;
      });
    } catch (error) {
      debugPrint('Profil: gagal memuat ringkasan: $error');
    }
  }

  /// Menyimpan perubahan ke data pengguna yang dipakai bersama
  /// (Home, Profile), supaya sapaan di Home ikut berubah.
  void _applyProfile(UserProfile profile) {
    widget.user['full_name'] = profile.fullName;
    widget.user['photo_url'] = profile.photoUrl;
  }

  Future<void> _loadBiometricSetting() async {
    try {
      final enabled = await SecureStorageService.isBiometricEnabled();

      if (!mounted) return;

      setState(() {
        _biometricEnabled = enabled;
        _loadingBiometricSetting = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _biometricEnabled = false;
        _loadingBiometricSetting = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (_processingBiometric || _loadingBiometricSetting) return;

    if (!enabled) {
      try {
        await SecureStorageService.saveBiometricEnabled(false);

        if (!mounted) return;

        setState(() => _biometricEnabled = false);
        _showMessage('Login biometrik berhasil dinonaktifkan.');
      } catch (error) {
        _showMessage('Gagal mengubah pengaturan: $error');
      }

      return;
    }

    setState(() => _processingBiometric = true);

    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;

      if (!supported || !canCheck) {
        _showMessage('Perangkat tidak mendukung autentikasi biometrik.');
        return;
      }

      final available = await _localAuth.getAvailableBiometrics();

      if (available.isEmpty) {
        _showMessage(
          'Daftarkan sidik jari atau wajah di pengaturan perangkat '
          'terlebih dahulu.',
        );
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Verifikasi identitas untuk mengaktifkan login biometrik Gerak-in',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) {
        _showMessage('Verifikasi dibatalkan atau tidak berhasil.');
        return;
      }

      await SecureStorageService.saveBiometricEnabled(true);

      if (!mounted) return;

      setState(() => _biometricEnabled = true);
      _showMessage('Login biometrik berhasil diaktifkan.');
    } catch (error) {
      _showMessage('Biometrik tidak dapat digunakan: $error');
    } finally {
      if (mounted) {
        setState(() => _processingBiometric = false);
      }
    }
  }

  // ---------- Foto profil ----------

  Future<void> _showPhotoSheet() async {
    if (_savingPhoto) return;

    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.camera),
            ),
            if (_photoUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text('Hapus foto'),
                onTap: () => Navigator.pop(sheetContext, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _PhotoAction.gallery:
        await _changePhoto(ImageSource.gallery);
      case _PhotoAction.camera:
        await _changePhoto(ImageSource.camera);
      case _PhotoAction.remove:
        await _removePhoto();
    }
  }

  Future<void> _changePhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (file == null || !mounted) return;

      setState(() => _savingPhoto = true);

      final profile = await _profileRepository.updatePhoto(file);
      if (!mounted) return;

      setState(() => _applyProfile(profile));
      _showMessage('Foto profil berhasil diperbarui.');
    } on ProfileException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        'Tidak dapat membuka kamera atau galeri. Periksa izin aplikasi.',
      );
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _savingPhoto = true);

    try {
      final profile = await _profileRepository.removePhoto();
      if (!mounted) return;

      setState(() => _applyProfile(profile));
      _showMessage('Foto profil dihapus.');
    } on ProfileException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Gagal menghapus foto. Coba lagi.');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  // ---------- Nama lengkap ----------

  Future<void> _editName() async {
    if (_savingName) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: _fullName ?? ''),
    );

    if (newName == null || !mounted || newName == _fullName) return;

    setState(() => _savingName = true);

    try {
      final profile = await _profileRepository.updateFullName(newName);
      if (!mounted) return;

      setState(() => _applyProfile(profile));
      _showMessage('Nama lengkap berhasil diperbarui.');
    } on ProfileException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Gagal menyimpan nama. Coba lagi.');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ---------- Followers / Following ----------

  Future<void> _openFollowList(FollowListKind kind) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => FollowListScreen(kind: kind)),
    );
    if (mounted) _loadOverview();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Tampilan ----------

  /// Header: foto di kiri; nama, username, followers, dan following di kanan.
  Widget _buildProfileHeader() {
    final url = _photoUrl;
    final username = _clean(widget.user['username']) ?? '-';
    final counts = _counts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _savingPhoto ? null : _showPhotoSheet,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFFD9EEE7),
                  foregroundImage: url == null ? null : NetworkImage(url),
                  onForegroundImageError: url == null ? null : (_, __) {},
                  child: const Icon(
                    Icons.person_rounded,
                    size: 50,
                    color: _kGreen,
                  ),
                ),
                if (_savingPhoto)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kPrimary,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      size: 14,
                      color: _kOnPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 20,
                  runSpacing: 6,
                  children: [
                    _FollowCount(
                      value: counts?.followers,
                      label: 'followers',
                      onTap: () => _openFollowList(FollowListKind.followers),
                    ),
                    _FollowCount(
                      value: counts?.following,
                      label: 'following',
                      onTap: () => _openFollowList(FollowListKind.following),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _clean(widget.user['email']) ?? '-';
    final username = _clean(widget.user['username']) ?? '-';

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 32),
          const _SectionTitle('Akun'),
          _AppCard(
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.badge_outlined,
                  title: 'Nama lengkap',
                  subtitle: _fullName ?? '-',
                  onTap: _savingName ? null : _editName,
                  trailing: _savingName
                      ? const _TrailingSpinner()
                      : const _Chevron(),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.alternate_email_rounded,
                  title: 'Username',
                  subtitle: username,
                  trailing: const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: Colors.white38,
                  ),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email',
                  subtitle: email,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('Langganan'),
          _AppCard(
            child: _SettingsRow(
              icon: Icons.workspace_premium_rounded,
              iconColor: _kOnPrimary,
              iconTint: _kPrimary,
              title: 'FitMate Plus',
              subtitle: 'Buka semua fitur latihan dan achievement',
              trailing: const _Chevron(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('Keamanan'),
          _AppCard(
            child: _SettingsRow(
              icon: Icons.fingerprint_rounded,
              title: 'Login biometrik',
              subtitle: _loadingBiometricSetting
                  ? 'Memuat pengaturan...'
                  : _processingBiometric
                  ? 'Memverifikasi biometrik...'
                  : 'Sidik jari atau wajah membuka sesi yang tersimpan',
              onTap: _loadingBiometricSetting || _processingBiometric
                  ? null
                  : () => _toggleBiometric(!_biometricEnabled),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: _loadingBiometricSetting || _processingBiometric
                    ? null
                    : _toggleBiometric,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('Lainnya'),
          _AppCard(
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.rate_review_outlined,
                  title: 'Saran dan Kesan',
                  subtitle: 'Mata kuliah Pemrograman Aplikasi Mobile',
                  trailing: const _Chevron(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                    );
                  },
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  iconColor: _kRed,
                  iconTint: _kRedTint,
                  title: 'Keluar',
                  titleColor: _kRed,
                  subtitle: 'Akhiri sesi di perangkat ini',
                  onTap: widget.onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Komponen tampilan ----------

/// Kartu datar dengan garis tepi tipis. Memakai Material supaya efek
/// sentuhan (ripple) pada baris di dalamnya terlihat.
class _AppCard extends StatelessWidget {
  const _AppCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _kBorder),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Lencana ikon bulat dengan latar berwarna tipis.
class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    this.color = _kPrimary,
    this.tint = _kPrimaryTint,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chevron_right_rounded, color: Colors.white38);
  }
}

class _TrailingSpinner extends StatelessWidget {
  const _TrailingSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    // indent 74 = padding kiri (16) + lebar lencana (44) + jarak (14),
    // supaya garis sejajar dengan teks.
    return const Divider(height: 1, thickness: 1, indent: 74, color: _kBorder);
  }
}

/// Satu baris: lencana ikon, judul dengan keterangan di bawahnya, lalu
/// elemen di kanan (panah, gembok, atau switch).
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = _kPrimary,
    this.iconTint = _kPrimaryTint,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconTint;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconBadge(icon: icon, color: iconColor, tint: iconTint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Angka tebal diikuti label, misalnya "469 followers". Bisa diketuk.
class _FollowCount extends StatelessWidget {
  const _FollowCount({
    required this.value,
    required this.label,
    required this.onTap,
  });

  /// Null selama belum berhasil dimuat.
  final int? value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' $label',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog ubah nama. Controller dikelola di sini supaya dibuang dengan aman.
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  static final RegExp _pattern = RegExp(
    r"^[\p{L}\p{N} .,'’\-]+$",
    unicode: true,
  );

  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (value.length < 2) {
      setState(() => _error = 'Nama minimal 2 karakter.');
      return;
    }
    if (value.length > 60) {
      setState(() => _error = 'Nama maksimal 60 karakter.');
      return;
    }
    if (!_pattern.hasMatch(value)) {
      setState(
        () => _error =
            'Nama hanya boleh berisi huruf, angka, dan tanda baca sederhana.',
      );
      return;
    }

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah nama lengkap'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nama lengkap',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
