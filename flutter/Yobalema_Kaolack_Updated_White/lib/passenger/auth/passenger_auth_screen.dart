import 'package:flutter/material.dart';
import '../../api.dart';
import '../booking/passenger_booking_screen.dart';

class PassengerAuthScreen extends StatefulWidget {
  final YobalemaApi api;
  const PassengerAuthScreen({super.key, required this.api});
  @override State<PassengerAuthScreen> createState() => _PassengerAuthScreenState();
}

class _PassengerAuthScreenState extends State<PassengerAuthScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool loading = false;

  Future<void> submit() async {
    setState(() => loading = true);
    try {
      Map<String, dynamic> data;
      try { data = await widget.api.login(phone.text.trim(), password.text); }
      catch (_) { data = await widget.api.register(phone: phone.text.trim(), password: password.text, name: name.text.trim().isEmpty ? 'Passager Yobalema' : name.text.trim(), role: 'PASSENGER'); }
      final user = Map<String, dynamic>.from(data['user'] ?? {});
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PassengerBookingScreen(api: widget.api, user: user)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override void dispose() { phone.dispose(); password.dispose(); name.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(children: [
    const Icon(Icons.person_pin_circle, size: 72), const SizedBox(height: 12),
    const Text('Yobalema Passenger', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    const Text('Commander une moto dans la région de Kaolack.'), const SizedBox(height: 20),
    TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())), const SizedBox(height: 10),
    TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())), const SizedBox(height: 10),
    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder())), const SizedBox(height: 16),
    FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Connexion...' : 'Continuer')),
  ])))));
}
