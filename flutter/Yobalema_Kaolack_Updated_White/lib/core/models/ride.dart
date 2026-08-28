import 'payment.dart';
import 'ride_status.dart';

class Ride {
  final String id;
  final String fromName;
  final String toName;
  final int priceFcfa;
  final RideStatus status;
  final PaymentMethod paymentMethod;
  final String? driverId;

  const Ride({
    required this.id,
    required this.fromName,
    required this.toName,
    required this.priceFcfa,
    required this.status,
    required this.paymentMethod,
    this.driverId,
  });

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id']?.toString() ?? '',
        fromName: json['fromName']?.toString() ?? '',
        toName: json['toName']?.toString() ?? '',
        priceFcfa: (json['priceFcfa'] as num?)?.round() ??
            (json['price'] as num?)?.round() ??
            0,
        status: RideStatusX.fromApi(json['status']?.toString()),
        paymentMethod:
            PaymentMethodX.fromApi(json['paymentMethod']?.toString()),
        driverId: json['driverId']?.toString(),
      );

  bool get isTerminal => status.isTerminal;
}

extension PaymentMethodX on PaymentMethod {
  String get apiValue => switch (this) {
        PaymentMethod.cash => 'CASH',
        PaymentMethod.wave => 'WAVE',
        PaymentMethod.orangeMoney => 'ORANGE_MONEY',
      };

  static PaymentMethod fromApi(String? value) => switch (value?.toUpperCase()) {
        'WAVE' => PaymentMethod.wave,
        'ORANGE_MONEY' => PaymentMethod.orangeMoney,
        _ => PaymentMethod.cash,
      };
}
