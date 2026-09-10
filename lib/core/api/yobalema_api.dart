import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../services/pricing_engine.dart';
import '../models/commune.dart';

class YobalemaApi {
  final http.Client _client;
  String? token;
  io.Socket? socket;
  String? _joinedRideId;

  YobalemaApi({http.Client? client}) : _client = client ?? http.Client();

  bool get isSocketConnected => socket?.connected ?? false;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  bool _isNetworkError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('failed to fetch') ||
        str.contains('clientexception') ||
        str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('connection reset') ||
        str.contains('xmlhttprequest') ||
        str.contains('handshakeexception') ||
        str.contains('timeoutexception') ||
        str.contains('failed host lookup') ||
        str.contains('network is unreachable') ||
        str.contains('serveur injoignable') ||
        str.contains('localhost:4000') ||
        str.contains('10.0.2.2:4000');
  }

  Future<http.Response> _sendRequest(Future<http.Response> Function() request) async {
    try {
      return await request();
    } catch (e) {
      if (_isNetworkError(e)) {
        throw Exception('Serveur injoignable. Vérifiez votre connexion ou que le backend est démarré.');
      }
      rethrow;
    }
  }

  Future<http.Response> _safeGet(Uri uri, {Map<String, String>? headers, Duration timeout = const Duration(seconds: 5)}) =>
      _sendRequest(() => _client.get(uri, headers: headers ?? _headers).timeout(timeout));

  Future<http.Response> _safePost(Uri uri, {Map<String, String>? headers, Object? body, Duration timeout = const Duration(seconds: 5)}) =>
      _sendRequest(() => _client.post(uri, headers: headers ?? _headers, body: body).timeout(timeout));

  Future<http.Response> _safePatch(Uri uri, {Map<String, String>? headers, Object? body, Duration timeout = const Duration(seconds: 5)}) =>
      _sendRequest(() => _client.patch(uri, headers: headers ?? _headers, body: body).timeout(timeout));

  // Session Management
  Future<void> saveSession(String newToken, Map<String, dynamic> user, String role) async {
    token = newToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('yobalema_token', newToken);
      await prefs.setString('yobalema_user', jsonEncode(user));
      await prefs.setString('yobalema_role', role);
    } catch (_) {}
  }

  /// Restores the cached session and optionally validates it with the backend.
  ///
  /// Validation is required at application startup. A cached token is only
  /// retained without validation when the backend is genuinely unreachable.
  Future<Map<String, dynamic>?> restoreSession({bool validate = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('yobalema_token');
      final savedUser = prefs.getString('yobalema_user');
      final savedRole = prefs.getString('yobalema_role');
      if (savedToken == null || savedUser == null || savedRole == null) return null;

      token = savedToken;
      final decoded = jsonDecode(savedUser);
      final userMap = decoded is Map<String, dynamic>
          ? decoded
          : (decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{});
      final cachedSession = {
        'token': savedToken,
        'user': userMap,
        'role': savedRole,
      };

      if (!validate) return cachedSession;

      try {
        final response = await _safeGet(
          Uri.parse('${ApiConfig.baseUrl}/api/me'),
          headers: _headers,
        );
        final remoteUser = _decode(response);
        final normalizedUser = remoteUser is Map<String, dynamic>
            ? remoteUser
            : Map<String, dynamic>.from(remoteUser as Map);
        final remoteRole = normalizedUser['role']?.toString() ?? savedRole;
        await saveSession(savedToken, normalizedUser, remoteRole);
        return {'token': savedToken, 'user': normalizedUser, 'role': remoteRole};
      } on _UnauthorizedException {
        await clearSession();
        return null;
      } catch (error) {
        // A valid cached session remains usable only when the backend is unreachable.
        if (_isNetworkError(error)) return cachedSession;
        rethrow;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    token = null;
    leaveRide();
    socket?.dispose();
    socket = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('yobalema_token');
      await prefs.remove('yobalema_user');
      await prefs.remove('yobalema_role');
    } catch (_) {}
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final r = await _client.get(Uri.parse('${ApiConfig.baseUrl}/health')).timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Auth endpoints
  Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: _headers,
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      final data = _decode(r);
      if (data['token'] != null) {
        token = data['token'].toString();
        final user = Map<String, dynamic>.from(data['user'] ?? {});
        final role = user['role']?.toString() ?? 'PASSENGER';
        await saveSession(token!, user, role);
      }
      return data;
      } catch (e) {
        rethrow;
      }
    }

    Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'phone': phone,
          'password': password,
          'name': name,
          'role': role,
        }),
      );
      final data = _decode(r);
      if (data['token'] != null) {
        token = data['token'].toString();
        final user = Map<String, dynamic>.from(data['user'] ?? {});
        await saveSession(token!, user, role);
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestOtp() async {
    try {
      final r = await _safePost(Uri.parse('${ApiConfig.baseUrl}/api/auth/request-otp'), headers: _headers);
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String code) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/verify-otp'),
        headers: _headers,
        body: jsonEncode({'code': code}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final r = await _safeGet(Uri.parse('${ApiConfig.baseUrl}/api/me'), headers: _headers);
      return _decode(r);
    } catch (e) {
      if (_isNetworkError(e)) {
        final session = await restoreSession();
        if (session != null && session['user'] != null) {
          return Map<String, dynamic>.from(session['user'] as Map);
        }
      }
      rethrow;
    }
  }
  // Pricing & Rides
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
    double? distanceKm,
  }) async {
    try {
      final r = await _safePost(
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
          if (distanceKm != null) 'distanceKm': distanceKm,
        }),
      );
      return _decode(r);
    } catch (e) {
      if (_isNetworkError(e)) {
        // Fallback calcul de prix local
        ZoneType parseZone(String z) {
          switch (z.toUpperCase()) {
            case 'CITY':
              return ZoneType.city;
            case 'PERIURBAN':
              return ZoneType.periurban;
            default:
              return ZoneType.village;
          }
        }

        final dist = distanceKm ?? 5.0;
        final localQuote = Pricing.calculate(
          km: dist,
          fromZone: parseZone(fromZone),
          toZone: parseZone(toZone),
          trafficLevel: trafficLevel,
          night: night,
        );

        return {
          'priceFcfa': localQuote.total,
          'distanceKm': dist,
          'breakdown': {
            'baseFare': localQuote.total,
            'trafficFactor': localQuote.trafficFactor,
            'driverGain': localQuote.driver,
            'platformFee': localQuote.platform,
          },
          'explanation': localQuote.explanation,
        };
      }
      rethrow;
    }
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
    double? distanceKm,
  }) async {
    try {
      final r = await _safePost(
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
          if (distanceKm != null) 'distanceKm': distanceKm,
        }),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getAvailableRides() async {
    try {
      final r = await _safeGet(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/pending'),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        return _decode(r) as List<dynamic>;
      }
    } on _UnauthorizedException {
      rethrow;
    } catch (_) {}
    try {
      final r = await _safeGet(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/available'),
        headers: _headers,
      );
      return _decode(r) as List<dynamic>;
    } on _UnauthorizedException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> pendingRides() => getAvailableRides();

  Future<List<dynamic>> ridesHistory() async {
    try {
      final r = await _safeGet(Uri.parse('${ApiConfig.baseUrl}/api/rides'), headers: _headers);
      return _decode(r) as List<dynamic>;
    } on _UnauthorizedException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getRide(String id) async {
    final r = await _safeGet(Uri.parse('${ApiConfig.baseUrl}/api/rides/$id'), headers: _headers);
    return _decode(r);
  }

  Future<Map<String, dynamic>> acceptRide(String id) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/$id/accept'),
        headers: _headers,
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestPickupOtp(String rideId) async {
    try {
      final r = await _safePost(Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/pickup-otp'), headers: _headers);
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPickup(String rideId, String code) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/verify-pickup'),
        headers: _headers,
        body: jsonEncode({'code': code}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> rideStatus(String id, String status) async {
    try {
      final r = await _safePatch(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/$id/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelRide(String id, {String? reason}) async {
    try {
      final r = await _safePatch(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/$id/status'),
        headers: _headers,
        body: jsonEncode({
          'status': 'CANCELLED',
          if (reason != null) 'reason': reason,
        }),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  // Driver actions
  Future<Map<String, dynamic>> setDriverStatus(String status) async {
    try {
      final r = await _safePatch(
        Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateDriverLocation(double lat, double lng, {double accuracy = 0.0, double speed = 0.0, double heading = 0.0}) async {
    try {
      final r = await _safePatch(
        Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/location'),
        headers: _headers,
        body: jsonEncode({'lat': lat, 'lng': lng, 'accuracy': accuracy, 'speed': speed, 'heading': heading}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> setVehicle(String vehicleType, String vehiclePlate) async {
    try {
      final r = await _safePatch(
        Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/vehicle'),
        headers: _headers,
        body: jsonEncode({'vehicleType': vehicleType, 'vehiclePlate': vehiclePlate}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> nearbyDrivers(double lat, double lng) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/drivers/nearby?lat=$lat&lng=$lng&radiusKm=15');
      final r = await _safeGet(uri, headers: _headers);
      return _decode(r) as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> driverWallet() async {
    try {
      final r = await _safeGet(Uri.parse('${ApiConfig.baseUrl}/api/drivers/me/wallet'), headers: _headers);
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  // Payments
  Future<Map<String, dynamic>> startPayment(String rideId) async {
    try {
      final r = await _safePost(Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/payment/start'), headers: _headers);
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> confirmPayment(String rideId, String providerRef) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/payment/confirm'),
        headers: _headers,
        body: jsonEncode({'providerRef': providerRef}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> rateRide(String rideId, int score, {String? comment}) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/rides/$rideId/rating'),
        headers: _headers,
        body: jsonEncode({'score': score, if (comment != null) 'comment': comment}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  // Support & Notifications
  Future<List<dynamic>> notifications() async {
    try {
      final r = await _safeGet(Uri.parse('${ApiConfig.baseUrl}/api/notifications'), headers: _headers);
      final data = _decode(r);
      return data is List<dynamic> ? data : [];
    } on _UnauthorizedException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      final r = await _safePatch(Uri.parse('${ApiConfig.baseUrl}/api/notifications/$id/read'), headers: _headers);
      _decode(r);
    } on _UnauthorizedException {
      rethrow;
    } catch (_) {}
  }

  Future<Map<String, dynamic>> createSupportTicket(String subject, String message) async {
    try {
      final r = await _safePost(
        Uri.parse('${ApiConfig.baseUrl}/api/support/tickets'),
        headers: _headers,
        body: jsonEncode({'subject': subject, 'message': message}),
      );
      return _decode(r);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> supportTickets() async {
    try {
      final r = await _safeGet(Uri.parse('${ApiConfig.baseUrl}/api/support/tickets'), headers: _headers);
      final data = _decode(r);
      return data is List<dynamic> ? data : [];
    } on _UnauthorizedException {
      rethrow;
    } catch (_) {
      return [];
    }
  }

  // Socket.IO
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
    try {
      final connectedSocket = io.io(ApiConfig.baseUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'reconnection': true,
        if (token != null) 'auth': {'token': token},
      });
      socket = connectedSocket;
      connectedSocket.onConnect((_) {
        if (userId != null && role == 'DRIVER') {
          connectedSocket.emit('driver:join', userId);
        }
        if (userId != null && role == 'PASSENGER') {
          connectedSocket.emit('passenger:join', userId);
        }
        final rideId = _joinedRideId;
        if (rideId != null && rideId.isNotEmpty) {
          connectedSocket.emit('ride:join', rideId);
        }
      });
      connectedSocket.onConnectError((error) {
        debugPrint('[SOCKET] Connexion impossible: $error');
      });
      connectedSocket.onError((error) {
        debugPrint('[SOCKET] Erreur: $error');
      });
      connectedSocket.onDisconnect((reason) {
        debugPrint('[SOCKET] Déconnecté: $reason');
      });
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
    } catch (_) {}
  }

  void joinRide(String rideId) {
    final normalizedRideId = rideId.trim();
    if (normalizedRideId.isEmpty) return;
    _joinedRideId = normalizedRideId;
    if (socket?.connected ?? false) {
      socket!.emit('ride:join', normalizedRideId);
    }
  }

  void leaveRide() {
    final rideId = _joinedRideId;
    if (rideId != null && socket?.connected == true) {
      socket!.emit('ride:leave', rideId);
    }
    _joinedRideId = null;
  }

  void emitLocation(String rideId, double lat, double lng, {double accuracy = 0.0, double speed = 0.0, double heading = 0.0}) =>
      socket?.emit('ride:location', {'rideId': rideId, 'lat': lat, 'lng': lng, 'latitude': lat, 'longitude': lng, 'accuracy': accuracy, 'speed': speed, 'heading': heading, 'timestamp': DateTime.now().millisecondsSinceEpoch});

  void dispose() {
    leaveRide();
    socket?.dispose();
    socket = null;
  }

  dynamic _decode(http.Response r) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      try {
        data = jsonDecode(r.body);
      } catch (_) {
        data = {'error': r.body};
      }
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : (data is Map && data['message'] != null
              ? data['message'].toString()
              : 'Erreur réseau (${r.statusCode})');
      if (r.statusCode == 401 || r.statusCode == 403) {
        clearSession();
        throw _UnauthorizedException(msg);
      }
      throw Exception(msg);
    }
    if (data is Map && data['token'] != null) {
      token = data['token'].toString();
    }
    return data;
  }
}

class _UnauthorizedException implements Exception {
  final String message;

  const _UnauthorizedException(this.message);

  @override
  String toString() => message;
}

