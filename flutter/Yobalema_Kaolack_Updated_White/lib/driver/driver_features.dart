import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import 'auth/driver_auth_screen_v2.dart';

class DriverFeatureApp extends StatefulWidget {
  const DriverFeatureApp({super.key});

  @override
  State<DriverFeatureApp> createState() => _DriverFeatureAppState();
}

class _DriverFeatureAppState extends State<DriverFeatureApp> {
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
      title: 'Yobalema Driver',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF159947),
      ),
      home: DriverAuthScreenV2(api: _api),
    );
  }
}
