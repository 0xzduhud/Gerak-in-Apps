import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/biometric_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repository = AuthRepository();
  final _biometricService = BiometricService();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _autoBiometricAttempted = false;

  @override
  void initState() {
    super.initState();
    _initializeLoginScreen();
  }

  /// Periksa status biometrik, lalu tampilkan autentikasi otomatis
  /// jika biometrik aktif dan tersedia pada perangkat.
  Future<void> _initializeLoginScreen() async {
    await _checkBiometricStatus();

    if (!mounted ||
        !_biometricEnabled ||
        !_biometricAvailable ||
        _autoBiometricAttempted) {
      return;
    }

    // Beri waktu agar halaman Login selesai ditampilkan.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted ||
        !_biometricEnabled ||
        !_biometricAvailable ||
        _autoBiometricAttempted) {
      return;
    }

    _autoBiometricAttempted = true;
    await _loginWithBiometrics();
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final enabled = await SecureStorageService.isBiometricEnabled();
      final available = await _biometricService.isAvailable();

      if (!mounted) return;

      setState(() {
        // Status biometrik tidak bergantung pada keberadaan token.
        // Token diperiksa setelah autentikasi biometrik berhasil.
        _biometricEnabled = enabled && available;
        _biometricAvailable = available;
      });
    } catch (error) {
      debugPrint('Gagal memeriksa status biometrik: $error');

      if (!mounted) return;

      setState(() {
        _biometricEnabled = false;
        _biometricAvailable = false;
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openHome(Map<String, dynamic> user) async {
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            HomeScreen(user: user, repository: _repository, onLogout: _logout),
      ),
    );
  }

  /// Login manual tetap menggunakan alur Sprint 5 yang sudah ada.
  Future<void> _login() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final result = await _repository.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      final token = result['token'];
      final userData = result['user'];

      if (token is! String || token.isEmpty || userData is! Map) {
        throw Exception('Respons login tidak lengkap.');
      }

      // Pemeriksaan diagnostik lama tetap dipertahankan.
      // Kegagalan endpoint activities tidak membatalkan login.
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'activities',
          method: HttpMethod.get,
          headers: {'Authorization': 'Bearer $token'},
        );

        debugPrint('ACTIVITIES STATUS: ${response.status}');
        debugPrint('ACTIVITIES RESPONSE: ${response.data}');
      } on FunctionException catch (error) {
        debugPrint('ACTIVITIES STATUS: ${error.status}');
        debugPrint('ACTIVITIES ERROR DETAIL: ${error.details}');
      } catch (error) {
        debugPrint('ACTIVITIES ERROR: $error');
      }

      await _repository.saveSession(token);

      if (!mounted) return;

      await _openHome(Map<String, dynamic>.from(userData));
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Autentikasi biometrik otomatis maupun melalui tombol.
  Future<void> _loginWithBiometrics() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final enabled = await SecureStorageService.isBiometricEnabled();

      if (!enabled) {
        if (mounted) {
          setState(() => _biometricEnabled = false);
        }

        _showMessage(
          'Login biometrik belum aktif. Silakan login '
          'dengan username/email dan password.',
        );
        return;
      }

      final available = await _biometricService.isAvailable();

      if (!available) {
        if (mounted) {
          setState(() {
            _biometricAvailable = false;
            _biometricEnabled = false;
          });
        }

        _showMessage(
          'Biometrik tidak tersedia. Periksa pengaturan '
          'keamanan perangkat.',
        );
        return;
      }

      // Minta autentikasi biometrik terlebih dahulu.
      final authenticated = await _biometricService.authenticate();

      if (!authenticated) {
        _showMessage('Autentikasi biometrik dibatalkan atau gagal.');
        return;
      }

      // Biometrik berhasil, sekarang periksa sesi Supabase.
      final token = await _repository.getSavedToken();

      if (token == null || token.isEmpty) {
        _showMessage(
          'Autentikasi biometrik berhasil, tetapi sesi tidak ditemukan. '
          'Silakan login dengan username/email dan password.',
        );
        return;
      }

      final user = await _repository.validateSession(token);

      if (user == null) {
        _showMessage(
          'Sesi Supabase tidak valid atau telah kedaluwarsa. '
          'Silakan login kembali dengan username/email dan password.',
        );
        return;
      }

      if (!mounted) return;

      await _openHome(user);
    } catch (error) {
      _showMessage(
        'Login biometrik gagal: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      // Logout manual tetap menonaktifkan fitur biometrik,
      // sesuai perilaku yang sudah ada pada proyek.
      await SecureStorageService.saveBiometricEnabled(false);
      await _repository.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      _showMessage(
        'Gagal logout: '
        '${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16856B);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.directions_run_rounded,
                    size: 76,
                    color: green,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gerak-in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mulai bergerak, jaga kesehatan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Selamat datang kembali!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _identifierController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username atau Email',
                      hintText: 'Masukkan username atau email',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username atau email wajib diisi.';
                      }

                      if (value.trim().contains(' ')) {
                        return 'Username atau email tidak boleh mengandung spasi.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password wajib diisi.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Masuk'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text('Lupa Password?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_biometricEnabled && _biometricAvailable)
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _loginWithBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 28),
                      label: const Text('Masuk dengan Biometrik'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: green),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: const Text('Belum punya akun? Daftar sekarang'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
