import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yobalema/core/api/yobalema_api.dart';
import 'package:yobalema/passenger/screens/passenger_main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PassengerMainScreen recalculates route and price after destination selection', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MaterialApp(
      home: PassengerMainScreen(
        phone: '+221770000000',
        api: YobalemaApi(),
        user: const {'id': 'test-user', 'phone': '+221770000000', 'role': 'PASSENGER'},
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Vérifier la présence du titre épuré et des sélecteurs
    expect(find.text('Prix estimé'), findsOneWidget);
    expect(find.textContaining('FCFA'), findsWidgets);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);

    // Vérifier la présence du tracé polyline
    expect(find.byType(PolylineLayer), findsOneWidget);

    // Changer la destination vers Kahone
    await tester.tap(find.text('Destination'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir la destination'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kahone');
    await tester.pump();
    expect(find.text('Kahone (Centre / Cité Ouvrière)'), findsOneWidget);

    await tester.tap(find.text('Kahone (Centre / Cité Ouvrière)'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Choisir la destination'), findsNothing);

    // Vérifier que le recalcul s'est exécuté sans erreur
    expect(find.text('Prix estimé'), findsOneWidget);
    expect(find.textContaining('FCFA'), findsWidgets);
  });
}
