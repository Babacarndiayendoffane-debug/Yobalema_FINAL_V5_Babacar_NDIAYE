import 'package:latlong2/latlong.dart';
import '../../models/commune.dart';
import 'geo_position.dart';

/// Unified representation of a named geographical point/location in Yobalema.
class GeoPoint {
  final String name;
  final String department;
  final GeoPosition position;
  final ZoneType zone;
  final String region;
  final String description;

  const GeoPoint({
    required this.name,
    required this.department,
    required this.position,
    this.zone = ZoneType.city,
    this.region = 'Kaolack',
    this.description = '',
  });

  factory GeoPoint.fromCommune(Commune commune) {
    return GeoPoint(
      name: commune.name,
      department: commune.department,
      position: GeoPosition.fromLatLng(commune.point),
      zone: commune.zone,
      region: commune.region,
      description: commune.description,
    );
  }

  factory GeoPoint.fromCoordinates({
    required String name,
    required double latitude,
    required double longitude,
    String department = 'Kaolack',
    ZoneType zone = ZoneType.city,
    String region = 'Kaolack',
    String description = '',
    double accuracy = 0.0,
  }) {
    return GeoPoint(
      name: name,
      department: department,
      position: GeoPosition(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: DateTime.now(),
      ),
      zone: zone,
      region: region,
      description: description,
    );
  }

  LatLng get point => position.toLatLng();
  double get latitude => position.latitude;
  double get longitude => position.longitude;

  String get zoneString {
    switch (zone) {
      case ZoneType.city:
        return 'CITY';
      case ZoneType.periurban:
        return 'PERIURBAN';
      case ZoneType.village:
        return 'VILLAGE';
    }
  }

  Commune toCommune() {
    return Commune(
      name,
      department,
      point,
      zone,
      region,
      description,
    );
  }

  @override
  String toString() => 'GeoPoint($name @ ${position.latitude}, ${position.longitude})';
}
