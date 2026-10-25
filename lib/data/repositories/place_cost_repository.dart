import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_cost_model.dart';
import '../models/place_model.dart';

// ============================================================================
// [PBI-11.8/11.9] Mengambil biaya tempat dari tabel Supabase `place_costs`
// ============================================================================
abstract class PlaceCostSource {
  Future<PlaceCost?> byOsmId(String osmId);
  Future<PlaceCost?> byNameKey(String key);
}

class SupabasePlaceCostSource implements PlaceCostSource {
  // Diakses saat dipakai (bukan saat dibuat) supaya aman dalam pengujian.
  SupabaseClient get _client => Supabase.instance.client;

  Future<PlaceCost?> _first(String column, String value) async {
    final rows = await _client
        .from('place_costs')
        .select('price_idr, period, note')
        .eq(column, value)
        .limit(1);
    if (rows.isEmpty) return null;
    return PlaceCost.fromRow(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<PlaceCost?> byOsmId(String osmId) => _first('osm_id', osmId);

  @override
  Future<PlaceCost?> byNameKey(String key) => _first('name_key', key);
}

class PlaceCostRepository {
  PlaceCostRepository({PlaceCostSource? source})
      : _source = source ?? SupabasePlaceCostSource();

  final PlaceCostSource _source;

  /// Biaya tempat, atau null jika tidak ada datanya (atau server gagal
  /// dihubungi; kalkulator memang hanya tampil jika info biaya tersedia).
  Future<PlaceCost?> costFor(Place place) async {
    try {
      return await _source.byOsmId(place.id) ??
          await _source.byNameKey(nameKey(place.name));
    } catch (e) {
      debugPrint('Gagal memuat biaya tempat: $e');
      return null;
    }
  }
}