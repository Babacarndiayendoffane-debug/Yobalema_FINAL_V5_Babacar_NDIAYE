import '../../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final data = await _client.postMap('/api/auth/login', {
      'phone': phone,
      'password': password,
    });
    _captureToken(data);
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String name,
    required String role,
  }) async {
    final data = await _client.postMap('/api/auth/register', {
      'phone': phone,
      'password': password,
      'name': name,
      'role': role,
    });
    _captureToken(data);
    return data;
  }

  Future<Map<String, dynamic>> requestOtp() =>
      _client.postMap('/api/auth/request-otp');

  Future<Map<String, dynamic>> verifyOtp(String code) =>
      _client.postMap('/api/auth/verify-otp', {'code': code});

  void logout() => _client.token = null;

  void _captureToken(Map<String, dynamic> data) {
    final nested = data['data'];
    final value = data['token'] ??
        data['accessToken'] ??
        (nested is Map ? nested['token'] : null);
    if (value != null && value.toString().isNotEmpty) {
      _client.token = value.toString();
    }
  }
}
