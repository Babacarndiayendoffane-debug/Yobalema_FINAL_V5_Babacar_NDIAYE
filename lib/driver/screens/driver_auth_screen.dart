import 'package:flutter/material.dart';
import '../../core/api/yobalema_api.dart';
import '../../core/constants/yobalema_theme.dart';
import '../../core/utils/error_helper.dart';

class DriverAuthScreen extends StatefulWidget {
  final YobalemaApi api;
  final void Function(Map<String, dynamic> user, String token) onAuthenticated;

  const DriverAuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  @override
  State<DriverAuthScreen> createState() => _DriverAuthScreenState();
}

class _DriverAuthScreenState extends State<DriverAuthScreen> {
  bool isRegister = false;
  final phoneCtrl = TextEditingController(text: '+221770000001');
  final passCtrl = TextEditingController(text: 'Yobalema123!');
  final nameCtrl = TextEditingController(text: 'Ibrahima Ndiaye');
  final plateCtrl = TextEditingController(text: 'KL-4829-B');
  final String vehicleType = 'MOTO'; // Yobalema = 100% Moto
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    phoneCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text;
    final name = nameCtrl.text.trim();
    final plate = plateCtrl.text.trim();

    if (phone.length < 8 || pass.length < 4) {
      _toast('Veuillez entrer un numéro valide et un mot de passe (min 4 caractères).');
      return;
    }

    setState(() => loading = true);
    try {
      Map<String, dynamic> res;
      if (isRegister) {
        res = await widget.api.register(
          phone: phone,
          password: pass,
          name: name.isEmpty ? 'Chauffeur Yobalema' : name,
          role: 'DRIVER',
        );
        if (plate.isNotEmpty) {
          try {
            await widget.api.setVehicle(vehicleType, plate);
          } catch (_) {}
        }
      } else {
        res = await widget.api.login(phone, pass);
      }

      final user = Map<String, dynamic>.from(res['user'] ?? {});
      final token = res['token']?.toString() ?? widget.api.token ?? '';
      widget.onAuthenticated(user, token);
    } catch (e) {
      _toast(cleanErrorMessage(e), bg: YobalemaTheme.red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String s, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), backgroundColor: bg ?? YobalemaTheme.ink),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              // App Logo & Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: YobalemaTheme.ink,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.two_wheeler, color: YobalemaTheme.primary, size: 32),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOBALEMA MOTO',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: YobalemaTheme.ink),
                      ),
                      Text(
                        'Cockpit Chauffeur Moto • Région de Kaolack',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: YobalemaTheme.green),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 36),
              Text(
                isRegister ? 'Devenir Chauffeur Partenaire' : 'Espace Chauffeur',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: YobalemaTheme.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Recevez des courses en continu avec seulement 10% de commission.',
                style: TextStyle(color: YobalemaTheme.textMuted, fontSize: 13),
              ),

              const SizedBox(height: 28),

              if (isRegister) ...[
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom et Prénom',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.two_wheeler, color: YobalemaTheme.ink),
                      SizedBox(width: 12),
                      Text('Moto Jakarta / Tiak-Tiak', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Immatriculation (ex: KL-1234-A / DK-...)',
                    prefixIcon: Icon(Icons.pin),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone (+221...)',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: passCtrl,
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
                onPressed: loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: YobalemaTheme.ink,
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isRegister ? 'Créer mon compte Chauffeur' : 'Accéder au Cockpit'),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () => setState(() => isRegister = !isRegister),
                child: Text(
                  isRegister ? 'Déjà inscrit ? Se connecter' : 'Nouveau chauffeur ? S\'inscrire',
                  style: const TextStyle(color: YobalemaTheme.ink, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
