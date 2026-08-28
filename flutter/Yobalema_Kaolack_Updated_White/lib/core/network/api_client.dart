import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token case final value? when value.isNotEmpty)
          'Authorization': 'Bearer $value',
      };

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? query,
  }) async {
    final data = await _request('GET', path, query: query);
    return _asMap(data);
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final data = await _request('GET', path, query: query);
    return data is List ? data : <dynamic>[];
  }

  Future<Map<String, dynamic>> postMap(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    return _asMap(await _request('POST', path, body: body));
  }

  Future<Map<String, dynamic>> patchMap(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    return _asMap(await _request('PATCH', path, body: body));
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = ApiConfig.uri(path, queryParameters: query);
    final encoded = body == null ? null : jsonEncode(body);

    final response = switch (method) {
      'GET' => await _client.get(uri, headers: _headers),
      'POST' => await _client.post(uri, headers: _headers, body: encoded),
      'PATCH' => await _client.patch(uri, headers: _headers, body: encoded),
      _ => throw ArgumentError('Unsupported HTTP method: $method'),
    };

    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      throw ApiException('Réponse serveur invalide.', statusCode: response.statusCode);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? (data['message'] ?? data['error'] ?? 'Une erreur est survenue.')
          : 'Une erreur est survenue.';
      throw ApiException(message.toString(), statusCode: response.statusCode);
    }

    return data;
  }

  Map<String, dynamic> _asMap(dynamic data) => data is Map
      ? Map<String, dynamic>.from(data)
      : throw const ApiException('Réponse serveur inattendue.');

  void dispose() => _client.close();
}
