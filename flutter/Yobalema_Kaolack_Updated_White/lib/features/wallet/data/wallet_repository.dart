import '../../../core/network/api_client.dart';

class WalletRepository {
  WalletRepository(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> driverWallet() =>
      _client.getMap('/api/drivers/me/wallet');
}
