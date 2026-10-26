import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
// ignore: unused_import
import 'features/premium/subscription_provider.dart';
import 'features/auth/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // PBI-8.5: port komunikasi UI <-> layanan latar belakang.
  if (!kIsWeb) FlutterForegroundTask.initCommunicationPort();

  String errorMessage = 'Penyebab tidak diketahui.';

  try {
    await dotenv.load(fileName: '.env');

    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
    final supabaseKey = dotenv.env['SUPABASE_KEY']?.trim();

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      throw Exception(
        'SUPABASE_URL tidak ditemukan. Periksa nama variabel di file .env.',
      );
    }

    if (supabaseKey == null || supabaseKey.isEmpty) {
      throw Exception(
        'SUPABASE_KEY tidak ditemukan. Periksa nama variabel di file .env.',
      );
    }

    if (!supabaseUrl.startsWith('https://')) {
      throw Exception(
        'SUPABASE_URL harus menggunakan alamat HTTPS yang benar.',
      );
    }

    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Log diagnostik tetap dipertahankan.
      debugPrint('AUTH EVENT: ${data.event}');
      debugPrint(
        'SESSION: ${data.session != null ? "tersedia" : "tidak tersedia"}',
      );

      // Tambahan: navigasi khusus untuk pemulihan password.
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Event passwordRecovery diterima.');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = rootNavigatorKey.currentState;

          if (navigator == null) {
            debugPrint('Navigator belum tersedia untuk membuka halaman reset.');
            return;
          }

          navigator.pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => const ResetPasswordScreen(),
            ),
            (route) => false,
          );
        });
      }
    });

    runApp(const GerakInApp());
  } catch (error, stackTrace) {
    errorMessage = error.toString();

    debugPrint('========== GERAK-IN ERROR ==========');
    debugPrint('Penyebab: $error');
    debugPrintStack(stackTrace: stackTrace);
    debugPrint('====================================');

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Gerak-in - Error')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Aplikasi gagal dijalankan',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Detail error:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(errorMessage),
                  const SizedBox(height: 20),
                  const Text(
                    'Periksa detail di atas dan terminal VS Code '
                    'untuk mengetahui penyebabnya.',
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
