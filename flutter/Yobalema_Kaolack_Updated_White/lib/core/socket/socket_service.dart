import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';

class SocketService {
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect({
    required String token,
    required String userId,
    required String role,
  }) {
    disconnect();
    _socket = io.io(ApiConfig.baseUrl, {
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      switch (role) {
        case 'DRIVER':
          _socket!.emit('driver:join', userId);
        case 'PASSENGER':
          _socket!.emit('passenger:join', userId);
      }
    });

    _socket!.connect();
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) => _socket?.off(event);

  void joinRide(String rideId) => _socket?.emit('ride:join', rideId);

  void emit(String event, [dynamic data]) => _socket?.emit(event, data);

  void disconnect() {
    _socket?.off();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
