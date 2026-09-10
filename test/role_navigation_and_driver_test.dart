import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yobalema/core/api/yobalema_api.dart';
import 'package:yobalema/driver/screens/driver_main_screen.dart';
import 'package:yobalema/passenger/screens/passenger_main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Role Navigation & Dedicated Screens Tests', () {
    testWidgets('Passenger role navigates directly to PassengerScreen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(MaterialApp(
        home: PassengerMainScreen(
          phone: '+221770000001',
          api: YobalemaApi(),
          user: const {'id': 'user-pass', 'phone': '+221770000001', 'role': 'PASSENGER'},
        ),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PassengerMainScreen), findsOneWidget);
      expect(find.byType(DriverMainScreen), findsNothing);

      // Le passager ne voit aucun outil chauffeur ni mention 90/10
      expect(find.text('Espace Chauffeur'), findsNothing);
      expect(find.textContaining('90 %'), findsNothing);
      expect(find.text('Prix estimé'), findsOneWidget);
    });

    testWidgets('Driver role navigates directly to DriverScreen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(MaterialApp(
        home: DriverMainScreen(
          phone: '+221770000002',
          api: YobalemaApi(),
          user: const {'id': 'user-driver', 'phone': '+221770000002', 'role': 'DRIVER'},
        ),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DriverMainScreen), findsOneWidget);
      expect(find.byType(PassengerMainScreen), findsNothing);

      // Le chauffeur voit son statut et ses commandes dédiées.
      expect(find.text('HORS LIGNE'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.textContaining('HORS LIGNE'), findsOneWidget);

      // Tester le passage en ligne
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('EN LIGNE'), findsOneWidget);

      // Tester l'ouverture du portefeuille
      final walletButton = find.byIcon(Icons.account_balance_wallet);
      expect(walletButton, findsOneWidget);
      await tester.tap(walletButton);
      await tester.pumpAndSettle();

      expect(find.text('Portefeuille Chauffeur'), findsOneWidget);
      expect(find.text('Commission Yobalema fixée à 10% sur chaque course.'), findsOneWidget);
    });
  });
}
