import 'package:flutter/material.dart';
import '../../api.dart';

class PassengerBookingScreen extends StatefulWidget {
  final YobalemaApi api; final Map<String, dynamic> user;
  const PassengerBookingScreen({super.key, required this.api, required this.user});
  @override State<PassengerBookingScreen> createState() => _PassengerBookingScreenState();
}
class _PassengerBookingScreenState extends State<PassengerBookingScreen> {
  final from = TextEditingController(); final to = TextEditingController();
  String payment = 'CASH'; String status = 'Prêt'; String? activeRideId; bool loading = false;
  @override void initState() { super.initState(); widget.api.connectSocket(userId: widget.user['id']?.toString(), role: 'PASSENGER', onRideAccepted: (d) { if (mounted) setState(() => status = 'Chauffeur trouvé'); }, onRideStatus: (d) { if (mounted) setState(() => status = d['status']?.toString() ?? status); }, onRideLocation: (_) { if (mounted) setState(() => status = 'Chauffeur en approche'); }); }
  Future<void> requestRide() async {
    setState(() => loading = true);
    try {
      final data = await widget.api.createRide(fromName: from.text.trim().isEmpty ? 'Ndoffane' : from.text.trim(), toName: to.text.trim().isEmpty ? 'Kaolack' : to.text.trim(), fromLat: 13.8447, fromLng: -15.9382, toLat: 14.1510, toLng: -16.0726, fromZone: 'CITY', toZone: 'CITY', trafficLevel: 0, night: false, shareTrip: false, paymentMethod: payment);
      final ride = data['ride'] is Map ? Map<String, dynamic>.from(data['ride']) : data;
      activeRideId = ride['id']?.toString();
      if (activeRideId != null) widget.api.joinRide(activeRideId!);
      if (payment != 'CASH' && activeRideId != null) await widget.api.startPayment(activeRideId!);
      if (mounted) setState(() => status = 'Course demandée');
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override void dispose() { from.dispose(); to.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Yobalema Passenger')), body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Statut : $status'), const SizedBox(height: 16),
    TextField(controller: from, decoration: const InputDecoration(labelText: 'Départ', border: OutlineInputBorder())), const SizedBox(height: 12),
    TextField(controller: to, decoration: const InputDecoration(labelText: 'Destination', border: OutlineInputBorder())), const SizedBox(height: 12),
    DropdownButtonFormField<String>(value: payment, decoration: const InputDecoration(labelText: 'Paiement', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'CASH', child: Text('Espèces')), DropdownMenuItem(value: 'WAVE', child: Text('Wave')), DropdownMenuItem(value: 'ORANGE_MONEY', child: Text('Orange Money'))], onChanged: (v) => setState(() => payment = v!)),
    const Spacer(), FilledButton.icon(onPressed: loading ? null : requestRide, icon: const Icon(Icons.two_wheeler), label: Text(loading ? 'Recherche...' : 'Commander une moto')),
  ])));
}
