import '../../../core/network/api_client.dart';

class DriversRepository {
  DriversRepository(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> setStatus(String status) =>
      _client.patchMap('/api/drivers/me/status', {'status': status});

  Future<Map<String, dynamic>> updateLocation(double lat, double lng) =>
      _client.patchMap('/api/drivers/me/location', {'lat': lat, 'lng': lng});

  Future<List<dynamic>> nearby(double lat, double lng) =>
      _client.getList('/api/drivers/nearby', query: {
        'lat': '$lat',
        'lng': '$lng',
        'radiusKm': '10',
      });

  Future<Map<String, dynamic>> setVehicle({
    required String vehicleType,
    required String vehiclePlate,
  }) => _client.patchMap('/api/drivers/me/vehicle', {
        'vehicleType': vehicleType,
        'vehiclePlate': vehiclePlate,
      });

  Future<Map<String, dynamic>> wallet() =>
      _client.getMap('/api/drivers/me/wallet');
}
