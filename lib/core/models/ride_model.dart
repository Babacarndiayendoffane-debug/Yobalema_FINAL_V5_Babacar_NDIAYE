class RideModel {
  final String id;
  final String from;
  final String to;
  final int price;
  final String status;
  final String paymentMethod;
  final DateTime date;
  final double? distanceKm;
  final String? driverName;
  final String? driverPhone;
  final String? vehiclePlate;
  final String? pickupPin;

  RideModel({
    required this.id,
    required this.from,
    required this.to,
    required this.price,
    required this.status,
    required this.paymentMethod,
    required this.date,
    this.distanceKm,
    this.driverName,
    this.driverPhone,
    this.vehiclePlate,
    this.pickupPin,
  });

  String get formattedPrice {
    final s = price.toString();
    if (s.length > 3) {
      return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
    }
    return s;
  }

  String get formattedStatus {
    switch (status) {
      case 'REQUESTED':
        return 'Recherche de chauffeur...';
      case 'ACCEPTED':
        return 'Chauffeur en route';
      case 'DRIVER_ARRIVING':
        return 'Chauffeur arrivé au départ';
      case 'IN_PROGRESS':
        return 'Course en cours';
      case 'COMPLETED':
        return 'Course terminée';
      case 'CANCELLED':
        return 'Course annulée';
      default:
        return status;
    }
  }
}
