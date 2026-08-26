import 'package:latlong2/latlong.dart';

enum Role { passenger, driver }
enum ZoneType { city, periurban, village }

class Commune {
  final String name;
  final String department;
  final LatLng point;
  final ZoneType zone;

  const Commune(this.name, this.department, this.point, this.zone);
}

class PriceQuote {
  final int total;
  final int driver;
  final int platform;
  final double trafficFactor;
  final String explanation;

  const PriceQuote({
    required this.total,
    required this.driver,
    required this.platform,
    required this.trafficFactor,
    required this.explanation,
  });
}

class RideModel {
  final String id;
  final String from;
  final String to;
  final int price;
  final String status;
  final String paymentMethod;
  final DateTime date;

  RideModel({
    required this.id,
    required this.from,
    required this.to,
    required this.price,
    required this.status,
    required this.paymentMethod,
    required this.date,
  });
}

class RegionKaolack {
  static const communes = <Commune>[
    Commune('Kaolack (Centre)', 'Kaolack', LatLng(14.1510, -16.0726), ZoneType.city),
    Commune('Kahone', 'Kaolack', LatLng(14.1560, -16.0400), ZoneType.periurban),
    Commune('Ndoffane', 'Kaolack', LatLng(13.8447, -15.9382), ZoneType.city),
    Commune('Keur Soce', 'Kaolack', LatLng(14.0100, -16.0300), ZoneType.village),
    Commune('Ndiaffate', 'Kaolack', LatLng(14.1200, -16.0000), ZoneType.village),
    Commune('Ndiedieng', 'Kaolack', LatLng(14.0800, -15.9700), ZoneType.village),
    Commune('Latmingue', 'Kaolack', LatLng(14.2700, -15.9800), ZoneType.village),
    Commune('Thiare', 'Kaolack', LatLng(13.9800, -15.9000), ZoneType.village),
    Commune('Keur Baka', 'Kaolack', LatLng(13.9900, -16.1000), ZoneType.village),
    Commune('Dya', 'Kaolack', LatLng(14.0200, -16.1300), ZoneType.village),
    Commune('Ndiebel', 'Kaolack', LatLng(14.0900, -15.8800), ZoneType.village),
    Commune('Thiomby', 'Kaolack', LatLng(13.9000, -16.0200), ZoneType.village),
    Commune('Gandiaye', 'Kaolack', LatLng(14.2300, -16.3200), ZoneType.village),
    Commune('Sibassor', 'Kaolack', LatLng(14.1500, -16.0000), ZoneType.periurban),
    Commune('Nioro du Rip', 'Nioro du Rip', LatLng(13.7500, -15.7800), ZoneType.city),
    Commune('Keur Madiabel', 'Nioro du Rip', LatLng(13.8500, -15.8500), ZoneType.village),
    Commune('Medina Sabakh', 'Nioro du Rip', LatLng(13.8500, -15.5500), ZoneType.village),
    Commune('Ngayene', 'Nioro du Rip', LatLng(13.6500, -15.7000), ZoneType.village),
    Commune('Kayemor', 'Nioro du Rip', LatLng(13.6500, -15.9000), ZoneType.village),
    Commune('Paoskoto', 'Nioro du Rip', LatLng(13.6500, -15.6000), ZoneType.village),
    Commune('Porokhane', 'Nioro du Rip', LatLng(13.8000, -15.7000), ZoneType.village),
    Commune('Guinguineo', 'Guinguineo', LatLng(14.2700, -15.9500), ZoneType.city),
    Commune('Mbadakhoune', 'Guinguineo', LatLng(14.3000, -15.8500), ZoneType.village),
    Commune('Ngathie Naoude', 'Guinguineo', LatLng(14.3500, -15.9500), ZoneType.village),
    Commune('Fass', 'Guinguineo', LatLng(14.2500, -15.8000), ZoneType.village),
  ];

  static bool inKaolack(LatLng p) =>
      p.latitude >= 13.50 &&
      p.latitude <= 14.55 &&
      p.longitude >= -16.45 &&
      p.longitude <= -15.35;
}

class Pricing {
  static const double commission = 0.10;

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
    final isEveningPeak = minutes >= (17 * 60 + 30) && minutes <= (19 * 60 + 30);
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
      explanation = 'Tarif urbain : distance + trafic estimé.';
    } else if (zone == ZoneType.periurban) {
      base = 500 + km * 85;
      explanation = 'Tarif périurbain : distance + disponibilité.';
    } else {
      base = 350 + km * 95;
      explanation = 'Tarif intercommunal : distance + conditions de route.';
    }

    var total = base * trafficFactor(zone: zone, trafficLevel: traffic);
    if (isNight) total += zone == ZoneType.village ? 100 : 200;

    total = total.clamp(300, 5000);
    final rounded = ((total / 50).round() * 50).toInt();
    final driver = (rounded * 0.90).round();
    final platform = rounded - driver;

    return PriceQuote(
      total: rounded,
      driver: driver,
      platform: platform,
      trafficFactor: trafficFactor(zone: zone, trafficLevel: traffic),
      explanation: explanation,
    );
  }
}
