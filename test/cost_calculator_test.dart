import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/core/utils/cost_calculator.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/models/place_cost_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/models/place_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/currency_repository.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/place_cost_repository.dart';

class _FakeSource implements PlaceCostSource {
  _FakeSource({this.byId, this.byName, this.throws = false});

  final PlaceCost? byId;
  final PlaceCost? byName;
  final bool throws;

  @override
  Future<PlaceCost?> byOsmId(String osmId) async {
    if (throws) throw Exception('server mati');
    return byId;
  }

  @override
  Future<PlaceCost?> byNameKey(String key) async {
    if (throws) throw Exception('server mati');
    return byName;
  }
}

const _body =
    '{"result":"success","rates":{"USD":1,"IDR":16300,"EUR":0.86}}';

void main() {
  const monthly = PlaceCost(priceIdr: 150000, period: CostPeriod.month);

  group('PBI-11.8 CostCalculator', () {
    test('total = harga x jumlah', () {
      expect(CostCalculator.totalIdr(monthly, 3), 450000);
    });

    test('jumlah di bawah 1 dipaksa jadi 1', () {
      expect(CostCalculator.clampQuantity(CostPeriod.month, 0), 1);
      expect(CostCalculator.clampQuantity(CostPeriod.month, -5), 1);
      expect(CostCalculator.totalIdr(monthly, 0), 150000);
    });

    test('jumlah di atas batas dipaksa ke batas', () {
      expect(CostCalculator.maxQuantity(CostPeriod.visit), 100);
      expect(CostCalculator.maxQuantity(CostPeriod.day), 31);
      expect(CostCalculator.maxQuantity(CostPeriod.week), 52);
      expect(CostCalculator.maxQuantity(CostPeriod.month), 36);
      expect(CostCalculator.clampQuantity(CostPeriod.day, 999), 31);
    });

    test('format total ke rupiah, dolar, euro (kurs lokal)', () {
      const t = RateTable.fallback; // 1 USD = 16.300 IDR = 0,86 EUR
      expect(CostCalculator.formatTotal(163000, Currency.idr, t), 'Rp 163.000');
      expect(CostCalculator.formatTotal(163000, Currency.usd, t), 'US\$ 10,00');
      expect(CostCalculator.formatTotal(163000, Currency.eur, t), '€ 8,60');
    });

    test('keterangan asal kurs berbeda untuk tiap sumber', () {
      final labels = RateSource.values.map(CostCalculator.sourceLabel).toSet();
      expect(labels.length, RateSource.values.length);
    });
  });

  group('PBI-11.8 PlaceCost dan nameKey', () {
    test('baris valid', () {
      final c = PlaceCost.fromRow({
        'price_idr': 75000,
        'period': 'week',
        'note': '  Termasuk handuk  ',
      });
      expect(c, isNotNull);
      expect(c!.priceIdr, 75000);
      expect(c.period, CostPeriod.week);
      expect(c.note, 'Termasuk handuk');
    });

    test('harga kosong, nol, atau negatif -> null', () {
      expect(PlaceCost.fromRow({'price_idr': null}), isNull);
      expect(PlaceCost.fromRow({'price_idr': 0}), isNull);
      expect(PlaceCost.fromRow({'price_idr': -1}), isNull);
    });

    test('periode tidak dikenal -> bulan; catatan kosong -> null', () {
      final c = PlaceCost.fromRow({
        'price_idr': 1000,
        'period': 'tahun',
        'note': '   ',
      });
      expect(c!.period, CostPeriod.month);
      expect(c.note, isNull);
    });

    test('teks satuan', () {
      expect(CostPeriod.visit.per, 'per kunjungan');
      expect(CostPeriod.month.unit, 'bulan');
    });

    test('nameKey merapikan huruf dan spasi', () {
      expect(nameKey('  Gym   Satu  FIT '), 'gym satu fit');
      expect(nameKey('Taman'), 'taman');
    });
  });

  group('PBI-11.9 PlaceCostRepository', () {
    const place = Place(
      id: 'node/1',
      name: 'Gym  Satu',
      type: PlaceType.gym,
      lat: 0,
      lng: 0,
    );
    const other = PlaceCost(priceIdr: 99000);

    test('cocok lewat id OSM lebih dulu', () async {
      final repo = PlaceCostRepository(
        source: _FakeSource(byId: monthly, byName: other),
      );
      expect((await repo.costFor(place))!.priceIdr, 150000);
    });

    test('jika id tidak ada, pakai nama', () async {
      final repo = PlaceCostRepository(source: _FakeSource(byName: other));
      expect((await repo.costFor(place))!.priceIdr, 99000);
    });

    test('tidak ada data -> null', () async {
      final repo = PlaceCostRepository(source: _FakeSource());
      expect(await repo.costFor(place), isNull);
    });

    test('server gagal -> null, tidak melempar error', () async {
      final repo = PlaceCostRepository(source: _FakeSource(throws: true));
      expect(await repo.costFor(place), isNull);
    });
  });

  group('PBI-11.7 kurs dan format', () {
    test('formatMoney', () {
      expect(formatMoney(150000, Currency.idr), 'Rp 150.000');
      expect(formatMoney(1500000, Currency.idr), 'Rp 1.500.000');
      expect(formatMoney(0, Currency.idr), 'Rp 0');
      expect(formatMoney(9.375, Currency.usd), 'US\$ 9,38');
      expect(formatMoney(8, Currency.eur), '€ 8,00');
    });

    test('RateTable.convert dan rate', () {
      const t = RateTable.fallback;
      expect(t.convert(16300, Currency.idr, Currency.usd), closeTo(1.0, 1e-9));
      expect(t.rate(Currency.usd, Currency.idr), closeTo(16300, 1e-6));
      expect(t.convert(5, Currency.usd, Currency.usd), closeTo(5, 1e-9));
    });

    test('parseRates: jawaban valid', () {
      final r = parseRates(_body);
      expect(r, isNotNull);
      expect(r![Currency.idr], 16300);
    });

    test('parseRates: jawaban rusak -> null', () {
      expect(parseRates('bukan json'), isNull);
      expect(parseRates('{"result":"error"}'), isNull);
      expect(
        parseRates('{"result":"success","rates":{"USD":1,"IDR":16300}}'),
        isNull,
      );
      expect(
        parseRates('{"result":"success","rates":{"USD":1,"IDR":-1,"EUR":1}}'),
        isNull,
      );
    });
  });

  group('PBI-11.7 CurrencyRepository', () {
    late DateTime now;
    late int calls;

    CurrencyRepository build({required Future<String> Function() fetch}) =>
        CurrencyRepository(
          fetcher: () {
            calls++;
            return fetch();
          },
          store: MemoryRateStore(),
          now: () => now,
        );

    setUp(() {
      now = DateTime(2026, 11, 3, 10);
      calls = 0;
    });

    test('ambil dari internet lalu pakai cache selama 12 jam', () async {
      final repo = build(fetch: () async => _body);
      expect((await repo.getRates()).source, RateSource.live);
      expect((await repo.getRates()).source, RateSource.cache);
      expect(calls, 1);
    });

    test('cache kedaluwarsa -> ambil lagi', () async {
      final repo = build(fetch: () async => _body);
      await repo.getRates();
      now = now.add(const Duration(hours: 13));
      expect((await repo.getRates()).source, RateSource.live);
      expect(calls, 2);
    });

    test('force mengabaikan cache', () async {
      final repo = build(fetch: () async => _body);
      await repo.getRates();
      expect((await repo.getRates(force: true)).source, RateSource.live);
      expect(calls, 2);
    });

    test('internet gagal, ada cache lama -> staleCache', () async {
      var fail = false;
      final repo = build(fetch: () async {
        if (fail) throw Exception('offline');
        return _body;
      });
      await repo.getRates();
      now = now.add(const Duration(hours: 20));
      fail = true;
      expect((await repo.getRates()).source, RateSource.staleCache);
    });

    test('internet gagal, tanpa cache -> tabel lokal', () async {
      final repo = build(fetch: () async => throw Exception('offline'));
      final r = await repo.getRates();
      expect(r.source, RateSource.fallback);
      expect(r.table.perUsd[Currency.idr], 16300);
    });

    test('jawaban tidak valid dianggap gagal', () async {
      final repo = build(fetch: () async => '{"result":"error"}');
      expect((await repo.getRates()).source, RateSource.fallback);
    });
  });
}