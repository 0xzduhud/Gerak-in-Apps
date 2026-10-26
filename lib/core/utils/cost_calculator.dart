import '../../data/models/place_cost_model.dart';
import '../../data/repositories/currency_repository.dart';

// ============================================================================
// [PBI-11.8] CostCalculator — logika murni kalkulator biaya (mudah diuji)
// ============================================================================
class CostCalculator {
  CostCalculator._();

  /// Batas jumlah per satuan agar angka tetap masuk akal.
  static int maxQuantity(CostPeriod period) => switch (period) {
        CostPeriod.visit => 100,
        CostPeriod.day => 31,
        CostPeriod.week => 52,
        CostPeriod.month => 36,
      };

  /// Jumlah dipaksa masuk 1..maksimum.
  static int clampQuantity(CostPeriod period, int quantity) =>
      quantity.clamp(1, maxQuantity(period));

  /// Total dalam rupiah = harga x jumlah.
  static int totalIdr(PlaceCost cost, int quantity) =>
      cost.priceIdr * clampQuantity(cost.period, quantity);

  /// Total rupiah diubah ke mata uang pilihan lalu diformat.
  static String formatTotal(int totalIdr, Currency to, RateTable rates) {
    final amount = rates.convert(totalIdr.toDouble(), Currency.idr, to);
    return formatMoney(amount, to);
  }

  /// Keterangan asal kurs untuk ditampilkan ke pengguna.
  static String sourceLabel(RateSource source) => switch (source) {
        RateSource.live => 'Kurs terbaru (ExchangeRate-API)',
        RateSource.cache => 'Kurs tersimpan, masih baru (ExchangeRate-API)',
        RateSource.staleCache =>
          'Kurs lama tersimpan karena internet tidak tersedia',
        RateSource.fallback => 'Kurs perkiraan lokal (tanpa internet)',
      };
}