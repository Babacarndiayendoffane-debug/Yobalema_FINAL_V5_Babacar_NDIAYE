import '../../../core/network/api_client.dart';

class SupportRepository {
  SupportRepository(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> createTicket({
    required String subject,
    required String message,
  }) => _client.postMap('/api/support/tickets', {
        'subject': subject,
        'message': message,
      });

  Future<List<dynamic>> tickets() =>
      _client.getList('/api/support/tickets');
}
