import 'package:flutter/material.dart';
import '../../api.dart';
import 'auth_home.dart';
import 'verify_otp_screen.dart';

class RegisterPassengerScreen extends StatefulWidget {
  final YobalemaApi api;
  final AuthCallback onAuthenticated;

  const RegisterPassengerScreen({super.key, required this.api, required this.onAuthenticated});

  @override
  State<RegisterPassengerScreen> createState() => _RegisterPassengerScreenState();
}

class _RegisterPassengerScreenState extends State<RegisterPassengerScreen> {
  final name = TextEditingController();
  final phone = TextEditingController(text: '+221');
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final cleanPhone = phone.text.trim();
    final cleanPass = password.text;
    final cleanName = name.text.trim().isEmpty ? 'Passager Yobalema' : name.text.trim();

    if (cleanPhone.length < 8 || cleanPass.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer un numero valide et un mot de passe (min 4 caracteres).')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => loading = true);
    try {
      final data = await widget.api.register(
        phone: cleanPhone,
        password: cleanPass,
        name: cleanName,
        role: 'PASSENGER',
      );
      if (!mounted) return;
      final user = Map<String, dynamic>.from(data['user'] ?? {});
      final devOtp = data['devOtp']?.toString();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            api: widget.api,
            user: user,
            role: 'PASSENGER',
            devOtp: devOtp,
            onAuthenticated: widget.onAuthenticated,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Inscription Passager")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Creer votre compte passager',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Commandez vos trajets en toute simplicite dans la region de Kaolack.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numero de telephone',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: password,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("S'inscrire"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
