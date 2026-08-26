import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:yobalema/services/routing_service.dart';

void main() {
  group('RoutingService & RouteResult Tests', () {
    test('RouteResult formatting works properly', () {
      const r1 = RouteResult(
        points: [LatLng(14.0, -16.0), LatLng(14.1, -16.1)],
        distanceKm: 42.56,
        durationMinutes: 48,
        isFallback: false,
      );

      expect(r1.formattedDistance, '42.6 km');
      expect(r1.formattedDuration, '48 min');
      expect(r1.isFallback, isFalse);

      const r2 = RouteResult(
        points: [LatLng(14.0, -16.0), LatLng(14.1, -16.1)],
        distanceKm: 120.0,
        durationMinutes: 125,
        isFallback: true,
      );

      expect(r2.formattedDuration, '2h 5min');
      expect(r2.isFallback, isTrue);
    });

    test('RoutingService successfully parses OSRM response', () async {
      final mockClient = MockClient((request) async {
        final sampleOsrm = {
          'code': 'Ok',
          'routes': [
            {
              'distance': 41175.4,
              'duration': 2968.8,
              'geometry': {
                'coordinates': [
                  [-15.9382, 13.8447],
                  [-15.9500, 13.9000],
                  [-16.0726, 14.1510],
                ],
                'type': 'LineString',
              },
            }
          ],
        };
        return http.Response(jsonEncode(sampleOsrm), 200);
      });

      final service = RoutingService(client: mockClient);
      final result = await service.getRoute(
        const LatLng(13.8447, -15.9382), // Ndoffane
        const LatLng(14.1510, -16.0726), // Kaolack
      );

      expect(result.isFallback, isFalse);
      expect(result.distanceKm, closeTo(41.18, 0.1));
      expect(result.durationMinutes, 49);
      expect(result.points.length, 3);
      expect(result.points.first.latitude, closeTo(13.8447, 0.001));
      expect(result.points.last.latitude, closeTo(14.1510, 0.001));
    });

    test('RoutingService fallback kicks in smoothly when network fails', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = RoutingService(client: mockClient);
      const start = LatLng(13.8447, -15.9382); // Ndoffane
      const dest = LatLng(14.1510, -16.0726); // Kaolack

      final result = await service.getRoute(start, dest);

      expect(result.isFallback, isTrue);
      expect(result.fallbackReason, isNotNull);
      expect(result.points.length, 2);
      // Fallback road distance (1.25 * geodesic straight distance ~37km -> ~46.2km)
      expect(result.distanceKm, greaterThan(37.0));
      expect(result.durationMinutes, greaterThan(30));
    });

    test('Recalculation on different destinations returns distinct results', () async {
      final mockClient = MockClient((request) async {
        final isKahone = request.url.toString().contains('-16.04');
        final sample = {
          'code': 'Ok',
          'routes': [
            {
              'distance': isKahone ? 12000.0 : 45000.0,
              'duration': isKahone ? 900.0 : 3000.0,
              'geometry': {
                'coordinates': [
                  [-15.9382, 13.8447],
                  isKahone ? [-16.0400, 14.1560] : [-16.3200, 14.2300],
                ],
                'type': 'LineString',
              },
            }
          ],
        };
        return http.Response(jsonEncode(sample), 200);
      });

      final service = RoutingService(client: mockClient);
      const start = LatLng(13.8447, -15.9382); // Ndoffane

      final route1 = await service.getRoute(start, const LatLng(14.1560, -16.0400)); // Kahone
      final route2 = await service.getRoute(start, const LatLng(14.2300, -16.3200)); // Gandiaye

      expect(route1.distanceKm, 12.0);
      expect(route1.durationMinutes, 15);

      expect(route2.distanceKm, 45.0);
      expect(route2.durationMinutes, 50);
    });
  });
}
