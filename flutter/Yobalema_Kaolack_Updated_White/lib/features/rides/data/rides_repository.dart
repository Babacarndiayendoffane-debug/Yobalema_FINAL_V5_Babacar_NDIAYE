import '../../../core/network/api_client.dart';

class RidesRepository {
  RidesRepository(this._client);

  final ApiClient _client;

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
  }) => _client.postMap('/api/rides/quote', {
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
      });

  Future<Map<String, dynamic>> create({
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
  }) => _client.postMap('/api/rides', {
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
      });

  Future<Map<String, dynamic>> accept(String rideId) =>
      _client.postMap('/api/rides/$rideId/accept');

  Future<Map<String, dynamic>> updateStatus(String rideId, String status) =>
      _client.patchMap('/api/rides/$rideId/status', {'status': status});

  Future<Map<String, dynamic>> requestPickupOtp(String rideId) =>
      _client.postMap('/api/rides/$rideId/pickup-otp');

  Future<Map<String, dynamic>> verifyPickup(String rideId, String code) =>
      _client.postMap('/api/rides/$rideId/verify-pickup', {'code': code});

  Future<Map<String, dynamic>> rate(
    String rideId,
    int score, {
    String? comment,
  }) => _client.postMap('/api/rides/$rideId/rating', {
        'score': score,
        if (comment != null) 'comment': comment,
      });
}
