import 'package:flutter/material.dart';
import '../api.dart';
import 'auth/passenger_auth_screen.dart';

class PassengerFeatureApp extends StatefulWidget {
  const PassengerFeatureApp({super.key});
  @override State<PassengerFeatureApp> createState() => _PassengerFeatureAppState();
}
class _PassengerFeatureAppState extends State<PassengerFeatureApp> {
  final api = YobalemaApi();
  @override void dispose() { api.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Yobalema Passenger',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFFFCC00)),
    home: PassengerAuthScreen(api: api),
  );
}
