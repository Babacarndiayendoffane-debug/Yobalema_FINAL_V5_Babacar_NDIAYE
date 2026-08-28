class Wallet {
  final String driverId;
  final int balanceFcfa;
  final int totalEarnedFcfa;
  final int totalPlatformFeesFcfa;

  const Wallet({
    required this.driverId,
    required this.balanceFcfa,
    required this.totalEarnedFcfa,
    required this.totalPlatformFeesFcfa,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        driverId: json['driverId']?.toString() ?? '',
        balanceFcfa: (json['balanceFcfa'] as num?)?.round() ??
            (json['balance'] as num?)?.round() ?? 0,
        totalEarnedFcfa: (json['totalEarnedFcfa'] as num?)?.round() ??
            (json['totalEarned'] as num?)?.round() ?? 0,
        totalPlatformFeesFcfa:
            (json['totalPlatformFeesFcfa'] as num?)?.round() ?? 0,
      );
}
