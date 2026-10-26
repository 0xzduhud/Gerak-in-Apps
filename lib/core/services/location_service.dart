// ============================================================================
// [PBI-11.1] Lokasi pengguna: izin + posisi
// [PBI-11.10] Penanganan GPS nonaktif dan izin ditolak
// File ini tidak mengimpor geolocator supaya logikanya mudah dites.
// Adaptor geolocator ada di geolocator_gateway.dart.
// ============================================================================

class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;
}

enum PermissionState { granted, denied, deniedForever }

enum LocationStatus {
  ok,
  serviceDisabled, // GPS/layanan lokasi mati
  denied, // izin ditolak (masih bisa diminta lagi)
  deniedForever, // izin ditolak permanen (harus lewat pengaturan)
  error,
}

class LocationResult {
  const LocationResult._(this.status, this.point);

  const LocationResult.ok(GeoPoint point) : this._(LocationStatus.ok, point);
  const LocationResult.failure(LocationStatus status) : this._(status, null);

  final LocationStatus status;
  final GeoPoint? point;

  bool get isOk => status == LocationStatus.ok && point != null;
}

abstract class LocationGateway {
  Future<bool> isServiceEnabled();
  Future<PermissionState> permission();
  Future<PermissionState> requestPermission();
  Future<GeoPoint> currentPosition();
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

class LocationService {
  LocationService(this._gateway);

  final LocationGateway _gateway;

  /// Urutan: cek GPS -> cek izin -> minta izin jika perlu -> ambil posisi.
  Future<LocationResult> locate() async {
    try {
      if (!await _gateway.isServiceEnabled()) {
        return const LocationResult.failure(LocationStatus.serviceDisabled);
      }

      var permission = await _gateway.permission();
      if (permission == PermissionState.denied) {
        permission = await _gateway.requestPermission();
      }
      if (permission == PermissionState.deniedForever) {
        return const LocationResult.failure(LocationStatus.deniedForever);
      }
      if (permission == PermissionState.denied) {
        return const LocationResult.failure(LocationStatus.denied);
      }

      return LocationResult.ok(await _gateway.currentPosition());
    } catch (_) {
      return const LocationResult.failure(LocationStatus.error);
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      return await _gateway.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await _gateway.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}