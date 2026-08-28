import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/network/api_client.dart';
import '../../core/socket/socket_service.dart';
import '../../features/drivers/data/drivers_repository.dart';
import '../../features/rides/data/rides_repository.dart';
import '../../features/wallet/data/wallet_repository.dart';

class DriverDashboardV2 extends StatefulWidget {
  const DriverDashboardV2({super.key, required this.api, required this.user});

  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<DriverDashboardV2> createState() => _DriverDashboardV2State();
}

class _DriverDashboardV2State extends State<DriverDashboardV2> {
  late final DriversRepository _drivers;
  late final RidesRepository _rides;
  late final WalletRepository _wallet;
  late final SocketService _socket;

  Timer? _locationTimer;
  Map<String, dynamic>? _offer;
  bool _online = false;
  bool _busy = false;
  String _earnings = '--';
  String? _activeRideId;

  @override
  void initState() {
    super.initState();
    _drivers = DriversRepository(widget.api);
    _rides = RidesRepository(widget.api);
    _wallet = WalletRepository(widget.api);
    _socket = SocketService();
    _connectSocket();
    _loadWallet();
  }

  void _connectSocket() {
    final userId = widget.user['id']?.toString();
    final token = widget.api.token;
    if (userId == null || token == null || token.isEmpty) return;

    _socket.connect(token: token, userId: userId, role: 'DRIVER');
    _socket.on('ride:offer', _onOffer);
    _socket.on('ride:new', _onOffer);
  }

  void _onOffer(dynamic payload) {
    if (payload is! Map || !_online || !mounted) return;
    setState(() => _offer = Map<String, dynamic>.from(payload));
  }

  Future<void> _loadWallet() async {
    try {
      final data = await _wallet.driverWallet();
      if (!mounted) return;
      final value = data['balance'] ?? data['availableBalance'] ?? data['earnings'];
      setState(() => _earnings = value?.toString() ?? data.toString());
    } catch (_) {
      // Wallet indisponible: l'écran reste fonctionnel.
    }
  }

  Future<void> _toggleOnline(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _drivers.setStatus(value ? 'ONLINE' : 'OFFLINE');
      if (value) {
        await _updateLocation();
        _locationTimer?.cancel();
        _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) => _updateLocation());
      } else {
        _locationTimer?.cancel();
        _locationTimer = null;
        _offer = null;
      }
      if (mounted) setState(() => _online = value);
    } catch (error) {
      _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      await _drivers.updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // L'envoi GPS échoue silencieusement pour ne pas faire tomber la disponibilité.
    }
  }

  Future<void> _acceptOffer() async {
    final rawId = _offer?['rideId'] ?? _offer?['id'];
    final rideId = rawId?.toString();
    if (rideId == null || rideId.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      await _rides.accept(rideId);
      _activeRideId = rideId;
      _socket.joinRide(rideId);
      if (mounted) setState(() => _offer = null);
    } catch (error) {
      _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yobalema Driver')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              value: _online,
              onChanged: _busy ? null : _toggleOnline,
              title: Text(_online ? 'Vous êtes en ligne' : 'Vous êtes hors ligne'),
              subtitle: const Text('Recevez uniquement des demandes de courses moto.'),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Mes gains'),
                subtitle: Text(_earnings),
              ),
            ),
            const SizedBox(height: 16),
            if (_offer != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nouvelle course', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('${_offer!['from'] ?? ''} → ${_offer!['to'] ?? ''}'),
                      Text('Prix : ${_offer!['priceFcfa'] ?? 0} FCFA'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _acceptOffer,
                          child: const Text('Accepter la course'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(child: Text('En attente de demandes de courses')),
              ),
            if (_activeRideId != null)
              Text('Course active : $_activeRideId', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('90 % chauffeur • 10 % plateforme', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
