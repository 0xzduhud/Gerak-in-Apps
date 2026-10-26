// ============================================================================
// [PBI-12.x] TimezoneConverter — konversi zona waktu (tanpa paket tambahan)
// Hanya zona TANPA daylight saving (WIB/WITA/WIT dan beberapa kota Asia).
// Zona ber-DST (London, New York, Sydney) sengaja tidak dimasukkan.
// ============================================================================
class AppTimeZone {
  const AppTimeZone(this.code, this.name, this.offsetHours);

  final String code;
  final String name;
  final int offsetHours;

  Duration get offset => Duration(hours: offsetHours);

  String get utcLabel => offsetHours == 0
      ? 'UTC'
      : 'UTC${offsetHours > 0 ? '+' : ''}$offsetHours';
}

class ConvertedTime {
  const ConvertedTime(this.time, this.dayShift);

  /// Jam dinding (wall clock) di zona tujuan.
  final DateTime time;

  /// Selisih hari terhadap waktu asal: -1, 0, atau +1.
  final int dayShift;
}

class TimezoneConverter {
  TimezoneConverter._();

  static const AppTimeZone wib = AppTimeZone('WIB', 'Jakarta (WIB)', 7);
  static const AppTimeZone wita = AppTimeZone('WITA', 'Makassar (WITA)', 8);
  static const AppTimeZone wit = AppTimeZone('WIT', 'Jayapura (WIT)', 9);
  static const AppTimeZone singapore = AppTimeZone('SGT', 'Singapura', 8);
  static const AppTimeZone tokyo = AppTimeZone('JST', 'Tokyo', 9);
  static const AppTimeZone dubai = AppTimeZone('GST', 'Dubai', 4);
  static const AppTimeZone utc = AppTimeZone('UTC', 'UTC', 0);

  static const List<AppTimeZone> all = [
    wib,
    wita,
    wit,
    singapore,
    tokyo,
    dubai,
    utc,
  ];

  /// Kode tidak dikenal -> WIB.
  static AppTimeZone byCode(String? code) =>
      all.firstWhere((z) => z.code == code, orElse: () => wib);

  /// Jam dinding di [zone] -> waktu UTC.
  static DateTime toUtc(DateTime wall, AppTimeZone zone) {
    return DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute)
        .subtract(zone.offset);
  }

  /// Waktu UTC -> jam dinding di [zone] (dibungkus DateTime.utc hanya sebagai
  /// penampung angka; jangan dipakai untuk perhitungan instan).
  static DateTime fromUtc(DateTime utc, AppTimeZone zone) {
    final u = utc.toUtc().add(zone.offset);
    return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute);
  }

  static ConvertedTime convert(
    DateTime wall,
    AppTimeZone from,
    AppTimeZone to,
  ) {
    final result = fromUtc(toUtc(wall, from), to);
    final shift = DateTime.utc(result.year, result.month, result.day)
        .difference(DateTime.utc(wall.year, wall.month, wall.day))
        .inDays;
    return ConvertedTime(result, shift);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static const List<String> _days = [
    'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
  ];
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Contoh: "Sen, 3 Nov 2026".
  static String formatDate(DateTime t) =>
      '${_days[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]} ${t.year}';

  static String dayShiftLabel(int shift) {
    if (shift == 0) return '';
    return shift > 0 ? '+$shift hari' : '$shift hari';
  }
}