import 'package:flutter/material.dart';
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
import 'features/premium/subscription_provider.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class GerakInApp extends StatelessWidget {
  const GerakInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
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

  bool _checkingSession = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    if (_checkingSession || _navigated) return;

    _checkingSession = true;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Periksa apakah proses aplikasi pernah berjalan.
      final previousProcess = await SecureStorageService.wasAppProcessStarted();

      // Tandai proses aplikasi yang sedang berjalan.
      await SecureStorageService.markAppProcessStarted();

      if (!mounted) return;

      // Proses aplikasi dimulai ulang: wajib melalui halaman Login.
      // LoginScreen menentukan apakah biometrik perlu ditampilkan.
      if (previousProcess) {
        _goToLogin();
        return;
      }

      // Pada proses pertama, pulihkan sesi yang masih valid.
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

      _navigated = true;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(
            user: user,
            repository: _repository,
            onLogout: _logout,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[SPLASH] Gagal memeriksa sesi: $error');
      debugPrintStack(stackTrace: stackTrace);

      _goToLogin();
    }
  }

  Future<void> _logout() async {
    try {
      await _repository.logout();
    } catch (error) {
      debugPrint('[SPLASH] Gagal logout: $error');
    }
  }

  void _goToLogin() {
    if (!mounted || _navigated) return;

    _navigated = true;

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
