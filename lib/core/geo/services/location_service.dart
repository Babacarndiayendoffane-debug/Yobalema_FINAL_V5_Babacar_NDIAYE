import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../filters/location_filter.dart';
import '../models/geo_position.dart';
import '../models/tracking_state.dart';

/// Professional high-precision GPS acquisition and stream provider for Yobalema.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final LocationFilterPipeline _pipeline = LocationFilterPipeline();
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<GeoPosition> _positionController =
      StreamController<GeoPosition>.broadcast();

  LocationTrackingMode _currentMode = LocationTrackingMode.idle;
  int _trackingStartRequest = 0;
  GeoPosition? _lastRawPosition;
  GeoPosition? _lastFilteredPosition;

  Stream<GeoPosition> get positionStream => _positionController.stream;
  GeoPosition? get lastRawPosition => _lastRawPosition;
  GeoPosition? get lastFilteredPosition => _lastFilteredPosition;
  GeoPosition? get lastKnownPosition => _lastFilteredPosition ?? _lastRawPosition;
  LocationTrackingMode get currentMode => _currentMode;

  /// Checks and requests device GPS permissions.
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LOCATION] GPS service désactivé sur l\'appareil.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[LOCATION] Permission GPS refusée: $permission');
      return false;
    }

    return true;
  }

  /// Builds platform-safe LocationSettings across Mobile (Android/iOS) and Web.
  LocationSettings _buildLocationSettings(LocationTrackingMode mode) {
    if (kIsWeb) {
      // Configuration optimale pour Google Chrome / HTML5 Geolocation API
      return LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: mode.distanceFilterMeters,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // Android FusedLocationProvider / GNSS haute précision
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: mode.distanceFilterMeters,
        intervalDuration: mode.sampleInterval,
        forceLocationManager: false,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: mode.distanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return LocationSettings(
      accuracy: mode.desiredAccuracy,
      distanceFilter: mode.distanceFilterMeters,
    );
  }

  /// Obtains the most accurate immediate position filtered and validated.
  Future<GeoPosition> getCurrentPosition({
    LocationTrackingMode mode = LocationTrackingMode.searching,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final hasPermission = await ensurePermission();
    if (!hasPermission) {
      throw Exception('Permission de localisation requise pour continuer.');
    }

    final settings = _buildLocationSettings(mode);
    final rawPos = await Geolocator.getCurrentPosition(
      locationSettings: settings,
    ).timeout(timeout);

    final rawGeo = GeoPosition.fromPosition(rawPos);
    _lastRawPosition = rawGeo;
    _logStage('RAW GPS POSITION', rawGeo);

    final validated = _pipeline.process(rawGeo) ?? rawGeo;
    _lastFilteredPosition = validated;
    _logStage('FILTERED POSITION', validated);

    return validated;
  }

  /// Starts continuous tracking stream adapting frequency and accuracy to [mode].
  Future<void> startTracking(LocationTrackingMode mode) async {
    final request = ++_trackingStartRequest;
    _currentMode = mode;
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final hasPermission = await ensurePermission();
    if (request != _trackingStartRequest) return;
    if (!hasPermission) {
      debugPrint('[LOCATION] Impossible de démarrer le tracking : permission manquante.');
      return;
    }

    final settings = _buildLocationSettings(mode);

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (rawPos) {
        final rawGeo = GeoPosition.fromPosition(rawPos);
        _lastRawPosition = rawGeo;
        _logStage('RAW GPS POSITION', rawGeo);

        final filtered = _pipeline.process(rawGeo);
        if (filtered != null) {
          _lastFilteredPosition = filtered;
          _logStage('FILTERED POSITION', filtered);
          _positionController.add(filtered);
        } else {
          debugPrint('[FILTERED POSITION] Point brut rejeté par le filtre (bruit/saut excessif)');
        }
      },
      onError: (err) {
        debugPrint('[LOCATION] Erreur stream GPS : $err');
      },
    );
  }

  /// Changes the tracking mode dynamically (e.g. from Searching to ActiveTrip).
  Future<void> setMode(LocationTrackingMode mode) async {
    if (_currentMode != mode) {
      await startTracking(mode);
    }
  }

  /// Stops continuous GPS tracking to preserve battery.
  Future<void> stopTracking() async {
    _currentMode = LocationTrackingMode.idle;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _logStage(String stage, GeoPosition pos) {
    debugPrint(
      '[$stage] lat=${pos.latitude.toStringAsFixed(6)} lng=${pos.longitude.toStringAsFixed(6)} '
      'accuracy=${pos.accuracy.toStringAsFixed(1)}m speed=${pos.speedKmh.toStringAsFixed(1)}km/h '
      'heading=${pos.heading.toStringAsFixed(0)}° provider=${pos.provider} ts=${pos.timestamp.toIso8601String()}',
    );
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
