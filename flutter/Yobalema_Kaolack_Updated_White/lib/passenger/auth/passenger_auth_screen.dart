import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../booking/passenger_booking_screen.dart';

class PassengerAuthScreen extends StatefulWidget {
  const PassengerAuthScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<PassengerAuthScreen> createState() => _PassengerAuthScreenState();
}

class _PassengerAuthScreenState extends State<PassengerAuthScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  late final AuthRepository authRepository;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    authRepository = AuthRepository(widget.api);
  }

  Future<void> _submit() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text;
    final name = nameController.text.trim();

    if (phone.length < 8 || password.length < 4) {
      _showMessage('Entre un numéro valide et un mot de passe de 4 caractères minimum.');
      return;
    }

    setState(() => isLoading = true);

    try {
      Map<String, dynamic> data;
      try {
        data = await authRepository.login(phone, password);
      } catch (_) {
        data = await authRepository.register(
          phone: phone,
          password: password,
          name: name.isEmpty ? 'Passager Yobalema' : name,
          role: 'PASSENGER',
        );
      }

      final user = Map<String, dynamic>.from(data['user'] is Map ? data['user'] : const {});
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PassengerBookingScreen(
            api: widget.api,
            user: user,
          ),
        ),
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const Icon(Icons.person_pin_circle, size: 72),
                  const SizedBox(height: 12),
                  const Text(
                    'Yobalema Passenger',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Commander une moto dans la région de Kaolack.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    onSubmitted: (_) => isLoading ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: Text(isLoading ? 'Connexion...' : 'Continuer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
