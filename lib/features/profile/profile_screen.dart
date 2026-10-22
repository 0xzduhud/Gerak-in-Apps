import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/services/secure_storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.user, required this.onLogout});

  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _biometricEnabled = false;
  bool _loadingBiometricSetting = true;
  bool _processingBiometric = false;

  String get _displayName {
    final fullName = widget.user['full_name']?.toString().trim();
    final username = widget.user['username']?.toString().trim();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return 'Pengguna';
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user['email']?.toString() ?? '-';
    final username = widget.user['username']?.toString() ?? '-';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Profil saya',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        const Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Color(0xFFD9EEE7),
            child: Icon(
              Icons.person_rounded,
              size: 54,
              color: Color(0xFF16856B),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nama lengkap'),
                subtitle: Text(_displayName),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('Username'),
                subtitle: Text(username),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Keamanan',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            secondary: const Icon(
              Icons.fingerprint_rounded,
              color: Color(0xFFE86524),
              size: 30,
            ),
            title: const Text('Login biometrik'),
            subtitle: Text(
              _loadingBiometricSetting
                  ? 'Memuat pengaturan...'
                  : _processingBiometric
                  ? 'Memverifikasi biometrik...'
                  : 'Gunakan sidik jari atau wajah saat membuka aplikasi',
            ),
            value: _biometricEnabled,
            onChanged: _loadingBiometricSetting || _processingBiometric
                ? null
                : _toggleBiometric,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Saran dan kesan mata kuliah '
          'Pemrograman Aplikasi Mobile',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bagian saran dan kesan dapat dilengkapi '
          'dengan formulir pada pengembangan berikutnya.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE86524),
              foregroundColor: const Color(0xFF24110A),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
