import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/repositories/geocoding_repository.dart';

// [PBI-11.4] Layar pencarian nama/area. Pencarian dijalankan saat pengguna
// menekan Enter (bukan tiap huruf) sesuai aturan Nominatim.
class PlaceSearchDelegate extends SearchDelegate<GeoResult?> {
  PlaceSearchDelegate({GeocodingRepository? repository})
      : _repo = repository ?? GeocodingRepository.shared,
        super(searchFieldLabel: 'Cari kota atau area');

  final GeocodingRepository _repo;
  Future<List<GeoResult>>? _future;
  String? _futureQuery;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: 'Kembali',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, null),
      );

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _message(
        'Ketik nama kota atau area (minimal 3 huruf), '
        'lalu tekan Enter atau ikon cari.',
      );

  @override
  Widget buildResults(BuildContext context) {
    final q = query.trim();
    if (q.length < GeocodingRepository.minQueryLength) {
      return _message('Ketik minimal 3 huruf.');
    }
    if (_futureQuery != q) {
      _futureQuery = q;
      _future = _repo.search(q);
    }
    return FutureBuilder<List<GeoResult>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _message('Pencarian gagal. Periksa koneksi internet.'),
                OutlinedButton(
                  onPressed: () {
                    _futureQuery = null;
                    showResults(context);
                  },
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        }
        final results = snapshot.data ?? const <GeoResult>[];
        if (results.isEmpty) {
          return _message('Tidak ada hasil untuk "$q". Coba nama lain.');
        }
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = results[i];
            return ListTile(
              leading: const Icon(Icons.place_rounded, color: AppColors.primary),
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: r.subtitle.isEmpty
                  ? null
                  : Text(r.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => close(context, r),
            );
          },
        );
      },
    );
  }
}