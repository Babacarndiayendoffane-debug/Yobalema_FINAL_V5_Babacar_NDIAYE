import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yobalema/main.dart';
import 'package:yobalema/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeScreen recalculates route and price when dropdown selection changes', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        role: Role.passenger,
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
    expect(find.byType(DropdownButtonFormField<Commune>), findsNWidgets(2));

    // Vérifier l'absence totale de boutons trafic/moment et commissions
    expect(find.text('Trafic'), findsNothing);
    expect(find.text('Moment'), findsNothing);
    expect(find.textContaining('90 %'), findsNothing);

    // Vérifier la présence du tracé polyline
    expect(find.byType(PolylineLayer), findsOneWidget);

    // Changer la destination vers Kahone
    final dropdowns = find.byType(DropdownButtonFormField<Commune>);
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();

    final destinationItem = find.text('Kahone - Kaolack').last;
    await tester.tap(destinationItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Vérifier que le recalcul s'est exécuté sans erreur
    expect(find.text('Prix estimé'), findsOneWidget);
    expect(find.textContaining('FCFA'), findsWidgets);
  });
}
