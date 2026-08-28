enum PaymentMethod { cash, wave, orangeMoney }

enum PaymentStatus { pending, processing, paid, failed, refunded }

class Payment {
  final String id;
  final String rideId;
  final int amountFcfa;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? providerReference;

  const Payment({
    required this.id,
    required this.rideId,
    required this.amountFcfa,
    required this.method,
    required this.status,
    this.providerReference,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id']?.toString() ?? '',
        rideId: json['rideId']?.toString() ?? '',
        amountFcfa: (json['amountFcfa'] as num?)?.round() ??
            (json['amount'] as num?)?.round() ?? 0,
        method: _method(json['paymentMethod']?.toString()),
        status: _status(json['status']?.toString()),
        providerReference: json['providerRef']?.toString(),
      );

  static PaymentMethod _method(String? value) => switch (value?.toUpperCase()) {
        'WAVE' => PaymentMethod.wave,
        'ORANGE_MONEY' => PaymentMethod.orangeMoney,
        _ => PaymentMethod.cash,
      };

  static PaymentStatus _status(String? value) => switch (value?.toUpperCase()) {
        'PROCESSING' => PaymentStatus.processing,
        'PAID', 'SUCCESS', 'COMPLETED' => PaymentStatus.paid,
        'FAILED' => PaymentStatus.failed,
        'REFUNDED' => PaymentStatus.refunded,
        _ => PaymentStatus.pending,
      };
}
