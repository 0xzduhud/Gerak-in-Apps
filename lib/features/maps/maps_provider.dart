import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/geolocator_gateway.dart';
import '../../core/services/location_service.dart';
import '../../data/models/place_model.dart';
import '../../data/repositories/geocoding_repository.dart';
import '../../data/repositories/place_repository.dart';

// [PBI-11.1/11.2] State lokasi pengguna untuk tab Maps.
// [PBI-11.3/11.5] State daftar tempat olahraga terdekat.
// [PBI-11.4] Pusat pencarian bisa dipindah ke area hasil pencarian nama.
class MapsProvider extends ChangeNotifier {
  MapsProvider({LocationService? location, PlaceRepository? places})
      : _location = location ?? LocationService(GeolocatorGateway()),
        _places = places ?? PlaceRepository();

  /// Radius dicoba berurutan sampai ada hasil (kota kecil datanya sedikit).
  static const List<int> _radii = [3000, 8000, 15000];

  static bool _isEnough(List<Place> places) =>
      places.length >= 10 &&
      places.where((p) => p.type == PlaceType.gym).length >= 3;
  final LocationService _location;
  final PlaceRepository _places;

  LocationResult? _result;
  bool _locating = false;
  bool _disposed = false;

  GeoPoint? _center; // null = pakai lokasi pengguna
  String? _searchLabel;
  int _radius = 3000;

  List<Place> _all = const [];
  PlaceType? _filter;
  Place? _selected;
  bool _loadingPlaces = false;
  bool _reloadRequested = false;
  bool _stale = false;
  bool _fromFallback = false;
  String? _placesError;
  String? _placesErrorDetail;

  bool get locating => _locating;
  LocationStatus? get status => _result?.status;
  GeoPoint? get user => _result?.point;

  /// Pusat pencarian tempat: hasil pencarian nama, atau lokasi pengguna.
  GeoPoint? get center => _center ?? user;
  bool get hasCenter => center != null;

  /// Pusat hasil pencarian nama (null jika memakai lokasi pengguna).
  GeoPoint? get searchCenter => _center;
  String? get searchLabel => _searchLabel;
  int get radiusKm => _radius ~/ 1000;

  bool get loadingPlaces => _loadingPlaces;
  bool get stale => _stale;
  bool get usingFallback => _fromFallback;
  String? get placesError => _placesError;
  String? get placesErrorDetail => _placesErrorDetail;
  PlaceType? get filter => _filter;
  Place? get selected => _selected;

  /// Daftar setelah filter jenis diterapkan (urutan: terdekat dulu).
  List<Place> get places =>
      _filter == null ? _all : _all.where((p) => p.type == _filter).toList();

  /// Jumlah tempat per jenis (null = semua), dihitung dari seluruh hasil.
  int countOf(PlaceType? type) =>
      type == null ? _all.length : _all.where((p) => p.type == type).length;

  /// Ringkasan status pemuatan, ditampilkan di header panel.
  String get placesSummary {
    if (_loadingPlaces) return 'Mencari tempat olahraga...';
    if (_placesError != null) return 'Gagal memuat tempat.';
    if (!hasCenter) return 'Menunggu lokasi...';
    final f = _filter == null ? '' : ' ${_filter!.label}';
    final where = _searchLabel == null ? '' : ' di $_searchLabel';
    final n = places.length;
    return n == 0
        ? 'Tidak ada$f dalam radius $radiusKm km$where.'
        : '$n$f ditemukan dalam radius $radiusKm km$where';
  }

  Future<void> locate() async {
    if (_locating) return;
    _locating = true;
    _notify();
    _result = await _location.locate();
    _locating = false;
    if (_result?.isOk == true) {
      // Kembali memakai lokasi pengguna.
      _center = null;
      _searchLabel = null;
    }
    _notify();
    if (_result?.isOk == true) unawaited(loadPlaces());
  }

  /// [PBI-11.4] Pindahkan pusat pencarian ke hasil pencarian nama.
  Future<void> searchHere(GeoResult result) async {
    _center = GeoPoint(result.lat, result.lng);
    _searchLabel = result.title;
    _selected = null;
    _all = const [];
    await loadPlaces();
  }

  Future<void> loadPlaces({bool force = false}) async {
    final c = center;
    if (c == null) return;
    if (_loadingPlaces) {
      _reloadRequested = true; // pusat berubah saat memuat: ulangi setelahnya
      return;
    }
    _loadingPlaces = true;
    _placesError = null;
    _placesErrorDetail = null;
    _notify();
    try {
      PlacesResult? result;
      for (final radius in _radii) {
        result = await _places.nearby(
          c.lat,
          c.lng,
          radius: radius,
          force: force,
          fromLat: user?.lat,
          fromLng: user?.lng,
        );
        _radius = radius;
        if (_isEnough(result.places)) break;
      }
      _all = result!.places;
      _stale = result.stale;
      _fromFallback = result.source == PlacesSource.nominatim;
      if (_selected != null && !_all.any((p) => p.id == _selected!.id)) {
        _selected = null;
      }
    } catch (e) {
      debugPrint('Gagal memuat tempat: $e');
      _placesError =
          'Tempat olahraga belum bisa dimuat. Periksa koneksi internet.';
      _placesErrorDetail = e.toString().replaceFirst('Exception: ', '');
    }
    _loadingPlaces = false;
    _notify();
    if (_reloadRequested) {
      _reloadRequested = false;
      await loadPlaces();
    }
  }

  void setFilter(PlaceType? type) {
    _filter = type;
    _notify();
  }

  void select(Place? place) {
    _selected = place;
    _notify();
  }

  Future<void> openLocationSettings() => _location.openLocationSettings();
  Future<void> openAppSettings() => _location.openAppSettings();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}