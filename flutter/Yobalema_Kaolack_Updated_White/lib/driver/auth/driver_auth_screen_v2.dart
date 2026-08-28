import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../dashboard/driver_dashboard_v2.dart';

class DriverAuthScreenV2 extends StatefulWidget {
  const DriverAuthScreenV2({super.key, required this.api});

  final ApiClient api;

  @override
  State<DriverAuthScreenV2> createState() => _DriverAuthScreenV2State();
}

class _DriverAuthScreenV2State extends State<DriverAuthScreenV2> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late final AuthRepository _auth;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _auth = AuthRepository(widget.api);
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final password = _password.text;
    if (phone.length < 8 || password.length < 4) {
      _show('Numéro ou mot de passe invalide.');
      return;
    }

    setState(() => _busy = true);
    try {
      Map<String, dynamic> response;
      try {
        response = await _auth.login(phone, password);
      } catch (_) {
        response = await _auth.register(
          phone: phone,
          password: password,
          name: _name.text.trim().isEmpty ? 'Chauffeur Yobalema' : _name.text.trim(),
          role: 'DRIVER',
        );
      }

      final user = response['user'] is Map
          ? Map<String, dynamic>.from(response['user'])
          : <String, dynamic>{};
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverDashboardV2(api: widget.api, user: user),
        ),
      );
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
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const Icon(Icons.two_wheeler, size: 72),
                    const SizedBox(height: 12),
                    const Text('Yobalema Driver', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Espace professionnel réservé aux chauffeurs moto.', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    TextField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nom')),
                    const SizedBox(height: 10),
                    TextField(controller: _phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Téléphone')),
                    const SizedBox(height: 10),
                    TextField(controller: _password, obscureText: true, onSubmitted: (_) => _busy ? null : _submit(), decoration: const InputDecoration(labelText: 'Mot de passe')),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Connexion...' : 'Continuer'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
