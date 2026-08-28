import 'user.dart';

enum DriverStatus { offline, online, busy }

enum VehicleType { moto }

class Driver {
  final User user;
  final DriverStatus status;
  final VehicleType vehicleType;
  final String vehiclePlate;
  final double? latitude;
  final double? longitude;

  const Driver({
    required this.user,
    required this.status,
    required this.vehicleType,
    required this.vehiclePlate,
    this.latitude,
    this.longitude,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    final statusValue = json['status']?.toString().toUpperCase();
    final vehicleValue = json['vehicleType']?.toString().toUpperCase();

    return Driver(
      user: User.fromJson(json['user'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['user'] as Map)
          : json),
      status: switch (statusValue) {
        'ONLINE' => DriverStatus.online,
        'BUSY' => DriverStatus.busy,
        _ => DriverStatus.offline,
      },
      vehicleType: vehicleValue == 'MOTO'
          ? VehicleType.moto
          : VehicleType.moto,
      vehiclePlate: json['vehiclePlate']?.toString() ?? '',
      latitude: (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble(),
    );
  }
}
