import '../../../core/network/api_client.dart';

class PaymentsRepository {
  PaymentsRepository(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> start(String rideId) =>
      _client.postMap('/api/rides/$rideId/payment/start');

  Future<Map<String, dynamic>> confirm(String rideId, String providerRef) =>
      _client.postMap('/api/rides/$rideId/payment/confirm', {
        'providerRef': providerRef,
      });
}
