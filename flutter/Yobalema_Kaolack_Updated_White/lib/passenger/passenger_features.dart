import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import 'auth/passenger_auth_screen_v2.dart';

class PassengerFeatureApp extends StatefulWidget {
  const PassengerFeatureApp({super.key});

  @override
  State<PassengerFeatureApp> createState() => _PassengerFeatureAppState();
}

class _PassengerFeatureAppState extends State<PassengerFeatureApp> {
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yobalema Passenger',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFCC00),
      ),
      home: PassengerAuthScreenV2(api: _api),
    );
  }
}
