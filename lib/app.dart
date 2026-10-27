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

class GerakInApp extends StatefulWidget {
  const GerakInApp({super.key});

  @override
  State<GerakInApp> createState() => _GerakInAppState();
}

class _GerakInAppState extends State<GerakInApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  static const Duration _loginTimeout = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      debugPrint('[LIFECYCLE] Aplikasi berada di latar belakang.');
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  void _handleAppResumed() {
    final backgroundedAt = _backgroundedAt;

    if (backgroundedAt == null) return;

    // Reset waktu agar satu periode di latar belakang
    // hanya diperiksa satu kali.
    _backgroundedAt = null;

    final elapsed = DateTime.now().difference(backgroundedAt);

    debugPrint(
      '[LIFECYCLE] Durasi di latar belakang: '
      '${elapsed.inSeconds} detik.',
    );

    if (elapsed < _loginTimeout) {
      debugPrint('[LIFECYCLE] Belum 10 menit, sesi tetap dilanjutkan.');
      return;
    }

    debugPrint('[LIFECYCLE] Sudah 10 menit, arahkan pengguna ke Login.');

    // Tunggu sampai navigator tersedia.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = rootNavigatorKey.currentState;

      if (navigator == null || !navigator.mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  }

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

      // Pertahankan pemeriksaan proses aplikasi sebelumnya.
      final previousProcess = await SecureStorageService.wasAppProcessStarted();

      await SecureStorageService.markAppProcessStarted();

      if (!mounted) return;

      // Jika aplikasi dimulai ulang, arahkan ke Login.
      if (previousProcess) {
        _goToLogin();
        return;
      }

      // Pada proses pertama, periksa sesi yang tersedia.
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
