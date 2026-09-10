import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:yobalema/core/constants/kaolack_boundary.dart';
import 'package:yobalema/core/constants/senegal_places.dart';
import 'package:yobalema/core/models/commune.dart';
import 'package:yobalema/core/services/pricing_engine.dart';
import 'package:yobalema/core/services/routing_service.dart';

void main() {
  group('Kaolack Region Places & Autocomplete Tests', () {
    test('SenegalPlaces contains strictly Kaolack Region localities', () {
      final kaolackPlaces = SenegalPlaces.search('', region: 'Kaolack');
      expect(kaolackPlaces, isNotEmpty);

      // Département de Kaolack
      expect(
          kaolackPlaces.any((p) => p.name.contains('Kaolack Centre')), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Médina Baye')), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Ndoffane')), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Kahone')), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Sibassor')), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Ndiaffate')), isTrue);

      // Département de Nioro du Rip
      expect(kaolackPlaces.any((p) => p.department == 'Nioro du Rip'), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Porokhane')), isTrue);
      expect(
          kaolackPlaces.any((p) => p.name.contains('Keur Madiabel')), isTrue);

      // Département de Guinguinéo
      expect(kaolackPlaces.any((p) => p.department == 'Guinguinéo'), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Guinguinéo')), isTrue);
      expect(kaolackPlaces.any((p) => p.name.contains('Mbadakhoune')), isTrue);
    });

    test('Negative Test: Outside regions (Dakar, Thiès, etc.) are NOT proposed',
        () {
      // Régions extérieures
      final dakarFilter = SenegalPlaces.search('', region: 'Dakar');
      final thiesFilter = SenegalPlaces.search('', region: 'Thiès');
      expect(dakarFilter, isEmpty);
      expect(thiesFilter, isEmpty);

      // Mots-clés de lieux extérieurs
      expect(SenegalPlaces.search('Dakar'), isEmpty);
      expect(SenegalPlaces.search('Plateau'), isEmpty);
      expect(SenegalPlaces.search('Almadies'), isEmpty);
      expect(SenegalPlaces.search('Ouakam'), isEmpty);
      expect(SenegalPlaces.search('AIBD'), isEmpty);
      expect(SenegalPlaces.search('Thiès'), isEmpty);
    });

    test(
        'Search autocomplete finds Kaolack places by partial keyword and description',
        () {
      final ndoffane = SenegalPlaces.search('Ndoffane');
      expect(ndoffane, isNotEmpty);
      expect(ndoffane.first.name, contains('Ndoffane'));

      final medinaBaye = SenegalPlaces.search('Médina Baye');
      expect(medinaBaye, isNotEmpty);
      expect(medinaBaye.first.name, contains('Médina Baye'));
    });
  });

  group('Real Road Routing Engine Tests (Kaolack Region Only)', () {
    test(
        'RoutingService calculates accurate road polyline & duration for Kaolack -> Kahone',
        () async {
      final mockClient = MockClient((request) async {
        final sampleOsrm = {
          'code': 'Ok',
          'routes': [
            {
              'distance': 4800.0, // 4.8 km
              'duration': 480.0, // 8 min
              'geometry': {
                'coordinates': [
                  [-16.0726, 14.1510], // Kaolack Centre
                  [-16.0550, 14.1530],
                  [-16.0400, 14.1560], // Kahone
                ],
                'type': 'LineString',
              },
            }
          ],
        };
        return http.Response(jsonEncode(sampleOsrm), 200);
      });

      final service = RoutingService(client: mockClient);
      const kaolackCentre = LatLng(14.1510, -16.0726);
      const kahone = LatLng(14.1560, -16.0400);

      final route = await service.getRoute(kaolackCentre, kahone);

      expect(route.isFallback, isFalse);
      expect(route.distanceKm, 4.8);
      expect(route.durationMinutes, 8);
      expect(route.points.length, 3);
      expect(route.formattedDistance, '4.8 km');
      expect(route.formattedDuration, '8 min');
    });

    test(
        'RoutingService calculates accurate road polyline & duration for Kaolack -> Ndoffane',
        () async {
      final mockClient = MockClient((request) async {
        final sampleOsrm = {
          'code': 'Ok',
          'routes': [
            {
              'distance': 41200.0, // 41.2 km
              'duration': 2940.0, // 49 min
              'geometry': {
                'coordinates': [
                  [-16.0726, 14.1510], // Kaolack Centre
                  [-16.0000, 14.0500],
                  [-15.9382, 13.8447], // Ndoffane
                ],
                'type': 'LineString',
              },
            }
          ],
        };
        return http.Response(jsonEncode(sampleOsrm), 200);
      });

      final service = RoutingService(client: mockClient);
      const kaolack = LatLng(14.1510, -16.0726);
      const ndoffane = LatLng(13.8447, -15.9382);

      final route = await service.getRoute(kaolack, ndoffane);

      expect(route.isFallback, isFalse);
      expect(route.distanceKm, 41.2);
      expect(route.durationMinutes, 49);
      expect(route.points.length, 3);
    });

    test('RoutingService generates road fallback when offline without crashing',
        () async {
      final mockClient =
          MockClient((request) async => http.Response('Offline', 503));
      final service = RoutingService(client: mockClient);

      const from = LatLng(14.1510, -16.0726); // Kaolack
      const to = LatLng(13.8447, -15.9382); // Ndoffane

      final route = await service.getRoute(from, to);

      expect(route.isFallback, isTrue);
      expect(route.distanceKm, greaterThan(35.0));
      expect(route.durationMinutes, greaterThan(40));
      expect(route.points.length, 3); // Includes interpolated waypoint
    });
  });

  group('Geofencing & Kaolack Boundary Validation Tests', () {
    test('Points inside Kaolack Region pass geofencing', () {
      const kaolack = LatLng(14.1510, -16.0726);
      const ndoffane = LatLng(13.8447, -15.9382);
      const kahone = LatLng(14.1560, -16.0400);
      const nioro = LatLng(13.7500, -15.7800);
      const guinguineo = LatLng(14.2700, -15.9500);

      expect(KaolackBoundary.isInside(kaolack), isTrue);
      expect(KaolackBoundary.isInside(ndoffane), isTrue);
      expect(KaolackBoundary.isInside(kahone), isTrue);
      expect(KaolackBoundary.isInside(nioro), isTrue);
      expect(KaolackBoundary.isInside(guinguineo), isTrue);
    });

    test('Points outside Kaolack Region fail geofencing', () {
      const dakarPlateau = LatLng(14.6698, -17.4326);
      const almadies = LatLng(14.7470, -17.5180);
      const thies = LatLng(14.7900, -16.9260);
      const saintLouis = LatLng(16.0300, -16.5000);
      const ziguinchor = LatLng(12.5800, -16.2700);

      expect(KaolackBoundary.isInside(dakarPlateau), isFalse);
      expect(KaolackBoundary.isInside(almadies), isFalse);
      expect(KaolackBoundary.isInside(thies), isFalse);
      expect(KaolackBoundary.isInside(saintLouis), isFalse);
      expect(KaolackBoundary.isInside(ziguinchor), isFalse);
    });
  });

  group('Yobalema Moto Pricing & 90/10 Commission Invariance Tests', () {
    test(
        'Commission is strictly 10% platform, 90% driver across multiple distances',
        () {
      final distances = [1.5, 3.0, 5.5, 10.0, 25.0, 42.0];

      for (final dist in distances) {
        final quote = Pricing.calculate(
          km: dist,
          fromZone: ZoneType.city,
          toZone: ZoneType.city,
          serviceType: 'MOTO',
        );

        expect(quote.serviceType, 'MOTO');
        expect(quote.total, greaterThanOrEqualTo(300));
        expect(quote.driver + quote.platform, equals(quote.total));
        // Platform share is ~10% (within rounding)
        expect(quote.platform, closeTo(quote.total * 0.10, 5));
        expect(quote.driver, closeTo(quote.total * 0.90, 5));
      }
    });

    test('Moto pricing applies night surcharge and minimum fare guarantee', () {
      final dayQuote = Pricing.calculate(
        km: 1.0,
        fromZone: ZoneType.city,
        toZone: ZoneType.city,
        night: false,
        trafficLevel: 0,
      );
      final nightQuote = Pricing.calculate(
        km: 1.0,
        fromZone: ZoneType.city,
        toZone: ZoneType.city,
        night: true,
        trafficLevel: 0,
      );

      // Minimum fare is at least 300 FCFA
      expect(dayQuote.total, greaterThanOrEqualTo(300));
      // Night fare is higher (+200 FCFA in city)
      expect(nightQuote.total, greaterThan(dayQuote.total));
      expect(nightQuote.total - dayQuote.total, equals(200));

      // Both strictly preserve 90% driver / 10% platform
      expect(dayQuote.driver + dayQuote.platform, equals(dayQuote.total));
      expect(nightQuote.driver + nightQuote.platform, equals(nightQuote.total));
    });
  });
}
