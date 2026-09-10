class PriceQuote {
  final int total;
  final int driver;
  final int platform;
  final double trafficFactor;
  final String explanation;
  final String serviceType; // Yobalema = 100% MOTO

  const PriceQuote({
    required this.total,
    required this.driver,
    required this.platform,
    required this.trafficFactor,
    required this.explanation,
    this.serviceType = 'MOTO',
  });

  String get formattedTotal {
    final s = total.toString();
    if (s.length > 3) {
      return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
    }
    return s;
  }

  String get formattedDriverEarnings {
    final s = driver.toString();
    if (s.length > 3) {
      return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
    }
    return s;
  }
}
