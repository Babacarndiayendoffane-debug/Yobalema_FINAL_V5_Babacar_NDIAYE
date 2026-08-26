import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yobalema/main.dart';
import 'package:yobalema/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Role Navigation & Dedicated Screens Tests', () {
    testWidgets('Passenger role navigates directly to PassengerScreen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          role: Role.passenger,
          phone: '+221770000001',
          api: YobalemaApi(),
          user: const {'id': 'user-pass', 'phone': '+221770000001', 'role': 'PASSENGER'},
        ),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PassengerScreen), findsOneWidget);
      expect(find.byType(DriverScreen), findsNothing);

      // Le passager ne voit aucun outil chauffeur ni mention 90/10
      expect(find.text('Espace Chauffeur'), findsNothing);
      expect(find.textContaining('90 %'), findsNothing);
      expect(find.text('Prix estimé'), findsOneWidget);
    });

    testWidgets('Driver role navigates directly to DriverScreen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          role: Role.driver,
          phone: '+221770000002',
          api: YobalemaApi(),
          user: const {'id': 'user-driver', 'phone': '+221770000002', 'role': 'DRIVER'},
        ),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DriverScreen), findsOneWidget);
      expect(find.byType(PassengerScreen), findsNothing);

      // Le chauffeur voit son espace dédié et son statut
      expect(find.text('Espace Chauffeur'), findsOneWidget);
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
      expect(find.textContaining('Commission garantie : 90 % chauffeur - 10 % Yobalema'), findsOneWidget);
    });
  });
}
