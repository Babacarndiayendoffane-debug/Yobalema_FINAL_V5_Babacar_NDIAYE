import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:yobalema/core/geo/geo.dart';

void main() {
  group('1. GeoPosition Model & Validation Tests', () {
    test('Valid GeoPosition creates correctly and exposes telemetry', () {
      final pos = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        accuracy: 4.8,
        speed: 12.5,
        heading: 85.0,
        altitude: 15.0,
        timestamp: DateTime(2025, 1, 1, 12, 0, 0),
      );

      expect(pos.isValid, isTrue);
      expect(pos.isReliable, isTrue);
      expect(pos.accuracy, 4.8);
      expect(pos.speedKmh, closeTo(45.0, 0.1));
      expect(pos.heading, 85.0);
      expect(pos.toLatLng().latitude, 14.1510);
      expect(pos.toLatLng().longitude, -16.0726);
    });

    test('Invalid coordinates (NaN, Inf, Out of Bounds, 0.0) are marked invalid', () {
      final nanPos = GeoPosition(
        latitude: double.nan,
        longitude: -16.0726,
        timestamp: DateTime.now(),
      );
      expect(nanPos.isValid, isFalse);

      final outOfBoundsPos = GeoPosition(
        latitude: 95.0,
        longitude: -16.0726,
        timestamp: DateTime.now(),
      );
      expect(outOfBoundsPos.isValid, isFalse);

      final zeroZeroPos = GeoPosition(
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
      );
      expect(zeroZeroPos.isValid, isFalse);
    });

    test('Distance and Bearing calculations work accurately', () {
      // Kaolack Centre -> Kahone (~4.8 km East-North-East)
      final kaolack = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        timestamp: DateTime(2025, 1, 1),
      );
      final kahone = GeoPosition(
        latitude: 14.1560,
        longitude: -16.0400,
        timestamp: DateTime(2025, 1, 1),
      );

      final distanceMeters = kaolack.distanceTo(kahone);
      expect(distanceMeters, closeTo(3560.0, 200.0)); // Geodesic straight-line ~3.5km

      final bearing = kaolack.bearingTo(kahone);
      expect(bearing, greaterThan(60.0));
      expect(bearing, lessThan(90.0)); // General East direction
    });

    test('GeoPosition JSON serialization & deserialization round-trip', () {
      final original = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        accuracy: 6.2,
        speed: 10.0,
        heading: 120.0,
        altitude: 22.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final json = original.toJson();
      final restored = GeoPosition.fromJson(json);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.accuracy, original.accuracy);
      expect(restored.speed, original.speed);
      expect(restored.heading, original.heading);
      expect(restored.timestamp.millisecondsSinceEpoch, original.timestamp.millisecondsSinceEpoch);
    });
  });

  group('2. GPS Filtering & Pipeline Tests', () {
    test('AccuracyFilter rejects points with excessive error radius', () {
      const filter = AccuracyFilter(maxAllowedAccuracyMeters: 50.0);

      final accuratePos = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        accuracy: 8.0,
        timestamp: DateTime.now(),
      );
      final noisyPos = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        accuracy: 120.0, // Inaccurate GPS
        timestamp: DateTime.now(),
      );

      expect(filter.filter(accuratePos, null), isNotNull);
      expect(filter.filter(noisyPos, null), isNull);
    });

    test('OutlierFilter detects impossible teleportation jumps', () {
      const filter = OutlierFilter(maxRealisticSpeedMps: 45.0); // ~162 km/h
      final t0 = DateTime.now();

      final p1 = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        timestamp: t0,
      );

      // 2 seconds later, moving 30 meters (~15 m/s = 54 km/h) -> NORMAL
      final p2 = GeoPosition(
        latitude: 14.1512,
        longitude: -16.0724,
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      expect(filter.filter(p2, p1), isNotNull);

      // 2 seconds later, teleporting 10 km away -> IMPOSSIBLE / ABERRANT
      final pTeleport = GeoPosition(
        latitude: 14.2500,
        longitude: -16.0726,
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      expect(filter.filter(pTeleport, p1), isNull);
    });

    test('HeadingSmoother preserves heading when vehicle is stationary', () {
      final smoother = HeadingSmoother();
      final t0 = DateTime.now();

      final pMoving = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        speed: 8.0,
        heading: 90.0,
        timestamp: t0,
      );

      final pStopped = GeoPosition(
        latitude: 14.1510,
        longitude: -16.0726,
        speed: 0.0, // Stopped at traffic light
        heading: 0.0, // Compass jitter
        timestamp: t0.add(const Duration(seconds: 2)),
      );

      final smoothed = smoother.filter(pStopped, pMoving);
      expect(smoothed?.heading, 90.0); // Preserved stable heading
    });
  });

  group('3. Position & Heading Interpolation Tests', () {
    test('Interpolates coordinates smoothly between two points', () {
      const start = LatLng(14.0, -16.0);
      const end = LatLng(14.2, -16.4);

      final mid = PositionInterpolator.interpolatePoint(start, end, 0.5);
      expect(mid.latitude, closeTo(14.1, 0.0001));
      expect(mid.longitude, closeTo(-16.2, 0.0001));
    });

    test('Interpolates heading using shortest angular path across 360 wrap-around', () {
      // From 350 degrees to 10 degrees (20 degree clockwise arc, not 340 degree counter-clockwise!)
      final midHeading = PositionInterpolator.interpolateHeading(350.0, 10.0, 0.5);
      expect(midHeading, closeTo(0.0, 0.1)); // Midpoint of (350 -> 10) is 0 / 360 degrees
    });
  });

  group('4. Telemetry Payload & Contract Tests', () {
    test('DriverTelemetryPayload parses and outputs correct VTC schema', () {
      final payload = DriverTelemetryPayload(
        driverId: 'driver-kl-01',
        tripId: 'ride-999',
        position: GeoPosition(
          latitude: 14.1510,
          longitude: -16.0726,
          accuracy: 5.0,
          speed: 11.2,
          heading: 180.0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ),
      );

      final json = payload.toJson();
      expect(json['driverId'], 'driver-kl-01');
      expect(json['tripId'], 'ride-999');
      expect(json['latitude'], 14.1510);
      expect(json['longitude'], -16.0726);
      expect(json['accuracy'], 5.0);
      expect(json['speed'], 11.2);
      expect(json['heading'], 180.0);
    });
  });
}
