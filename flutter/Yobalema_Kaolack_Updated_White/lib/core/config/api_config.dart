class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'YobalemaApiUrl',
    defaultValue: 'http://10.0.2.2:4000',
  );

  static Uri uri(String path, {Map<String, String>? queryParameters}) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
}
