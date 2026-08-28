import '../network/api_client.dart';
import '../socket/socket_service.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/drivers/data/drivers_repository.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/payments/data/payments_repository.dart';
import '../../features/rides/data/rides_repository.dart';
import '../../features/support/data/support_repository.dart';
import '../../features/wallet/data/wallet_repository.dart';

class AppServices {
  AppServices({ApiClient? apiClient}) : apiClient = apiClient ?? ApiClient() {
    auth = AuthRepository(this.apiClient);
    rides = RidesRepository(this.apiClient);
    drivers = DriversRepository(this.apiClient);
    payments = PaymentsRepository(this.apiClient);
    wallet = WalletRepository(this.apiClient);
    notifications = NotificationsRepository(this.apiClient);
    support = SupportRepository(this.apiClient);
  }

  final ApiClient apiClient;
  late final AuthRepository auth;
  late final RidesRepository rides;
  late final DriversRepository drivers;
  late final PaymentsRepository payments;
  late final WalletRepository wallet;
  late final NotificationsRepository notifications;
  late final SupportRepository support;
  final SocketService socket = SocketService();

  void dispose() {
    socket.disconnect();
    apiClient.dispose();
  }
}
