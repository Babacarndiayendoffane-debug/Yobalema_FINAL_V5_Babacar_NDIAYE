import 'package:geolocator/geolocator.dart';
import 'geo_position.dart';

/// Tracking modes optimized for battery life vs. high-resolution real-time navigation.
enum LocationTrackingMode {
  idle,
  passive,
  searching,
  activeTrip,
}

extension LocationTrackingModeConfig on LocationTrackingMode {
  LocationAccuracy get desiredAccuracy {
    switch (this) {
      case LocationTrackingMode.idle:
        return LocationAccuracy.low;
      case LocationTrackingMode.passive:
        return LocationAccuracy.medium;
      case LocationTrackingMode.searching:
        return LocationAccuracy.high;
      case LocationTrackingMode.activeTrip:
        return LocationAccuracy.bestForNavigation;
    }
  }

  int get distanceFilterMeters {
    switch (this) {
      case LocationTrackingMode.idle:
        return 50;
      case LocationTrackingMode.passive:
        return 20;
      case LocationTrackingMode.searching:
        return 8;
      case LocationTrackingMode.activeTrip:
        return 3;
    }
  }

  Duration get sampleInterval {
    switch (this) {
      case LocationTrackingMode.idle:
        return const Duration(seconds: 30);
      case LocationTrackingMode.passive:
        return const Duration(seconds: 10);
      case LocationTrackingMode.searching:
        return const Duration(seconds: 4);
      case LocationTrackingMode.activeTrip:
        return const Duration(seconds: 2);
    }
  }
}

/// Telemetry payload sent between Driver -> Backend -> Passenger.
class DriverTelemetryPayload {
  final String driverId;
  final String? tripId;
  final GeoPosition position;

  const DriverTelemetryPayload({
    required this.driverId,
    this.tripId,
    required this.position,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        if (tripId != null) 'tripId': tripId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'altitude': position.altitude,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
      };

  factory DriverTelemetryPayload.fromJson(Map<String, dynamic> json) {
    return DriverTelemetryPayload(
      driverId: json['driverId']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? json['rideId']?.toString(),
      position: GeoPosition.fromJson(json),
    );
  }
}
