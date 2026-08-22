import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'YobalemaApiUrl',
    defaultValue: 'http://10.0.2.2:4000',
  );
}

class YobalemaApi {
  String? token;
  io.Socket? socket;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    return _decode(r);
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String name,
    required String role,
  }) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'name': name,
        'role': role,
      }),
    );
    return _decode(r);
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
  }) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/rides/quote'),
      headers: _headers,
      body: jsonEncode({
        'fromName': fromName,
        'toName': toName,
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
        'fromZone': fromZone,
        'toZone': toZone,
        'trafficLevel': trafficLevel,
        'night': night,
      }),
    );
    return _decode(r);
  }

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
  }) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/rides'),
      headers: _headers,
      body: jsonEncode({
        'fromName': fromName,
        'toName': toName,
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
        'fromZone': fromZone,
        'toZone': toZone,
        'trafficLevel': trafficLevel,
        'night': night,
        'shareTrip': shareTrip,
        'paymentMethod': paymentMethod,
      }),
    );
    return _decode(r);
  }

  Future<Map<String, dynamic>> setDriverStatus(String status) async {
    final r = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return _decode(r);
  }

  Future<Map<String, dynamic>> updateDriverLocation(double lat, double lng) async {
    final r = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/location'),
      headers: _headers,
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    return _decode(r);
  }

  Future<List<dynamic>> nearbyDrivers(double lat, double lng) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/drivers/nearby?lat=$lat&lng=$lng&radiusKm=10');
    final r = await http.get(uri, headers: _headers);
    final data = _decode(r);
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> acceptRide(String id) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/rides/$id/accept'),
      headers: _headers,
    );
    return _decode(r);
  }

  Future<Map<String, dynamic>> rideStatus(String id, String status) async {
    final r = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/rides/$id/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return _decode(r);
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
    socket?.dispose();
    socket = io.io(ApiConfig.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });
    if (userId != null && role == 'DRIVER') socket!.emit('driver:join', userId);
    if (userId != null && role == 'PASSENGER') socket!.emit('passenger:join', userId);
    socket!.on('ride:offer', (data) {
      if (data is Map) onRideOffer?.call(Map<String, dynamic>.from(data));
    });
    socket!.on('ride:new', (data) {
      if (data is Map) onRideNew?.call(Map<String, dynamic>.from(data));
    });
    socket!.on('ride:accepted', (data) {
      if (data is Map) onRideAccepted?.call(Map<String, dynamic>.from(data));
    });
    socket!.on('ride:status', (data) {
      if (data is Map) onRideStatus?.call(Map<String, dynamic>.from(data));
    });
    socket!.on('ride:location', (data) {
      if (data is Map) onRideLocation?.call(Map<String, dynamic>.from(data));
    });
  }

  void joinRide(String rideId) => socket?.emit('ride:join', rideId);
  void dispose() => socket?.dispose();


  Future<Map<String, dynamic>> requestOtp() async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/auth/request-otp'), headers: _headers);
    return _decode(r);
  }

  Future<Map<String, dynamic>> verifyOtp(String code) async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/auth/verify-otp'), headers: _headers, body: jsonEncode({'code': code}));
    return _decode(r);
  }

  Future<Map<String, dynamic>> setVehicle(String vehicleType, String vehiclePlate) async {
    final r = await http.patch(Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/vehicle'), headers: _headers, body: jsonEncode({'vehicleType': vehicleType, 'vehiclePlate': vehiclePlate}));
    return _decode(r);
  }

  Future<Map<String, dynamic>> requestPickupOtp(String rideId) async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/pickup-otp'), headers: _headers);
    return _decode(r);
  }

  Future<Map<String, dynamic>> verifyPickup(String rideId, String code) async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/verify-pickup'), headers: _headers, body: jsonEncode({'code': code}));
    return _decode(r);
  }

  Future<Map<String, dynamic>> confirmPayment(String rideId, String providerRef) async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/payment/confirm'), headers: _headers, body: jsonEncode({'providerRef': providerRef}));
    return _decode(r);
  }

  Future<Map<String, dynamic>> rateRide(String rideId, int score, {String? comment}) async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/rating'), headers: _headers, body: jsonEncode({'score': score, if (comment != null) 'comment': comment}));
    return _decode(r);
  }


  Future<List<dynamic>> notifications() async {
    final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/notifications'), headers: _headers);
    return _decode(r) as List<dynamic>;
  }

  Future<void> markNotificationRead(String id) async {
    final r = await http.patch(Uri.parse('${ApiConfig.baseUrl}/api/notifications/$id/read'), headers: _headers);
    _decode(r);
  }

  Future<Map<String, dynamic>> createSupportTicket(String subject, String message) async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/support/tickets'), headers: _headers, body: jsonEncode({'subject': subject, 'message': message}));
    return _decode(r);
  }

  Future<List<dynamic>> supportTickets() async {
    final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/support/tickets'), headers: _headers);
    return _decode(r) as List<dynamic>;
  }

  Future<Map<String, dynamic>> driverWallet() async {
    final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/wallet'), headers: _headers);
    return _decode(r);
  }

  Future<Map<String, dynamic>> startPayment(String rideId) async {
    final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/payment/start'), headers: _headers);
    return _decode(r);
  }

  dynamic _decode(http.Response r) {
    dynamic data;
    try {
      data = jsonDecode(r.body);
    } catch (_) {
      data = {'error': r.body};
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = data is Map && data['error'] != null ? data['error'].toString() : 'Erreur réseau';
      throw Exception(msg);
    }
    if (data is Map && data['token'] != null) token = data['token'].toString();
    return data;
  }
}
