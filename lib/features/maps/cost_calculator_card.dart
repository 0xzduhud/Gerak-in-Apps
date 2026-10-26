import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils/cost_calculator.dart';
import '../../data/models/place_cost_model.dart';
import '../../data/models/place_model.dart';
import '../../data/repositories/currency_repository.dart';
import '../../data/repositories/place_cost_repository.dart';

// [PBI-11.8] Kartu kalkulator biaya di halaman detail tempat. Data biaya dari
// tabel Supabase `place_costs`, kurs dari open.er-api.com (ada cache dan cadangan).
class CostCalculatorCard extends StatefulWidget {
  const CostCalculatorCard({
    super.key,
    required this.place,
    this.costs,
    this.currency,
  });

  final Place place;
  final PlaceCostRepository? costs;
  final CurrencyRepository? currency;

  @override
  State<CostCalculatorCard> createState() => _CostCalculatorCardState();
}

class _CostCalculatorCardState extends State<CostCalculatorCard> {
  PlaceCost? _cost;
  RatesResult? _rates;
  bool _loading = true;
  int _qty = 1;
  Currency _currency = Currency.idr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cost =
        await (widget.costs ?? PlaceCostRepository()).costFor(widget.place);
    RatesResult? rates;
    if (cost != null) {
      rates = await (widget.currency ?? CurrencyRepository()).getRates();
    }
    if (!mounted) return;
    setState(() {
      _cost = cost;
      _rates = rates;
      _loading = false;
    });
  }

  BoxDecoration get _box => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final cost = _cost;
    final rates = _rates;
    if (cost == null || rates == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: _box,
        child: const Row(
          children: [
            Icon(Icons.payments_outlined, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Info biaya belum tersedia untuk tempat ini.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final max = CostCalculator.maxQuantity(cost.period);
    final qty = CostCalculator.clampQuantity(cost.period, _qty);
    final total = CostCalculator.totalIdr(cost, qty);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Kalkulator biaya',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatMoney(cost.priceIdr.toDouble(), Currency.idr)} '
            '${cost.period.per}',
          ),
          if (cost.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                cost.note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: qty > 1 ? () => setState(() => _qty = qty - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$qty ${cost.period.unit}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed:
                    qty < max ? () => setState(() => _qty = qty + 1) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final c in Currency.values)
                ChoiceChip(
                  label: Text(c.code),
                  selected: _currency == c,
                  onSelected: (_) => setState(() => _currency = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total: ${CostCalculator.formatTotal(total, _currency, rates.table)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
          if (_currency != Currency.idr)
            Text(
              '= ${formatMoney(total.toDouble(), Currency.idr)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            CostCalculator.sourceLabel(rates.source),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}