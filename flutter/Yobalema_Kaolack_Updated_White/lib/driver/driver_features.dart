import 'package:flutter/material.dart';
import '../api.dart';
import 'auth/driver_auth_screen.dart';

class DriverFeatureApp extends StatefulWidget {
  const DriverFeatureApp({super.key});
  @override State<DriverFeatureApp> createState() => _DriverFeatureAppState();
}
class _DriverFeatureAppState extends State<DriverFeatureApp> {
  final api = YobalemaApi();
  @override void dispose() { api.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Yobalema Driver',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF159947)),
    home: DriverAuthScreen(api: api),
  );
}
