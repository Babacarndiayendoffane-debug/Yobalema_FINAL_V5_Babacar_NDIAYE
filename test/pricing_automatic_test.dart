import 'package:flutter_test/flutter_test.dart';
import 'package:yobalema/core/models/commune.dart';
import 'package:yobalema/core/services/pricing_engine.dart';

void main() {
  group('Pricing Automatic Context & Rules', () {
    test('isNightTime accurately identifies Day and Night intervals', () {
      // Nuit : 20h00 -> 06h00
      expect(Pricing.isNightTime(DateTime(2026, 1, 1, 20, 0)), isTrue);
      expect(Pricing.isNightTime(DateTime(2026, 1, 1, 23, 45)), isTrue);
      expect(Pricing.isNightTime(DateTime(2026, 1, 1, 0, 0)), isTrue);
      expect(Pricing.isNightTime(DateTime(2026, 1, 1, 5, 59)), isTrue);

      // Jour : 06h00 -> 20h00
      expect(Pricing.isNightTime(DateTime(2026, 1, 1, 6, 0)), isFalse);
      expect(Pricing.isNightTime(DateTime(2026, 1, 1, 12, 30)), isFalse);
      expect(Pricing.isNightTime(DateTime(2026, 1, 1, 19, 59)), isFalse);
    });

    test('estimatedTrafficLevel accurately detects peak vs normal hours', () {
      // Pointe Matin : 07h30 -> 09h30
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 7, 30)), 2);
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 8, 15)), 2);
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 9, 30)), 2);

      // Normal Journée
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 11, 0)), 0);
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 15, 0)), 0);

      // Pointe Soir : 17h30 -> 19h30
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 17, 30)), 2);
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 18, 45)), 2);
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 19, 30)), 2);

      // Normal Soir / Nuit
      expect(Pricing.estimatedTrafficLevel(DateTime(2026, 1, 1, 21, 0)), 0);
    });

    test('Pricing.calculate respects the regional maximum fare', () {
      final quote = Pricing.calculate(
        km: 1000.0,
        fromZone: ZoneType.village,
        toZone: ZoneType.village,
        night: false,
        trafficLevel: 0,
      );

      expect(quote.total, 25000);
      expect(quote.driver + quote.platform, quote.total);
    });

    test('Pricing.calculate integrates automatic context seamlessly', () {
      final daytimeDate = DateTime(2026, 1, 1, 14, 0); // Jour, normal
      final quoteDay = Pricing.calculate(
        km: 10.0,
        fromZone: ZoneType.city,
        toZone: ZoneType.city,
        dateTime: daytimeDate,
      );

      final nightDate = DateTime(2026, 1, 1, 22, 0); // Nuit (+200 F)
      final quoteNight = Pricing.calculate(
        km: 10.0,
        fromZone: ZoneType.city,
        toZone: ZoneType.city,
        dateTime: nightDate,
      );

      expect(quoteNight.total, greaterThan(quoteDay.total));
      expect(quoteNight.total - quoteDay.total, 200);
    });
  });
}
