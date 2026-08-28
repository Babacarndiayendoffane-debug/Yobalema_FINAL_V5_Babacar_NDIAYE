enum RideStatus { requested, driverAssigned, driverArriving, inProgress, paymentPending, completed, cancelled }

enum PaymentMethod { cash, wave, orangeMoney }

class Ride {
  final String id;
  final String fromName;
  final String toName;
  final int price;
  final RideStatus status;
  final PaymentMethod paymentMethod;

  const Ride({required this.id, required this.fromName, required this.toName, required this.price, required this.status, required this.paymentMethod});

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
    id: json['id']?.toString() ?? '',
    fromName: json['fromName']?.toString() ?? '',
    toName: json['toName']?.toString() ?? '',
    price: (json['price'] as num?)?.round() ?? 0,
    status: _statusFrom(json['status']?.toString()),
    paymentMethod: _paymentFrom(json['paymentMethod']?.toString()),
  );

  static RideStatus _statusFrom(String? value) => switch (value) {
    'DRIVER_ASSIGNED' => RideStatus.driverAssigned,
    'DRIVER_ARRIVING' => RideStatus.driverArriving,
    'IN_PROGRESS' => RideStatus.inProgress,
    'PAYMENT_PENDING' => RideStatus.paymentPending,
    'COMPLETED' => RideStatus.completed,
    'CANCELLED' => RideStatus.cancelled,
    _ => RideStatus.requested,
  };

  static PaymentMethod _paymentFrom(String? value) => switch (value) {
    'WAVE' => PaymentMethod.wave,
    'ORANGE_MONEY' => PaymentMethod.orangeMoney,
    _ => PaymentMethod.cash,
  };
}
