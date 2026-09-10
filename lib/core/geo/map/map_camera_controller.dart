import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Manages camera tracking modes (Follow Vehicle vs. User Manual Exploration)
class MapCameraTracker {
  final MapController mapController;
  bool isFollowing = true;

  MapCameraTracker({required this.mapController});

  /// Called when a new vehicle/GPS position arrives.
  /// If [isFollowing] is true, smoothly moves camera to position.
  void onPositionUpdate(LatLng point, {double zoom = 15.0}) {
    if (isFollowing) {
      try {
        mapController.move(point, zoom);
      } catch (_) {}
    }
  }

  /// User panned or zoomed the map manually -> disable auto follow
  void onUserManualPan() {
    isFollowing = false;
  }

  /// Re-enable auto follow and recenter immediately on [targetPoint]
  void recenter(LatLng targetPoint, {double zoom = 15.0}) {
    isFollowing = true;
    try {
      mapController.move(targetPoint, zoom);
    } catch (_) {}
  }
}
