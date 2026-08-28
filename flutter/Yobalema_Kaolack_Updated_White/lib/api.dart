import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'YobalemaApiUrl',
    defaultValue: 'http://10.0.2.2:4000',
  );

  static Uri uri(String path, {Map<String, String>? queryParameters}) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class YobalemaApi {
  YobalemaApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? token;
  io.Socket? socket;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final data = await _post('/api/auth/login', {'phone': phone, 'password': password});
    _captureToken(data);
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String name,
    required String role,
  }) async {
    final data = await _post('/api/auth/register', {
      'phone': phone,
      'password': password,
      'name': name,
      'role': role,
    });
    _captureToken(data);
    return data;
  }

  void logout() {
    token = null;
    disconnectSocket();
  }

  Future<Map<String, dynamic>> quote({
    required String fromName,
    required String toName,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required String fromZone,
    required String toZone,
    required int trafficLevel,
    required bool night,
  }) => _post('/api/rides/quote', {
        'fromName': fromName, 'toName': toName,
        'fromLat': fromLat, 'fromLng': fromLng,
        'toLat': toLat, 'toLng': toLng,
        'fromZone': fromZone, 'toZone': toZone,
        'trafficLevel': trafficLevel, 'night': night,
      });

  Future<Map<String, dynamic>> createRide({
    required String fromName,
    required String toName,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required String fromZone,
    required String toZone,
    required int trafficLevel,
    required bool night,
    required bool shareTrip,
    String paymentMethod = 'CASH',
  }) => _post('/api/rides', {
        'fromName': fromName, 'toName': toName,
        'fromLat': fromLat, 'fromLng': fromLng,
        'toLat': toLat, 'toLng': toLng,
        'fromZone': fromZone, 'toZone': toZone,
        'trafficLevel': trafficLevel, 'night': night,
        'shareTrip': shareTrip, 'paymentMethod': paymentMethod,
      });

  Future<Map<String, dynamic>> setDriverStatus(String status) =>
      _patch('/api/drivers/me/status', {'status': status});

  Future<Map<String, dynamic>> updateDriverLocation(double lat, double lng) =>
      _patch('/api/drivers/me/location', {'lat': lat, 'lng': lng});

  Future<List<dynamic>> nearbyDrivers(double lat, double lng) async {
    final data = await _get('/api/drivers/nearby', query: {
      'lat': '$lat', 'lng': '$lng', 'radiusKm': '10',
    });
    return data is List ? data : <dynamic>[];
  }

  Future<Map<String, dynamic>> acceptRide(String id) => _post('/api/rides/$id/accept');
  Future<Map<String, dynamic>> rideStatus(String id, String status) =>
      _patch('/api/rides/$id/status', {'status': status});
  Future<Map<String, dynamic>> requestOtp() => _post('/api/auth/request-otp');
  Future<Map<String, dynamic>> verifyOtp(String code) => _post('/api/auth/verify-otp', {'code': code});
  Future<Map<String, dynamic>> setVehicle(String vehicleType, String vehiclePlate) =>
      _patch('/api/drivers/me/vehicle', {'vehicleType': vehicleType, 'vehiclePlate': vehiclePlate});
  Future<Map<String, dynamic>> requestPickupOtp(String rideId) =>
      _post('/api/rides/$rideId/pickup-otp');
  Future<Map<String, dynamic>> verifyPickup(String rideId, String code) =>
      _post('/api/rides/$rideId/verify-pickup', {'code': code});
  Future<Map<String, dynamic>> confirmPayment(String rideId, String providerRef) =>
      _post('/api/rides/$rideId/payment/confirm', {'providerRef': providerRef});
  Future<Map<String, dynamic>> rateRide(String rideId, int score, {String? comment}) =>
      _post('/api/rides/$rideId/rating', {'score': score, if (comment != null) 'comment': comment});
  Future<Map<String, dynamic>> startPayment(String rideId) =>
      _post('/api/rides/$rideId/payment/start');
  Future<Map<String, dynamic>> driverWallet() => _getMap('/api/drivers/me/wallet');
  Future<Map<String, dynamic>> createSupportTicket(String subject, String message) =>
      _post('/api/support/tickets', {'subject': subject, 'message': message});

  Future<List<dynamic>> notifications() async {
    final data = await _get('/api/notifications');
    return data is List ? data : <dynamic>[];
  }

  Future<void> markNotificationRead(String id) async {
    await _patch('/api/notifications/$id/read');
  }

  Future<List<dynamic>> supportTickets() async {
    final data = await _get('/api/support/tickets');
    return data is List ? data : <dynamic>[];
  }

  void connectSocket({
    void Function(Map<String, dynamic>)? onRideNew,
    void Function(Map<String, dynamic>)? onRideOffer,
    String? userId,
    String? role,
    void Function(Map<String, dynamic>)? onRideAccepted,
    void Function(Map<String, dynamic>)? onRideStatus,
    void Function(Map<String, dynamic>)? onRideLocation,
  }) {
    disconnectSocket();
    socket = io.io(ApiConfig.baseUrl, {
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'auth': {'token': token},
    });

    socket!.onConnect((_) {
      if (userId != null && role == 'DRIVER') socket!.emit('driver:join', userId);
      if (userId != null && role == 'PASSENGER') socket!.emit('passenger:join', userId);
    });
    socket!.on('ride:offer', (data) { if (data is Map) onRideOffer?.call(Map<String, dynamic>.from(data)); });
    socket!.on('ride:new', (data) { if (data is Map) onRideNew?.call(Map<String, dynamic>.from(data)); });
    socket!.on('ride:accepted', (data) { if (data is Map) onRideAccepted?.call(Map<String, dynamic>.from(data)); });
    socket!.on('ride:status', (data) { if (data is Map) onRideStatus?.call(Map<String, dynamic>.from(data)); });
    socket!.on('ride:location', (data) { if (data is Map) onRideLocation?.call(Map<String, dynamic>.from(data)); });
    socket!.connect();
  }

  void joinRide(String rideId) => socket?.emit('ride:join', rideId);

  void disconnectSocket() {
    socket?.off();
    socket?.disconnect();
    socket?.dispose();
    socket = null;
  }

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final response = await _client.get(ApiConfig.uri(path, queryParameters: query), headers: _headers).timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final data = await _get(path);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(ApiConfig.uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 20));
    return _asMap(_decode(response));
  }

  Future<Map<String, dynamic>> _patch(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.patch(ApiConfig.uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 20));
    return _asMap(_decode(response));
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    try { data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body); }
    catch (_) { throw ApiException('Réponse serveur invalide.', statusCode: response.statusCode); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? (data['message'] ?? data['error'] ?? 'Une erreur est survenue.') : 'Une erreur est survenue.';
      throw ApiException(message.toString(), statusCode: response.statusCode);
    }
    return data;
  }

  Map<String, dynamic> _asMap(dynamic data) => data is Map
      ? Map<String, dynamic>.from(data)
      : throw const ApiException('Réponse serveur inattendue.');

  void _captureToken(Map<String, dynamic> data) {
    final value = data['token'] ?? data['accessToken'] ?? (data['data'] is Map ? data['data']['token'] : null);
    if (value != null && value.toString().isNotEmpty) token = value.toString();
  }

  void dispose() {
    disconnectSocket();
    _client.close();
  }
}
