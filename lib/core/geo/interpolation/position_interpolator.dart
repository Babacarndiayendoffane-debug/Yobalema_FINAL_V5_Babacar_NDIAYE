import 'package:latlong2/latlong.dart';
import '../models/geo_position.dart';

/// Helper for linear and shortest-arc spherical angle interpolation.
class PositionInterpolator {
  /// Interpolates between two coordinates linearly given [t] in [0.0, 1.0].
  static LatLng interpolatePoint(LatLng from, LatLng to, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    final lat = from.latitude + (to.latitude - from.latitude) * clampedT;
    final lng = from.longitude + (to.longitude - from.longitude) * clampedT;
    return LatLng(lat, lng);
  }

  /// Interpolates between two angles in degrees using the shortest angular rotation path.
  static double interpolateHeading(double fromDegrees, double toDegrees, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    double diff = (toDegrees - fromDegrees) % 360.0;
    if (diff > 180.0) {
      diff -= 360.0;
    } else if (diff < -180.0) {
      diff += 360.0;
    }
    return (fromDegrees + diff * clampedT) % 360.0;
  }

  /// Interpolates complete [GeoPosition].
  static GeoPosition interpolatePosition(
    GeoPosition from,
    GeoPosition to,
    double t,
  ) {
    final point = interpolatePoint(from.toLatLng(), to.toLatLng(), t);
    final heading = interpolateHeading(from.heading, to.heading, t);
    final speed = from.speed + (to.speed - from.speed) * t.clamp(0.0, 1.0);

    return GeoPosition(
      latitude: point.latitude,
      longitude: point.longitude,
      accuracy: to.accuracy,
      speed: speed,
      heading: heading,
      altitude: to.altitude,
      timestamp: DateTime.now(),
    );
  }
}
