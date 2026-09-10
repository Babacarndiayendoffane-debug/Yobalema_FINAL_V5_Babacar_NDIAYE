import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Single source of truth for geographical positions across Yobalema.
class GeoPosition {
  final double latitude;
  final double longitude;
  final double accuracy; // En mètres
  final double speed; // En m/s
  final double heading; // En degrés [0, 360[
  final double? altitude; // En mètres
  final DateTime timestamp;
  final String provider;

  const GeoPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
    this.altitude,
    required this.timestamp,
    this.provider = 'GPS',
  });

  /// Factory depuis la position brute du package Geolocator
  factory GeoPosition.fromPosition(Position pos, {String? providerName}) {
    final defaultProvider = kIsWeb
        ? 'Chrome Web (HTML5 Wi-Fi/IP)'
        : (defaultTargetPlatform == TargetPlatform.android
            ? 'Android FusedLocation (GNSS)'
            : 'iOS CoreLocation');

    return GeoPosition(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speed: pos.speed.isNegative ? 0.0 : pos.speed,
      heading: pos.heading.isNegative ? 0.0 : pos.heading,
      altitude: pos.altitude,
      timestamp: pos.timestamp,
      provider: providerName ?? defaultProvider,
    );
  }

  /// Factory depuis LatLng
  factory GeoPosition.fromLatLng(
    LatLng point, {
    double accuracy = 0.0,
    double speed = 0.0,
    double heading = 0.0,
    double? altitude,
    DateTime? timestamp,
    String provider = 'Manual/Default',
  }) {
    return GeoPosition(
      latitude: point.latitude,
      longitude: point.longitude,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      altitude: altitude,
      timestamp: timestamp ?? DateTime.now(),
      provider: provider,
    );
  }

  /// Factory JSON
  factory GeoPosition.fromJson(Map<String, dynamic> json) {
    return GeoPosition(
      latitude: (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
              : DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      provider: json['provider']?.toString() ?? 'Remote/WebSocket',
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'altitude': altitude,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'provider': provider,
      };

  LatLng toLatLng() => LatLng(latitude, longitude);

  /// Vérifie la validité mathématique et géométrique stricte
  bool get isValid {
    if (latitude.isNaN || latitude.isInfinite || longitude.isNaN || longitude.isInfinite) {
      return false;
    }
    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
      return false;
    }
    // Point (0,0) est considéré comme une anomalie GPS nulle
    if (latitude == 0.0 && longitude == 0.0) {
      return false;
    }
    return true;
  }

  /// Indique si la précision GPS est d'un standard mobile élevé (<= 35m)
  bool get isReliable => accuracy <= 35.0 && accuracy >= 0.0;

  /// Vitesse en km/h
  double get speedKmh => speed * 3.6;

  /// Distance géodésique vers une autre position en mètres
  double distanceTo(GeoPosition other) {
    const distanceCalc = Distance();
    return distanceCalc.as(
      LengthUnit.Meter,
      toLatLng(),
      other.toLatLng(),
    );
  }

  /// Distance géodésique vers un LatLng en mètres
  double distanceToLatLng(LatLng target) {
    const distanceCalc = Distance();
    return distanceCalc.as(LengthUnit.Meter, toLatLng(), target);
  }

  /// Calcule le cap (bearing) vers une autre position en degrés [0, 360[
  double bearingTo(GeoPosition other) {
    final lat1 = latitude * (math.pi / 180.0);
    final lon1 = longitude * (math.pi / 180.0);
    final lat2 = other.latitude * (math.pi / 180.0);
    final lon2 = other.longitude * (math.pi / 180.0);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final radians = math.atan2(y, x);
    final degrees = (radians * (180.0 / math.pi) + 360.0) % 360.0;
    return degrees;
  }

  GeoPosition copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
    DateTime? timestamp,
    String? provider,
  }) {
    return GeoPosition(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      altitude: altitude ?? this.altitude,
      timestamp: timestamp ?? this.timestamp,
      provider: provider ?? this.provider,
    );
  }

  @override
  String toString() =>
      'GeoPosition(lat: ${latitude.toStringAsFixed(6)}, lng: ${longitude.toStringAsFixed(6)}, acc: ${accuracy.toStringAsFixed(1)}m, speed: ${speedKmh.toStringAsFixed(1)}km/h, heading: ${heading.toStringAsFixed(0)}°, src: $provider)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPosition &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          timestamp == other.timestamp;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode ^ timestamp.hashCode;
}
