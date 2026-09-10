import '../models/commune.dart';
import '../models/price_quote.dart';

class Pricing {
  /// Commission Yobalema strictement fixée à 10% (Chauffeur = 90%)
  static const double commissionRate = 0.10;
  static const int maxFare = 25000; // Cap pour trajets intercommunaux longue distance dans la région
  static const int minFare = 300; // Tarif minimum Moto

  /// Détermine automatiquement le mode Jour/Nuit selon l'heure locale :
  /// - Nuit : 20h00 -> 06h00 (inclus)
  /// - Jour : 06h00 -> 20h00
  static bool isNightTime([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    return hour >= 20 || hour < 6;
  }

  /// Détermine le niveau de trafic estimé selon les créneaux horaires :
  /// - Pointe matin : 07h30 -> 09h30
  /// - Pointe soir : 17h30 -> 19h30
  /// - Normal sinon
  static int estimatedTrafficLevel([DateTime? now]) {
    final time = now ?? DateTime.now();
    final minutes = time.hour * 60 + time.minute;
    final isMorningPeak = minutes >= (7 * 60 + 30) && minutes <= (9 * 60 + 30);
    final isEveningPeak =
        minutes >= (17 * 60 + 30) && minutes <= (19 * 60 + 30);
    if (isMorningPeak || isEveningPeak) return 2;
    return 0;
  }

  static double trafficFactor({
    required ZoneType zone,
    required int trafficLevel,
  }) {
    if (zone == ZoneType.village) return 1.0;
    if (trafficLevel <= 0) return 1.0;
    if (trafficLevel == 1) return 1.05;
    if (trafficLevel == 2) return 1.10;
    return 1.15;
  }

  static PriceQuote calculate({
    required double km,
    required ZoneType fromZone,
    required ZoneType toZone,
    int? trafficLevel,
    bool? night,
    DateTime? dateTime,
    String serviceType = 'MOTO',
  }) {
    final isNight = night ?? isNightTime(dateTime);
    final traffic = trafficLevel ?? estimatedTrafficLevel(dateTime);

    final zone = fromZone == ZoneType.city || toZone == ZoneType.city
        ? ZoneType.city
        : (fromZone == ZoneType.periurban || toZone == ZoneType.periurban
            ? ZoneType.periurban
            : ZoneType.village);

    double base;
    String explanation;

    if (zone == ZoneType.city) {
      if (km <= 2) {
        base = 300;
      } else if (km <= 4) {
        base = 400;
      } else if (km <= 6) {
        base = 500;
      } else if (km <= 10) {
        base = 700;
      } else {
        base = 700 + (km - 10) * 75;
      }
      explanation = 'Tarif Moto urbain : distance routière + trafic estimé.';
    } else if (zone == ZoneType.periurban) {
      base = 500 + km * 85;
      explanation = 'Tarif Moto périurbain : distance routière + disponibilité.';
    } else {
      base = 350 + km * 95;
      explanation =
          'Tarif Moto intercommunal : distance routière + conditions de route.';
    }

    var total = base * trafficFactor(zone: zone, trafficLevel: traffic);
    if (isNight) total += zone == ZoneType.village ? 100 : 200;

    total = total.clamp(minFare.toDouble(), maxFare.toDouble());
    final rounded = ((total / 50).round() * 50).toInt();

    // Règle 10% commission plateforme = 10%, chauffeur = 90%
    final driver = (rounded * (1.0 - commissionRate)).round();
    final platform = rounded - driver;
    final normalizedServiceType = serviceType.trim().toUpperCase();
    final effectiveServiceType = normalizedServiceType == 'MOTO'
        ? normalizedServiceType
        : 'MOTO';

    return PriceQuote(
      total: rounded,
      driver: driver,
      platform: platform,
      trafficFactor: trafficFactor(zone: zone, trafficLevel: traffic),
      explanation: explanation,
      serviceType: effectiveServiceType,
    );
  }
}

