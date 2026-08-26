import 'package:flutter/material.dart';
import '../../api.dart';
import 'auth_home.dart';

class LoginScreen extends StatefulWidget {
  final YobalemaApi api;
  final AuthCallback onAuthenticated;

  const LoginScreen({super.key, required this.api, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController(text: '+221');
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final cleanPhone = phone.text.trim();
    final cleanPass = password.text;

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
      final data = await widget.api.login(cleanPhone, cleanPass);
      if (!mounted) return;
      final user = Map<String, dynamic>.from(data['user'] ?? {});
      final role = user['role']?.toString() ?? 'PASSENGER';
      widget.onAuthenticated(context, user, role, widget.api);
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
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Bon retour parmi nous !',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connectez-vous pour commander ou accepter des courses.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),

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
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: 24),

              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Comptes de test rapides :',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        phone.text = '+221770000002';
                        password.text = 'Yobalema123!';
                      });
                    },
                    child: const Text('Remplir Passager'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        phone.text = '+221770000001';
                        password.text = 'Yobalema123!';
                      });
                    },
                    child: const Text('Remplir Chauffeur'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
