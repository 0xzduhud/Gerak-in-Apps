import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/services/secure_storage_service.dart';
import 'core/theme.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/community/community_provider.dart';
import 'features/games/game_provider.dart';
import 'features/home/home_screen.dart';

// Navigator utama agar halaman dapat dibuka dari event autentikasi.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class GerakInApp extends StatelessWidget {
  const GerakInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
      ),
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
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _checkingSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    if (_checkingSession) return;
    _checkingSession = true;

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null || session.accessToken.isEmpty) {
        _goToLogin();
        return;
      }

      final user = await _repository.validateSession(session.accessToken);

      if (!mounted) return;

      if (user == null) {
        _goToLogin();
        return;
      }

      final biometricEnabled = await SecureStorageService.isBiometricEnabled();

      if (!mounted) return;

      if (biometricEnabled) {
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();

        if (!mounted) return;

        if (!canCheckBiometrics && !isDeviceSupported) {
          _goToLogin();
          return;
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verifikasi identitas untuk membuka Gerak-in',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (!mounted) return;

        if (!authenticated) {
          _goToLogin();
          return;
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(
            user: user,
            repository: _repository,
            onLogout: _logout,
          ),
        ),
      );
    } on AuthException catch (error) {
      debugPrint('Sesi Supabase bermasalah: ${error.message}');
      if (mounted) _goToLogin();
    } catch (error, stackTrace) {
      debugPrint('Gagal memulihkan sesi: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) _goToLogin();
    }
  }

  Future<void> _logout() async {
    try {
      await SecureStorageService.saveBiometricEnabled(false);
      await _repository.logout();
    } catch (error) {
      debugPrint('Gagal logout: $error');
    }
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
