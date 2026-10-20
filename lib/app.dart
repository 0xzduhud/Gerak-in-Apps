import 'package:flutter/material.dart';

import 'data/repositories/auth_repository.dart';
import 'features/auth/login_screen.dart';

class GerakInApp extends StatelessWidget {
  const GerakInApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF16856B);
    const backgroundColor = Color(0xFFF5F8F6);
    const textColor = Color(0xFF19332D);

    return MaterialApp(
      title: 'Gerak-in',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          centerTitle: false,
        ),
      ),
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
  final _repository = AuthRepository();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Token yang tersimpan diperiksa keberadaannya.
    // Validasi token ke server akan ditambahkan saat endpoint profil dibuat.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // Belum ada endpoint untuk memvalidasi sesi atau mengambil profil.
    // Karena itu, untuk sementara selalu mulai dari halaman login.
    await _repository.getSavedToken();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16856B);

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_run_rounded, size: 76, color: green),
            SizedBox(height: 20),
            Text(
              'Gerak-in',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF19332D),
              ),
            ),
            SizedBox(height: 8),
            Text('Mulai bergerak, jaga kesehatan.'),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
