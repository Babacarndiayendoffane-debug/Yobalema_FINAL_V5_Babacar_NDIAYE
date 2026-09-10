import 'package:flutter/foundation.dart';
import '../models/geo_position.dart';

/// Contract for GPS position filters.
abstract class ILocationFilter {
  GeoPosition? filter(GeoPosition current, GeoPosition? previous);
}

/// Filter that rejects readings with unacceptable GPS accuracy radius.
/// Adaptive across Native Mobile (high GPS precision required) and Web (Wi-Fi/IP tolerance).
class AccuracyFilter implements ILocationFilter {
  final double maxAllowedAccuracyMeters;

  const AccuracyFilter({this.maxAllowedAccuracyMeters = 50.0});

  @override
  GeoPosition? filter(GeoPosition current, GeoPosition? previous) {
    if (!current.isValid) return null;
    
    // On Web, allow Wi-Fi / Browser HTML5 accuracy up to 250m without dropping the fix
    final threshold = kIsWeb ? 250.0 : maxAllowedAccuracyMeters;
    if (current.accuracy > threshold && current.accuracy > 0) {
      return null;
    }
    return current;
  }
}

/// Filter that rejects anomalous GPS jumps and impossible vehicular speeds.
class OutlierFilter implements ILocationFilter {
  final double maxRealisticSpeedMps; // Max 50 m/s ~ 180 km/h for moto/car in Senegal

  const OutlierFilter({this.maxRealisticSpeedMps = 50.0});

  @override
  GeoPosition? filter(GeoPosition current, GeoPosition? previous) {
    if (!current.isValid) return null;
    if (previous == null) return current;

    final timeDeltaSec =
        current.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;

    // Reject backward timestamps or identical timestamp with different location
    if (timeDeltaSec <= 0.05) {
      return previous;
    }

    final distanceMeters = previous.distanceTo(current);
    final calculatedSpeedMps = distanceMeters / timeDeltaSec;

    // Detect impossible jump (except for initial web browser location initialization)
    if (calculatedSpeedMps > maxRealisticSpeedMps && distanceMeters > 50.0) {
      return null;
    }

    return current;
  }
}

/// Smoother for heading/bearing calculation when vehicle is moving vs. stationary.
class HeadingSmoother implements ILocationFilter {
  @override
  GeoPosition? filter(GeoPosition current, GeoPosition? previous) {
    if (previous == null) return current;

    double cleanHeading = current.heading;

    // If device doesn't supply compass heading but vehicle is moving (> 1.2 m/s), compute geodesic bearing
    if (cleanHeading <= 0.0 && current.speed > 1.2) {
      cleanHeading = previous.bearingTo(current);
    } else if (current.speed < 0.5 && previous.heading > 0.0) {
      // When stationary, maintain previous stable heading to prevent jitter/spinning
      cleanHeading = previous.heading;
    }

    return current.copyWith(heading: cleanHeading);
  }
}

/// Composite pipeline executing all filters sequentially.
class LocationFilterPipeline {
  final List<ILocationFilter> filters;
  GeoPosition? _lastValidPosition;

  LocationFilterPipeline({List<ILocationFilter>? customFilters})
      : filters = customFilters ??
            [
              const AccuracyFilter(maxAllowedAccuracyMeters: 65.0),
              const OutlierFilter(maxRealisticSpeedMps: 45.0),
              HeadingSmoother(),
            ];

  GeoPosition? get lastValidPosition => _lastValidPosition;

  GeoPosition? process(GeoPosition rawPosition) {
    GeoPosition? candidate = rawPosition;

    for (final f in filters) {
      candidate = f.filter(candidate!, _lastValidPosition);
      if (candidate == null) {
        return null;
      }
    }

    _lastValidPosition = candidate;
    return candidate;
  }

  void reset() {
    _lastValidPosition = null;
  }
}
