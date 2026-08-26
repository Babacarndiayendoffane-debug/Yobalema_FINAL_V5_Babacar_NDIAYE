import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yobalema/main.dart';
import 'package:yobalema/screens/auth/register_driver.dart';
import 'package:yobalema/screens/auth/register_passenger.dart';
import 'package:yobalema/screens/auth/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Scenario lifecycle - Login, Logout, Register Driver & Passenger without unmounted error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // 1. Ouvrir l'application
    await tester.pumpWidget(const YobalemaApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Yobalema'), findsOneWidget);
    expect(find.textContaining('Continuer'), findsOneWidget);

    // 2. Entrer comme passager (Mode Démo)
    await tester.tap(find.textContaining('Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 3. Arriver dans l'application (HomeScreen)
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    // 4. Quitter / retour à l'écran d'accueil
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Vérifier retour sur AuthHome
    expect(find.text('Devenir chauffeur'), findsOneWidget);

    // 5. Tester "Devenir chauffeur"
    await tester.tap(find.text('Devenir chauffeur'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RegisterDriverScreen), findsOneWidget);

    // Revenir à AuthHome
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 6. Tester "S'inscrire (Passager)"
    await tester.tap(find.text("S'inscrire (Passager)"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RegisterPassengerScreen), findsOneWidget);

    // Revenir à AuthHome
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 7. Tester "Se connecter"
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
