import 'package:flutter/material.dart';

import '../core/app/app_services.dart';
import 'auth/passenger_auth_screen_v2.dart';

class PassengerFeatureApp extends StatelessWidget {
  const PassengerFeatureApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yobalema Passenger',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFCC00),
      ),
      home: PassengerAuthScreenV2(api: services.apiClient),
    );
  }
}
