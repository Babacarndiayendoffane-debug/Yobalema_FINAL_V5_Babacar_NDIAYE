import 'package:flutter_test/flutter_test.dart';

import 'package:yobalema/core/app/app_services.dart';
import 'package:yobalema/passenger/passenger_features.dart';

void main() {
  testWidgets('Passenger app shell loads', (WidgetTester tester) async {
    final services = AppServices();
    addTearDown(services.dispose);

    await tester.pumpWidget(PassengerFeatureApp(services: services));

    expect(find.text('Yobalema Passenger'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
  });
}
