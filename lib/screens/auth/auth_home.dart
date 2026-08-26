import 'package:flutter/material.dart';
import '../../api.dart';
import 'login_screen.dart';
import 'register_driver.dart';
import 'register_passenger.dart';

typedef AuthCallback = void Function(BuildContext context, Map<String, dynamic> user, String role, YobalemaApi api);

class AuthHome extends StatefulWidget {
  final YobalemaApi api;
  final AuthCallback onAuthenticated;

  const AuthHome({super.key, required this.api, required this.onAuthenticated});

  @override
  State<AuthHome> createState() => _AuthHomeState();
}

class _AuthHomeState extends State<AuthHome> {
  bool checkingSession = true;
  bool loadingQuick = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final session = await widget.api.restoreSession();
    if (!mounted) return;
    if (session != null) {
      widget.onAuthenticated(
        context,
        Map<String, dynamic>.from(session['user'] as Map),
        session['role']?.toString() ?? 'PASSENGER',
        widget.api,
      );
      return;
    }
    setState(() => checkingSession = false);
  }

  Future<void> _quickLogin(String phone, String password) async {
    if (!mounted) return;
    setState(() => loadingQuick = true);
    try {
      final data = await widget.api.login(phone, password);
      if (!mounted) return;
      final user = Map<String, dynamic>.from(data['user'] ?? {});
      final role = user['role']?.toString() ?? 'PASSENGER';
      widget.onAuthenticated(context, user, role, widget.api);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => loadingQuick = false);
    }
  }

  void _enterAsGuest() {
    widget.onAuthenticated(
      context,
      {'id': 'guest-passenger', 'phone': '+221770000000', 'name': 'Passager Invite', 'role': 'PASSENGER'},
      'PASSENGER',
      widget.api,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checkingSession) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFCC00)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bienvenue', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.two_wheeler, size: 48, color: Color(0xFF111111)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Yobalema',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF111111)),
              ),
              const SizedBox(height: 4),
              const Text(
                'La mobilite qui rapproche Kaolack',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _enterAsGuest,
                icon: const Icon(Icons.explore),
                label: const Text('Continuer (Mode Demo Kaolack)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: const Color(0xFF111111),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),

              const Divider(),
              const SizedBox(height: 10),

              const Text(
                'Votre compte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api, onAuthenticated: widget.onAuthenticated)),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Se connecter'),
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterPassengerScreen(api: widget.api, onAuthenticated: widget.onAuthenticated)),
                ),
                icon: const Icon(Icons.person_add),
                label: const Text("S'inscrire (Passager)"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterDriverScreen(api: widget.api, onAuthenticated: widget.onAuthenticated)),
                ),
                icon: const Icon(Icons.two_wheeler),
                label: const Text('Devenir chauffeur'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              const Text(
                'Acces rapide (Comptes de test) :',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: loadingQuick ? null : () => _quickLogin('+221770000002', 'Yobalema123!'),
                      child: const Text('Passager Demo', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: loadingQuick ? null : () => _quickLogin('+221770000001', 'Yobalema123!'),
                      child: const Text('Chauffeur Demo', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              if (loadingQuick) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
    );
  }
}
