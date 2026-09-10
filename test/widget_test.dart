import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yobalema/driver/screens/driver_auth_screen.dart';
import 'package:yobalema/main_driver.dart';
import 'package:yobalema/main_passenger.dart';
import 'package:yobalema/passenger/screens/passenger_auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('official passenger flow opens authentication and registration',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: PassengerRootFlow()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PassengerAuthScreen), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);

    await tester.tap(find.text('Nouveau sur Yobalema ? Créer un compte'));
    await tester.pump();

    expect(find.text('Créer un compte Passager'), findsOneWidget);
    expect(find.text("S'inscrire"), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
  });

  testWidgets('official driver flow opens authentication and registration',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: DriverRootFlow()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(DriverAuthScreen), findsOneWidget);
    expect(find.text('Accéder au Cockpit'), findsOneWidget);

    await tester.tap(find.text("Nouveau chauffeur ? S'inscrire"));
    await tester.pump();

    expect(find.text('Devenir Chauffeur Partenaire'), findsOneWidget);
    expect(find.text('Créer mon compte Chauffeur'), findsOneWidget);
    expect(find.text('Immatriculation (ex: KL-1234-A / DK-...)'), findsOneWidget);
  });
}

