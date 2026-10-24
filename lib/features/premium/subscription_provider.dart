import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [SubscriptionProvider] - Pengelola state langganan FitMate Plus dan integrasi Supabase.
class SubscriptionProvider extends ChangeNotifier {
  /// Status fitur premium pengguna.
  bool isPremium = false;

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

  /// Memeriksa status langganan aktif pengguna di Supabase.
  Future<void> checkSubscriptionStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      isPremium = false;
      notifyListeners();
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('expires_at', DateTime.now().toIso8601String())
          .limit(1);

      isPremium = response.isNotEmpty;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checkSubscriptionStatus: $e');
      isPremium = false;
      notifyListeners();
    }
  }

  /// Status loading saat pembayaran disimulasikan.
  bool isLoading = false;

  /// Mata uang yang dipilih, default 'IDR'.
  String selectedCurrency = 'IDR';

  /// Harga dasar dalam IDR (Rp 150.000,00).
  static const double basePriceIdr = 150000.0;

  /// Map nilai tukar statis ke IDR.
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

  /// Menyimulasikan proses pembayaran langganan ke Supabase.
  Future<void> simulatePayment() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Sesi pengguna tidak valid atau belum login.');
    }

    isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 30));

      // 1. Insert ke tabel subscriptions
      final subRes = await Supabase.instance.client
          .from('subscriptions')
          .insert({
            'user_id': userId,
            'plan': 'Plus',
            'status': 'active',
            'started_at': now.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
          })
          .select()
          .single();

      final subscriptionId = subRes['id'];

      // 2. Insert ke tabel payments
      await Supabase.instance.client.from('payments').insert({
        'user_id': userId,
        'subscription_id': subscriptionId,
        'currency': selectedCurrency,
        'amount': currentPrice,
        'rate_to_idr': exchangeRates[selectedCurrency] ?? 1.0,
        'status': 'success',
      });

      isPremium = true;
    } catch (e) {
      debugPrint('Error simulatePayment Supabase: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
