import 'package:flutter/material.dart';
import 'api.dart';

void main() => runApp(const YobalemaDriverApp());

class YobalemaDriverApp extends StatelessWidget {
  const YobalemaDriverApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Yobalema Driver',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF159947)),
        home: const DriverAuthScreen(),
      );
}

class DriverAuthScreen extends StatelessWidget {
  const DriverAuthScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.two_wheeler, size: 72),
              const SizedBox(height: 16),
              const Text('Yobalema Driver', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('L’espace professionnel réservé aux chauffeurs moto Yobalema.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DriverHomeScreen())),
                child: const Text('Continuer comme chauffeur'),
              ),
            ]),
          ),
        ),
      );
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool online = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yobalema Driver')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SwitchListTile(
              value: online,
              onChanged: (value) => setState(() => online = value),
              title: Text(online ? 'Vous êtes en ligne' : 'Vous êtes hors ligne'),
              subtitle: const Text('Seuls les chauffeurs moto disponibles reçoivent les demandes.'),
            ),
            const SizedBox(height: 24),
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: const [
              Icon(Icons.account_balance_wallet_outlined, size: 40),
              SizedBox(height: 8),
              Text('Mes gains', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Les gains sont calculés avec 90 % chauffeur et 10 % plateforme.'),
            ]))),
            const Spacer(),
            FilledButton.icon(onPressed: online ? () {} : null, icon: const Icon(Icons.notifications_active), label: const Text('Prêt à recevoir des courses')),
          ]),
        ),
      );
}

YobalemaApi driverApi() => YobalemaApi();
