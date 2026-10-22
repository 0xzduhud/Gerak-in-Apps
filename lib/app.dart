import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

class GerakInApp extends StatelessWidget {
  const GerakInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthRepository _repository = AuthRepository();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    String? token;

    try {
      token = await _repository.getSavedToken();
    } catch (_) {
      token = null;
    }

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      try {
        final user = await _repository.validateSession(token);

        if (!mounted) return;

        if (user != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => HomeScreen(
                user: user,
                repository: _repository,
                onLogout: () async {
                  await _repository.logout();
                },
              ),
            ),
          );
          return;
        }
      } catch (error) {
        debugPrint('Gagal memvalidasi sesi: $error');
      }
    }

    if (!mounted) return;

    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_run_rounded,
              size: 76,
              color: AppColors.primary,
            ),
            SizedBox(height: 20),
            Text(
              'Gerak-in',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text('Mulai bergerak, jaga kesehatan.'),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}