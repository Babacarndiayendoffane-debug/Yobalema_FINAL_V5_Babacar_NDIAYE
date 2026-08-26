import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isFallback;
  final String? fallbackReason;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.isFallback = false,
    this.fallbackReason,
  });

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  String get formattedDuration {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }
}

class RoutingService {
  final http.Client _client;

  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Calcule l'itinéraire routier réel entre départ et destination via OSRM.
  /// En cas d'erreur ou d'indisponibilité, utilise une estimation routière locale réaliste.
  Future<RouteResult> getRoute(LatLng start, LatLng destination) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await _client.get(
        url,
        headers: {
          'User-Agent': 'Yobalema-Kaolack-App/2.0 (Flutter)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['routes'] != null) {
          final routes = data['routes'] as List<dynamic>;
          if (routes.isNotEmpty) {
            final route = routes[0] as Map<String, dynamic>;
            final rawDistance = (route['distance'] as num?)?.toDouble() ?? 0.0;
            final rawDuration = (route['duration'] as num?)?.toDouble() ?? 0.0;

            final distanceKm = double.parse((rawDistance / 1000.0).toStringAsFixed(2));
            final durationMinutes = (rawDuration / 60.0).round().clamp(1, 9999);

            final geometry = route['geometry'] as Map<String, dynamic>?;
            final coordinates = (geometry?['coordinates'] as List<dynamic>?) ?? [];

            final points = <LatLng>[];
            for (final coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final lon = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lon));
              }
            }

            if (points.isNotEmpty) {
              return RouteResult(
                points: points,
                distanceKm: distanceKm < 0.5 ? 0.5 : distanceKm,
                durationMinutes: durationMinutes,
                isFallback: false,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('RoutingService: OSRM indisponible ($e) -> fallback estimation locale.');
    }

    return _calculateFallbackRoute(start, destination);
  }

  /// Estimation routière locale basée sur un facteur de détour routier (~1.25x)
  /// et une vitesse moyenne estimée à 35 km/h pour la région de Kaolack.
  RouteResult _calculateFallbackRoute(LatLng start, LatLng destination) {
    const distanceCalc = Distance();
    final straightLineKm = distanceCalc.as(LengthUnit.Kilometer, start, destination);

    final estimatedRoadKm = double.parse(
      ((straightLineKm * 1.25).clamp(0.5, 999.0)).toStringAsFixed(1),
    );

    final estimatedMinutes = ((estimatedRoadKm / 35.0) * 60).round().clamp(1, 9999);

    return RouteResult(
      points: [start, destination],
      distanceKm: estimatedRoadKm,
      durationMinutes: estimatedMinutes,
      isFallback: true,
      fallbackReason: 'Estimation routière locale (hors-ligne)',
    );
  }
}
