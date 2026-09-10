import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_result.dart';

/// Configuration options for routing calculations and network requests.
class RoutingConfig {
  final String osrmBaseUrl;
  final String userAgent;
  final Duration timeout;
  final double roadDetourFactor;
  final double averageSpeedKmh;
  final double minDistanceKm;

  const RoutingConfig({
    this.osrmBaseUrl = 'https://router.project-osrm.org',
    this.userAgent = 'Yobalema-Moto/2.0 (Flutter; Kaolack-Region)',
    this.timeout = const Duration(seconds: 5),
    this.roadDetourFactor = 1.25,
    this.averageSpeedKmh = 35.0,
    this.minDistanceKm = 0.5,
  });
}

/// Abstract contract for route calculation providers (Strategy Pattern).
abstract class RoutingProvider {
  Future<RouteResult> calculateRoute(LatLng start, LatLng destination);
}

/// Abstract contract for high-level routing services (Interface Segregation & DIP).
abstract class IRoutingService {
  Future<RouteResult> getRoute(LatLng start, LatLng destination);
}

/// Dedicated parser for OSRM GeoJSON response payloads (Single Responsibility Principle).
class OsrmRouteParser {
  static RouteResult? parse(
    Map<String, dynamic> data, {
    double minDistanceKm = 0.5,
  }) {
    if (data['code'] != 'Ok' || data['routes'] == null) {
      return null;
    }

    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return null;
    }

    final route = routes[0] as Map<String, dynamic>;
    final rawDistance = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final rawDuration = (route['duration'] as num?)?.toDouble() ?? 0.0;

    final distanceKm =
        double.parse((rawDistance / 1000.0).toStringAsFixed(2));
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

    if (points.isEmpty) {
      return null;
    }

    return RouteResult(
      points: points,
      distanceKm: distanceKm < minDistanceKm ? minDistanceKm : distanceKm,
      durationMinutes: durationMinutes,
      isFallback: false,
    );
  }
}

/// Remote OSRM implementation of [RoutingProvider] (Strategy Pattern).
class OsrmRoutingProvider implements RoutingProvider {
  final http.Client _client;
  final RoutingConfig _config;

  OsrmRoutingProvider({
    http.Client? client,
    RoutingConfig config = const RoutingConfig(),
  })  : _client = client ?? http.Client(),
        _config = config;

  @override
  Future<RouteResult> calculateRoute(LatLng start, LatLng destination) async {
    final url = Uri.parse(
      '${_config.osrmBaseUrl}/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await _client.get(
      url,
      headers: {
        'User-Agent': _config.userAgent,
        'Accept': 'application/json',
      },
    ).timeout(_config.timeout);

    if (response.statusCode != 200) {
      throw Exception('OSRM HTTP ${response.statusCode}: ${response.body}');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final result =
        OsrmRouteParser.parse(data, minDistanceKm: _config.minDistanceKm);
    if (result == null) {
      throw Exception('Format de réponse OSRM invalide ou itinéraire vide.');
    }

    return result;
  }
}

/// Offline / Heuristic estimation provider using geodesic calculation (Strategy Pattern).
class OfflineGeodesicRoutingProvider implements RoutingProvider {
  final RoutingConfig _config;

  const OfflineGeodesicRoutingProvider({
    RoutingConfig config = const RoutingConfig(),
  }) : _config = config;

  @override
  Future<RouteResult> calculateRoute(LatLng start, LatLng destination) async {
    const distanceCalc = Distance();
    final straightLineKm =
        distanceCalc.as(LengthUnit.Kilometer, start, destination);

    final estimatedRoadKm = double.parse(
      ((straightLineKm * _config.roadDetourFactor)
              .clamp(_config.minDistanceKm, 999.0))
          .toStringAsFixed(1),
    );

    final estimatedMinutes =
        ((estimatedRoadKm / _config.averageSpeedKmh) * 60)
            .round()
            .clamp(1, 9999);

    // Interpolation de points intermédiaires pour un tracé naturel
    final midLat = (start.latitude + destination.latitude) / 2 +
        (destination.longitude - start.longitude) * 0.05;
    final midLng = (start.longitude + destination.longitude) / 2 -
        (destination.latitude - start.latitude) * 0.05;

    return RouteResult(
      points: [
        start,
        LatLng(midLat, midLng),
        destination,
      ],
      distanceKm: estimatedRoadKm,
      durationMinutes: estimatedMinutes,
      isFallback: true,
      fallbackReason: 'Estimation routière locale (hors-ligne)',
    );
  }
}

/// High-level routing orchestrator supporting primary and resilient fallback routing (Composite / Facade Pattern).
class RoutingService implements IRoutingService {
  final RoutingProvider _primaryProvider;
  final RoutingProvider _fallbackProvider;

  RoutingService({
    http.Client? client,
    RoutingConfig config = const RoutingConfig(),
    RoutingProvider? primaryProvider,
    RoutingProvider? fallbackProvider,
  })  : _primaryProvider = primaryProvider ??
            OsrmRoutingProvider(client: client, config: config),
        _fallbackProvider = fallbackProvider ??
            OfflineGeodesicRoutingProvider(config: config);

  /// Calcule l'itinéraire routier réel entre départ et destination via le provider principal (OSRM)
  /// avec basculement automatique et résilient vers l'estimateur géodésique hors-ligne en cas d'erreur.
  @override
  Future<RouteResult> getRoute(LatLng start, LatLng destination) async {
    try {
      return await _primaryProvider.calculateRoute(start, destination);
    } catch (e) {
      debugPrint(
          'RoutingService: OSRM indisponible ($e) -> activation fallback routier.');
      return await _fallbackProvider.calculateRoute(start, destination);
    }
  }
}
