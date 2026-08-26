import 'package:flutter/material.dart';
import '../../api.dart';
import 'auth_home.dart';

class VerifyOtpScreen extends StatefulWidget {
  final YobalemaApi api;
  final Map<String, dynamic> user;
  final String role;
  final String? devOtp;
  final AuthCallback onAuthenticated;

  const VerifyOtpScreen({
    super.key,
    required this.api,
    required this.user,
    required this.role,
    this.devOtp,
    required this.onAuthenticated,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final otpController = TextEditingController();
  bool loading = false;
  String? devCode;

  @override
  void initState() {
    super.initState();
    devCode = widget.devOtp;
    if (devCode != null && devCode!.isNotEmpty) {
      otpController.text = devCode!;
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final code = otpController.text.trim();
    if (code.length != 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez saisir le code a 6 chiffres')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => loading = true);
    try {
      await widget.api.verifyOtp(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numero verifie avec succes !'), backgroundColor: Colors.green),
      );
      widget.onAuthenticated(context, widget.user, widget.role, widget.api);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resend() async {
    try {
      final res = await widget.api.requestOtp();
      if (!mounted) return;
      if (res['devOtp'] != null) {
        setState(() {
          devCode = res['devOtp'].toString();
          otpController.text = devCode!;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nouveau code envoye par SMS')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification du numero')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.mark_email_read, size: 64, color: Color(0xFFFFCC00)),
              const SizedBox(height: 16),
              const Text(
                'Code de confirmation (OTP)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez le code a 6 chiffres envoye au ${widget.user['phone'] ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                ),
              ),
              const SizedBox(height: 12),

              if (devCode != null)
                Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.developer_mode, size: 16),
                    label: Text('Code test detecte : $devCode (Cliquer pour coller)'),
                    onPressed: () => setState(() => otpController.text = devCode!),
                  ),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Valider le code'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: resend,
                child: const Text('Renvoyer un nouveau code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
