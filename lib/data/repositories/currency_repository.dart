import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// [PBI-11.7] Kurs IDR / USD / EUR
// Sumber: open.er-api.com (gratis, tanpa kunci API, update sekali sehari,
// wajib mencantumkan atribusi ke ExchangeRate-API). Cadangan: kurs tersimpan,
// lalu tabel kurs lokal di bawah.
// ============================================================================
enum Currency {
  idr('IDR', 'Rp', 'Rupiah'),
  usd('USD', 'US\$', 'Dolar AS'),
  eur('EUR', '€', 'Euro');

  const Currency(this.code, this.symbol, this.label);

  final String code;
  final String symbol;
  final String label;
}

/// Asal kurs yang sedang dipakai.
enum RateSource { live, cache, staleCache, fallback }

/// Kurs terhadap 1 USD. Konversi lewat USD sebagai penghubung.
class RateTable {
  const RateTable(this.perUsd, this.date);

  /// Tabel kurs lokal (perkiraan) saat tidak ada internet dan tidak ada cache.
  /// Perbarui nilainya sesekali.
  static const RateTable fallback = RateTable(
    {Currency.usd: 1.0, Currency.idr: 16300.0, Currency.eur: 0.86},
    null,
  );

  final Map<Currency, double> perUsd;

  /// Kapan kurs diambil. null = tabel lokal.
  final DateTime? date;

  double convert(double amount, Currency from, Currency to) =>
      amount / perUsd[from]! * perUsd[to]!;

  double rate(Currency from, Currency to) => convert(1, from, to);
}

class RatesResult {
  const RatesResult(this.table, this.source);

  final RateTable table;
  final RateSource source;
}

/// Mengurai jawaban open.er-api.com. null jika bukan jawaban sukses atau
/// salah satu mata uang yang dibutuhkan hilang/tidak masuk akal.
Map<Currency, double>? parseRates(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['result'] != 'success') return null;
    final rates = decoded['rates'];
    if (rates is! Map) return null;
    final out = <Currency, double>{};
    for (final c in Currency.values) {
      final v = (rates[c.code] as num?)?.toDouble();
      if (v == null || v <= 0 || v.isNaN || v.isInfinite) return null;
      out[c] = v;
    }
    return out;
  } catch (_) {
    return null;
  }
}

String _group(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// IDR: "Rp 150.000"  •  USD: "US$ 9,38"  •  EUR: "€ 8,07"
String formatMoney(double amount, Currency currency) {
  if (currency == Currency.idr) return 'Rp ${_group(amount.round())}';
  final cents = (amount * 100).round();
  final frac = (cents.abs() % 100).toString().padLeft(2, '0');
  return '${currency.symbol} ${_group(cents ~/ 100)},$frac';
}

abstract class RateStore {
  Future<RateTable?> read();
  Future<void> write(RateTable table);
}

class MemoryRateStore implements RateStore {
  RateTable? _table;

  @override
  Future<RateTable?> read() async => _table;

  @override
  Future<void> write(RateTable table) async => _table = table;
}

/// Cache tahan restart aplikasi (shared_preferences; jalan di HP dan web).
class PrefsRateStore implements RateStore {
  static const String _key = 'currency_rates_v1';

  @override
  Future<RateTable?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final t = (j['t'] as num?)?.toInt();
      final r = j['rates'];
      if (t == null || r is! Map) return null;
      final perUsd = <Currency, double>{};
      for (final c in Currency.values) {
        final v = (r[c.code] as num?)?.toDouble();
        if (v == null || v <= 0) return null;
        perUsd[c] = v;
      }
      return RateTable(perUsd, DateTime.fromMillisecondsSinceEpoch(t));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(RateTable table) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        't': (table.date ?? DateTime.now()).millisecondsSinceEpoch,
        'rates': {for (final e in table.perUsd.entries) e.key.code: e.value},
      }),
    );
  }
}

typedef RatesFetcher = Future<String> Function();

class CurrencyRepository {
  CurrencyRepository({
    RatesFetcher? fetcher,
    RateStore? store,
    DateTime Function()? now,
  })  : _fetcher = fetcher ?? _fetchFromApi,
        _store = store ?? PrefsRateStore(),
        _now = now ?? DateTime.now;

  /// Sumber memperbarui kurs sekali sehari dan membatasi laju permintaan
  /// (HTTP 429), jadi kurs disimpan 12 jam.
  static const Duration cacheTtl = Duration(hours: 12);
  static const String _endpoint = 'https://open.er-api.com/v6/latest/USD';

  final RatesFetcher _fetcher;
  final RateStore _store;
  final DateTime Function() _now;

  static Future<String> _fetchFromApi() async {
    final response =
        await http.get(Uri.parse(_endpoint)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} dari open.er-api.com');
    }
    return utf8.decode(response.bodyBytes);
  }

  /// Selalu mengembalikan kurs yang bisa dipakai: terbaru, tersimpan, atau
  /// tabel lokal. [force] = abaikan cache yang masih segar.
  Future<RatesResult> getRates({bool force = false}) async {
    RateTable? cached;
    try {
      cached = await _store.read();
    } catch (_) {}

    final date = cached?.date;
    final fresh = cached != null &&
        date != null &&
        _now().difference(date) < cacheTtl;
    if (fresh && !force) return RatesResult(cached, RateSource.cache);

    try {
      final rates = parseRates(await _fetcher());
      if (rates == null) throw const FormatException('Jawaban kurs tidak valid');
      final table = RateTable(rates, _now());
      try {
        await _store.write(table);
      } catch (e) {
        debugPrint('Gagal menyimpan kurs: $e');
      }
      return RatesResult(table, RateSource.live);
    } catch (e) {
      debugPrint('Gagal mengambil kurs: $e');
      if (cached != null) return RatesResult(cached, RateSource.staleCache);
      return const RatesResult(RateTable.fallback, RateSource.fallback);
    }
  }
}