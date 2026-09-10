import 'package:latlong2/latlong.dart';

enum ZoneType { city, periurban, village }

class Commune {
  final String name;
  final String department;
  final LatLng point;
  final ZoneType zone;
  final String region;
  final String description;

  const Commune(
    this.name,
    this.department,
    this.point,
    this.zone, [
    this.region = 'Kaolack',
    this.description = '',
  ]);

  String get shortName {
    final idx = name.indexOf('(');
    if (idx != -1) return name.substring(0, idx).trim();
    final idxSlash = name.indexOf('/');
    if (idxSlash != -1) return name.substring(0, idxSlash).trim();
    return name;
  }

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Commune &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          point.latitude == other.point.latitude &&
          point.longitude == other.point.longitude;

  @override
  int get hashCode =>
      name.hashCode ^ point.latitude.hashCode ^ point.longitude.hashCode;
}
