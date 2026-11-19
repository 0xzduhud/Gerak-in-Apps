import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoadRouteResult {
  const RoadRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes menit';
    }
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return '${hours}j ${rem}m';
  }
}

class RoadRoutingService {
  RoadRoutingService._();
  static final RoadRoutingService instance = RoadRoutingService._();

  /// Mengambil titik rute nyata mengikuti jalan raya menggunakan OSRM API (Revisi 5).
  Future<RoadRouteResult?> fetchRoadRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'GerakinApps/1.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final firstRoute = routes.first as Map<String, dynamic>;
            final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
            final coordinates = geometry?['coordinates'] as List<dynamic>?;

            final distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
            final duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

            if (coordinates != null && coordinates.isNotEmpty) {
              final points = <LatLng>[];
              for (final c in coordinates) {
                if (c is List && c.length >= 2) {
                  final lng = (c[0] as num).toDouble();
                  final lat = (c[1] as num).toDouble();
                  points.add(LatLng(lat, lng));
                }
              }

              if (points.isNotEmpty) {
                return RoadRouteResult(
                  points: points,
                  distanceMeters: distance,
                  durationSeconds: duration,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('RoadRoutingService error: $e');
    }

    return null;
  }
}
