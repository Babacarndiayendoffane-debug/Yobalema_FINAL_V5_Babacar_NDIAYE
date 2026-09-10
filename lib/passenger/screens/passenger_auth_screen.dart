import 'package:flutter/material.dart';
import '../../core/api/yobalema_api.dart';
import '../../core/constants/yobalema_theme.dart';
import '../../core/utils/error_helper.dart';

class PassengerAuthScreen extends StatefulWidget {
  final YobalemaApi api;
  final void Function(Map<String, dynamic> user, String token) onAuthenticated;

  const PassengerAuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  @override
  State<PassengerAuthScreen> createState() => _PassengerAuthScreenState();
}

class _PassengerAuthScreenState extends State<PassengerAuthScreen> {
  bool isRegister = false;
  final phoneCtrl = TextEditingController(text: '+221770000002');
  final passCtrl = TextEditingController(text: 'Yobalema123!');
  final nameCtrl = TextEditingController(text: 'Mamadou Diallo');
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    phoneCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text;
    final name = nameCtrl.text.trim();

    if (phone.length < 8 || pass.length < 4) {
      _toast(
          'Veuillez entrer un numéro valide et un mot de passe (min 4 caractères).');
      return;
    }

    setState(() => loading = true);
    try {
      Map<String, dynamic> res;
      if (isRegister) {
        res = await widget.api.register(
          phone: phone,
          password: pass,
          name: name.isEmpty ? 'Passager Yobalema' : name,
          role: 'PASSENGER',
        );
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
                      color: YobalemaTheme.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.two_wheeler,
                        color: YobalemaTheme.ink, size: 32),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOBALEMA MOTO',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: YobalemaTheme.ink),
                      ),
                      Text(
                        'Passager • Région de Kaolack',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: YobalemaTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),
              Text(
                isRegister
                    ? 'Créer un compte Passager'
                    : 'Bon retour parmi nous !',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: YobalemaTheme.ink),
              ),
              const SizedBox(height: 6),
              Text(
                isRegister
                    ? 'Commandez vos trajets en moto en toute sécurité dans toute la région de Kaolack.'
                    : 'Connectez-vous pour commander votre moto.',
                style: const TextStyle(
                    color: YobalemaTheme.textMuted, fontSize: 13),
              ),

              const SizedBox(height: 28),

              if (isRegister) ...[
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person),
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
                    icon:
                        Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isRegister ? 'S\'inscrire' : 'Se connecter'),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () => setState(() => isRegister = !isRegister),
                child: Text(
                  isRegister
                      ? 'Vous avez déjà un compte ? Se connecter'
                      : 'Nouveau sur Yobalema ? Créer un compte',
                  style: const TextStyle(
                      color: YobalemaTheme.ink, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
