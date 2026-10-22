import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/community/community_provider.dart';
import 'features/games/game_provider.dart';
import 'features/home/home_screen.dart';

class GerakInApp extends StatelessWidget {
  const GerakInApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFE86524);
    const secondary = Color(0xFFF09557);
    const tertiary = Color(0xFFEE2D11);
    const background = Color(0xFF171312);
    const surface = Color(0xFF241F1D);
    const foreground = Color(0xFFF5E9E4);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
      ],
      child: MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          tertiary: tertiary,
          surface: surface,
          onPrimary: Color(0xFF24110A),
          onSecondary: Color(0xFF24110A),
          onTertiary: Colors.white,
          onSurface: foreground,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: foreground,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          labelStyle: const TextStyle(color: secondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF514744)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: const Color(0xFF24110A),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
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
              color: Color(0xFFE86524),
            ),
            SizedBox(height: 20),
            Text(
              'Gerak-in',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF5E9E4),
              ),
            ),
            SizedBox(height: 8),
            Text('Mulai bergerak, jaga kesehatan.'),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFFE86524)),
          ],
        ),
      ),
    );
  }
}
