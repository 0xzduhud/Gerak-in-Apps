import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// Adaptor antara [LocationGateway] dan package geolocator.
class GeolocatorGateway implements LocationGateway {
  PermissionState _map(LocationPermission p) => switch (p) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          PermissionState.granted,
        LocationPermission.deniedForever => PermissionState.deniedForever,
        _ => PermissionState.denied,
      };

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<PermissionState> permission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<PermissionState> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<GeoPoint> currentPosition() async {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return GeoPoint(p.latitude, p.longitude);
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}