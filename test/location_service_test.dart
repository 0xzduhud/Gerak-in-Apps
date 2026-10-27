import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/core/services/location_service.dart';

class _FakeGateway implements LocationGateway {
  _FakeGateway({
    this.enabled = true,
    this.initial = PermissionState.granted,
    this.afterRequest = PermissionState.granted,
    this.throwOnPosition = false,
  });

  final bool enabled;
  final PermissionState initial;
  final PermissionState afterRequest;
  final bool throwOnPosition;
  int requestCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => enabled;

  @override
  Future<PermissionState> permission() async => initial;

  @override
  Future<PermissionState> requestPermission() async {
    requestCalls++;
    return afterRequest;
  }

  @override
  Future<GeoPoint> currentPosition() async {
    if (throwOnPosition) throw Exception('timeout');
    return const GeoPoint(-7.8, 110.4);
  }

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

void main() {
  group('PBI-11.1 / 11.10 LocationService.locate', () {
    test('izin sudah diberikan: langsung mengembalikan posisi', () async {
      final g = _FakeGateway();
      final r = await LocationService(g).locate();
      expect(r.isOk, isTrue);
      expect(r.point!.lat, -7.8);
      expect(g.requestCalls, 0);
    });

    test('GPS mati: serviceDisabled, izin tidak diminta', () async {
      final g = _FakeGateway(enabled: false);
      final r = await LocationService(g).locate();
      expect(r.status, LocationStatus.serviceDisabled);
      expect(r.point, isNull);
      expect(g.requestCalls, 0);
    });

    test('izin belum ada lalu disetujui: posisi didapat', () async {
      final g = _FakeGateway(initial: PermissionState.denied);
      final r = await LocationService(g).locate();
      expect(r.isOk, isTrue);
      expect(g.requestCalls, 1);
    });

    test('izin diminta lalu ditolak: denied', () async {
      final g = _FakeGateway(
        initial: PermissionState.denied,
        afterRequest: PermissionState.denied,
      );
      final r = await LocationService(g).locate();
      expect(r.status, LocationStatus.denied);
    });

    test('ditolak permanen: deniedForever tanpa meminta lagi', () async {
      final g = _FakeGateway(initial: PermissionState.deniedForever);
      final r = await LocationService(g).locate();
      expect(r.status, LocationStatus.deniedForever);
      expect(g.requestCalls, 0);
    });

    test('diminta lalu ditolak permanen: deniedForever', () async {
      final g = _FakeGateway(
        initial: PermissionState.denied,
        afterRequest: PermissionState.deniedForever,
      );
      final r = await LocationService(g).locate();
      expect(r.status, LocationStatus.deniedForever);
    });

    test('kegagalan ambil posisi: error, tidak melempar', () async {
      final g = _FakeGateway(throwOnPosition: true);
      final r = await LocationService(g).locate();
      expect(r.status, LocationStatus.error);
    });
  });
}