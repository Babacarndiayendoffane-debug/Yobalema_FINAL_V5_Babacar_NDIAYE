import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../api/yobalema_api.dart';
import '../models/geo_position.dart';
import '../models/tracking_state.dart';
import 'location_service.dart';

/// Service managing real-time driver telemetry broadcast to backend and passengers.
class DriverTrackingService {
  final YobalemaApi api;
  final LocationService locationService;

  StreamSubscription<GeoPosition>? _subscription;
  String? _activeRideId;
  String? _driverId;
  DateTime? _lastEmitTime;
  GeoPosition? _lastEmittedPosition;

  DriverTrackingService({
    required this.api,
    LocationService? locationService,
  }) : locationService = locationService ?? LocationService();

  void initialize({required String driverId}) {
    _driverId = driverId;
  }

  /// Starts tracking driver with appropriate fidelity.
  Future<void> startDriverTracking({
    bool isOnline = true,
    String? activeRideId,
  }) async {
    _activeRideId = activeRideId;
    final mode = activeRideId != null
        ? LocationTrackingMode.activeTrip
        : (isOnline ? LocationTrackingMode.searching : LocationTrackingMode.passive);

    await _subscription?.cancel();
    _subscription = null;
    await locationService.startTracking(mode);

    _subscription = locationService.positionStream.listen((pos) {
      _handleNewPosition(pos);
    });
  }

  /// Updates current ride context.
  void setActiveRide(String? rideId) {
    _activeRideId = rideId;
    if (rideId != null) {
      locationService.setMode(LocationTrackingMode.activeTrip);
    } else {
      locationService.setMode(LocationTrackingMode.searching);
    }
  }

  void _handleNewPosition(GeoPosition pos) {
    final now = DateTime.now();

    // Throttling check: emit at most every 1.5s in active trip, every 5s if idle/online
    final minInterval = _activeRideId != null
        ? const Duration(milliseconds: 1500)
        : const Duration(seconds: 5);

    if (_lastEmitTime != null && now.difference(_lastEmitTime!) < minInterval) {
      // If displaced significantly (> 15m), allow immediate broadcast
      if (_lastEmittedPosition == null ||
          _lastEmittedPosition!.distanceTo(pos) < 15.0) {
        return;
      }
    }

    _lastEmitTime = now;
    _lastEmittedPosition = pos;

    debugPrint(
      '[TRACKING] driver=$_driverId ride=$_activeRideId lat=${pos.latitude} lng=${pos.longitude} speed=${pos.speedKmh.toStringAsFixed(1)}km/h heading=${pos.heading.toStringAsFixed(0)}°',
    );

    // 1. Emit live location to Ride WebSocket room if active
    if (_activeRideId != null) {
      api.emitLocation(
        _activeRideId!,
        pos.latitude,
        pos.longitude,
        accuracy: pos.accuracy,
        speed: pos.speed,
        heading: pos.heading,
      );
    }

    // 2. Update driver location on backend
    api.updateDriverLocation(pos.latitude, pos.longitude);
  }

  /// Stops tracking when driver goes offline.
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _activeRideId = null;
    locationService.stopTracking();
  }

  void dispose() {
    stopTracking();
  }
}
