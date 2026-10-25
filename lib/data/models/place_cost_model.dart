// ============================================================================
// [PBI-11.8/11.9] Informasi biaya tempat olahraga (dari tabel server place_costs)
// ============================================================================
enum CostPeriod { visit, day, week, month }

extension CostPeriodX on CostPeriod {
  /// "Rp 150.000 per bulan"
  String get per => switch (this) {
        CostPeriod.visit => 'per kunjungan',
        CostPeriod.day => 'per hari',
        CostPeriod.week => 'per minggu',
        CostPeriod.month => 'per bulan',
      };

  /// Satuan untuk jumlah di kalkulator: "3 kunjungan".
  String get unit => switch (this) {
        CostPeriod.visit => 'kunjungan',
        CostPeriod.day => 'hari',
        CostPeriod.week => 'minggu',
        CostPeriod.month => 'bulan',
      };
}

CostPeriod parseCostPeriod(Object? value) {
  for (final p in CostPeriod.values) {
    if (p.name == value) return p;
  }
  return CostPeriod.month;
}

class PlaceCost {
  const PlaceCost({
    required this.priceIdr,
    this.period = CostPeriod.month,
    this.note,
  });

  final int priceIdr;
  final CostPeriod period;
  final String? note;

  /// null jika harga kosong atau tidak masuk akal.
  static PlaceCost? fromRow(Map<String, dynamic> row) {
    final price = (row['price_idr'] as num?)?.toInt();
    if (price == null || price <= 0) return null;
    final note = row['note']?.toString().trim();
    return PlaceCost(
      priceIdr: price,
      period: parseCostPeriod(row['period']),
      note: (note == null || note.isEmpty) ? null : note,
    );
  }
}

/// Kunci pencocokan nama: huruf kecil dan spasi dirapikan.
/// Harus sama dengan kolom `name_key` di tabel place_costs.
String nameKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');