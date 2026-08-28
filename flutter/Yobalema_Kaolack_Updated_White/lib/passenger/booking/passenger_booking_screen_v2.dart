import 'package:flutter/material.dart';

import '../../core/models/ride.dart';
import '../../core/network/api_client.dart';
import '../../core/socket/socket_service.dart';
import '../../features/payments/data/payments_repository.dart';
import '../../features/rides/data/rides_repository.dart';

class PassengerBookingScreenV2 extends StatefulWidget {
  const PassengerBookingScreenV2({super.key, required this.api, required this.user});

  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<PassengerBookingScreenV2> createState() => _PassengerBookingScreenV2State();
}

class _PassengerBookingScreenV2State extends State<PassengerBookingScreenV2> {
  late final RidesRepository _rides;
  late final PaymentsRepository _payments;
  late final SocketService _socket;

  final _from = TextEditingController();
  final _to = TextEditingController();

  RideStatus _status = RideStatus.requested;
  PaymentMethod _payment = PaymentMethod.cash;
  String? _rideId;
  String _message = 'Prêt à partir';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rides = RidesRepository(widget.api);
    _payments = PaymentsRepository(widget.api);
    _socket = SocketService();

    final userId = widget.user['id']?.toString();
    final token = widget.api.token;
    if (userId == null || token == null || token.isEmpty) return;

    _socket.connect(token: token, userId: userId, role: 'PASSENGER');
    _socket.on('ride:accepted', _onRideUpdate);
    _socket.on('ride:status', _onRideUpdate);
    _socket.on('ride:location', _onRideLocation);
  }

  void _onRideUpdate(dynamic payload) {
    if (payload is! Map || _rideId == null) return;
    final data = Map<String, dynamic>.from(payload);
    if (data['rideId']?.toString() != _rideId) return;

    final next = RideStatusX.fromApi(data['status']?.toString());
    if (next == _status || !RideStateMachine.canTransition(_status, next)) return;

    if (!mounted) return;
    setState(() {
      _status = next;
      _message = _label(next);
    });
  }

  void _onRideLocation(dynamic payload) {
    if (payload is! Map || _rideId == null) return;
    final data = Map<String, dynamic>.from(payload);
    if (data['rideId']?.toString() != _rideId) return;
    if (mounted) setState(() => _message = 'Chauffeur en approche');
  }

  Future<void> _requestRide() async {
    final from = _from.text.trim();
    final to = _to.text.trim();
    if (from.isEmpty || to.isEmpty) {
      _show('Le départ et la destination sont obligatoires.');
      return;
    }

    setState(() => _busy = true);
    try {
      final response = await _rides.create(
        fromName: from,
        toName: to,
        fromLat: 14.1510,
        fromLng: -16.0726,
        toLat: 14.1560,
        toLng: -16.0400,
        fromZone: 'CITY',
        toZone: 'CITY',
        trafficLevel: 0,
        night: false,
        shareTrip: false,
        paymentMethod: _payment.apiValue,
      );

      final raw = response['ride'] is Map ? response['ride'] : response;
      if (raw is! Map) throw const FormatException('Réponse de course invalide.');

      final ride = Ride.fromJson(Map<String, dynamic>.from(raw));
      if (ride.id.isEmpty) throw const FormatException('Identifiant de course manquant.');

      _rideId = ride.id;
      _status = ride.status;
      _message = _label(ride.status);
      _socket.joinRide(ride.id);

      if (_payment != PaymentMethod.cash) {
        await _payments.start(ride.id);
      }
    } catch (error) {
      _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(RideStatus status) => switch (status) {
        RideStatus.requested => 'Recherche d’un chauffeur...',
        RideStatus.driverAssigned => 'Chauffeur trouvé',
        RideStatus.driverArriving => 'Chauffeur en approche',
        RideStatus.inProgress => 'Course en cours',
        RideStatus.paymentPending => 'Paiement en attente',
        RideStatus.completed => 'Course terminée',
        RideStatus.cancelled => 'Course annulée',
      };

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _socket.disconnect();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yobalema Passenger')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _from,
              decoration: const InputDecoration(labelText: 'Départ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _to,
              decoration: const InputDecoration(labelText: 'Destination'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              value: _payment,
              items: const [
                DropdownMenuItem(value: PaymentMethod.cash, child: Text('Espèces')),
                DropdownMenuItem(value: PaymentMethod.wave, child: Text('Wave')),
                DropdownMenuItem(
                  value: PaymentMethod.orangeMoney,
                  child: Text('Orange Money'),
                ),
              ],
              onChanged: _busy ? null : (value) {
                if (value != null) setState(() => _payment = value);
              },
              decoration: const InputDecoration(labelText: 'Paiement'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _busy ? null : _requestRide,
              icon: const Icon(Icons.two_wheeler),
              label: Text(_busy ? 'Envoi...' : 'Commander une moto'),
            ),
          ],
        ),
      ),
    );
  }
}
