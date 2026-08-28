import '../../../core/network/api_client.dart';

class NotificationsRepository {
  NotificationsRepository(this._client);

  final ApiClient _client;

  Future<List<dynamic>> list() => _client.getList('/api/notifications');

  Future<void> markRead(String notificationId) async {
    await _client.patchMap('/api/notifications/$notificationId/read');
  }
}
