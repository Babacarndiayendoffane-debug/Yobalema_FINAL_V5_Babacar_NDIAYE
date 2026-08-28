import 'package:flutter/material.dart';

import '../core/app/app_services.dart';
import 'auth/driver_auth_screen_v2.dart';

class DriverFeatureApp extends StatelessWidget {
  const DriverFeatureApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yobalema Driver',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF159947),
      ),
      home: DriverAuthScreenV2(api: services.apiClient),
    );
  }
}
