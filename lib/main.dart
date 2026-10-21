import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
