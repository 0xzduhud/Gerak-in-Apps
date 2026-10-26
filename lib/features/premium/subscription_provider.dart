import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [SubscriptionProvider] - Pengelola state langganan FitMate Plus.
///
/// Status dimuat otomatis saat pengguna login dan dikosongkan saat logout.
/// Aktivasi langganan dilakukan oleh Edge Function `subscriptions`,
/// bukan langsung dari aplikasi.
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        switch (data.event) {
          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.signedIn:
            if (data.session != null) {
              checkSubscriptionStatus();
            } else {
              clear();
            }
          case AuthChangeEvent.signedOut:
            clear();
          default:
            break;
        }
      },
      onError: (Object error) {
        debugPrint('SubscriptionProvider: kesalahan sesi: $error');
      },
    );
  }

  StreamSubscription<AuthState>? _authSubscription;
  bool _disposed = false;

  /// Status fitur premium pengguna.
  bool isPremium = false;

  /// Tanggal berakhir langganan aktif (null jika Free).
  DateTime? expiresAt;

  /// Status loading saat pembayaran atau reset berjalan.
  bool isLoading = false;

  /// Metode pembayaran yang dipilih.
  String selectedPaymentMethod = 'Kartu Kredit / Debit';

  /// Daftar pilihan metode pembayaran.
  final List<String> paymentMethods = [
    'Kartu Kredit / Debit',
    'Transfer Bank (VA)',
    'E-Wallet / QRIS',
    'Minimarket',
  ];

  /// Mengubah metode pembayaran yang dipilih dan memberitahu listeners.
  void setPaymentMethod(String method) {
    selectedPaymentMethod = method;
    notifyListeners();
  }

  /// Mata uang yang dipilih, default 'IDR'.
  String selectedCurrency = 'IDR';

  /// Harga dasar dalam IDR (Rp 150.000,00).
  static const double basePriceIdr = 150000.0;

  /// Map nilai tukar statis ke IDR. Harus sama dengan di Edge Function.
  static const Map<String, double> exchangeRates = {
    'IDR': 1.0,
    'USD': 15500.0,
    'EUR': 16800.0,
  };

  /// Mengubah mata uang yang dipilih dan memberitahu listeners.
  void setCurrency(String currency) {
    if (exchangeRates.containsKey(currency)) {
      selectedCurrency = currency;
      notifyListeners();
    }
  }

  /// Menghitung harga saat ini sesuai mata uang yang dipilih.
  double get currentPrice {
    final rate = exchangeRates[selectedCurrency] ?? 1.0;
    return basePriceIdr / rate;
  }

  /// Mengembalikan harga terformat (Rp, $, atau €) sesuai mata uang.
  String get formattedPrice {
    switch (selectedCurrency) {
      case 'IDR':
        final formattedNumber = currentPrice
            .toInt()
            .toString()
            .replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]}.',
            );
        return 'Rp $formattedNumber';
      case 'USD':
        return '\$${currentPrice.toStringAsFixed(2)}';
      case 'EUR':
        return '€${currentPrice.toStringAsFixed(2)}';
      default:
        return '$selectedCurrency ${currentPrice.toStringAsFixed(2)}';
    }
  }

  /// Memuat status langganan dari server.
  Future<void> checkSubscriptionStatus() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      clear();
      return;
    }

    try {
      final data = await _call({'action': 'status'});
      _applyStatus(data);
    } catch (e) {
      // Gagal memuat: pertahankan status yang sudah diketahui.
      debugPrint('Error checkSubscriptionStatus: $e');
    }
  }

  /// Mengosongkan status (dipanggil saat logout atau ganti akun).
  void clear() {
    isPremium = false;
    expiresAt = null;
    notifyListeners();
  }

  /// Pembayaran simulasi: server menghitung harga, mencatat pembayaran,
  /// lalu mengaktifkan atau memperpanjang langganan.
  Future<void> simulatePayment() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      throw Exception('Sesi pengguna tidak valid atau belum login.');
    }
    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    try {
      final data = await _call({
        'action': 'activate',
        'currency': selectedCurrency,
      });
      _applyStatus(data);
    } catch (e) {
      debugPrint('Error simulatePayment: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Mengembalikan akun ke status Free. Khusus untuk keperluan demo.
  Future<void> resetForDemo() async {
    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    try {
      final data = await _call({'action': 'reset'});
      _applyStatus(data);
    } catch (e) {
      debugPrint('Error resetForDemo: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _applyStatus(Map<String, dynamic> data) {
    final subscription = data['subscription'];
    isPremium = data['is_premium'] == true;
    expiresAt = (subscription is Map && subscription['expires_at'] != null)
        ? DateTime.tryParse(subscription['expires_at'].toString())?.toLocal()
        : null;
    notifyListeners();
  }

  /// Memanggil Edge Function `subscriptions`. Error dilempar sebagai
  /// Exception dengan pesan yang aman ditampilkan ke pengguna.
  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    dynamic data;

    try {
      final response = await Supabase.instance.client.functions
          .invoke('subscriptions', body: body)
          .timeout(const Duration(seconds: 20));
      data = response.data;
    } on FunctionException catch (error) {
      throw Exception(
        _messageFrom(error.details) ??
            'Server sedang bermasalah (${error.status}). Coba lagi nanti.',
      );
    } on TimeoutException {
      throw Exception('Server terlalu lama merespons. Coba lagi.');
    } catch (_) {
      throw Exception(
        'Tidak dapat terhubung ke server. Periksa koneksi internetmu.',
      );
    }

    if (data is Map && data['success'] == true) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception(_messageFrom(data) ?? 'Respons server tidak valid.');
  }

  String? _messageFrom(dynamic details) {
    if (details is Map && details['message'] is String) {
      final text = (details['message'] as String).trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  // Proses async bisa selesai setelah provider dibuang. Setelah dispose,
  // notifikasi diabaikan supaya tidak error.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
