import 'package:flutter/foundation.dart';

class ApiConfig {
  static final String baseUrl = (() {
    const env = String.fromEnvironment('YobalemaApiUrl', defaultValue: '');
    if (env.isNotEmpty) return env;
    if (kIsWeb) return 'http://localhost:4000';
    return 'http://10.0.2.2:4000';
  })();
}
