enum RideStatus {
  requested,
  driverAssigned,
  driverArriving,
  inProgress,
  paymentPending,
  completed,
  cancelled,
}

extension RideStatusX on RideStatus {
  String get apiValue => switch (this) {
        RideStatus.requested => 'REQUESTED',
        RideStatus.driverAssigned => 'DRIVER_ASSIGNED',
        RideStatus.driverArriving => 'DRIVER_ARRIVING',
        RideStatus.inProgress => 'IN_PROGRESS',
        RideStatus.paymentPending => 'PAYMENT_PENDING',
        RideStatus.completed => 'COMPLETED',
        RideStatus.cancelled => 'CANCELLED',
      };

  static RideStatus fromApi(String? value) => switch (value?.trim().toUpperCase()) {
        'REQUESTED' => RideStatus.requested,
        'DRIVER_ASSIGNED' => RideStatus.driverAssigned,
        'DRIVER_ARRIVING' => RideStatus.driverArriving,
        'IN_PROGRESS' => RideStatus.inProgress,
        'PAYMENT_PENDING' => RideStatus.paymentPending,
        'COMPLETED' => RideStatus.completed,
        'CANCELLED' => RideStatus.cancelled,
        _ => RideStatus.requested,
      };

  bool get isTerminal => this == RideStatus.completed || this == RideStatus.cancelled;
}
