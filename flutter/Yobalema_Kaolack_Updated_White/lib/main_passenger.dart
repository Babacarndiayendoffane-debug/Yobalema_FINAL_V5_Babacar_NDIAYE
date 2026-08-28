import 'package:flutter/material.dart';
import 'api.dart';

void main() => runApp(const YobalemaPassengerApp());

class YobalemaPassengerApp extends StatelessWidget {
  const YobalemaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Yobalema Passenger',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFFFCC00)),
        home: const PassengerAuthScreen(),
      );
}

class PassengerAuthScreen extends StatelessWidget {
  const PassengerAuthScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_pin_circle, size: 72),
              const SizedBox(height: 16),
              const Text('Yobalema Passenger', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Commander une moto dans la région de Kaolack.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PassengerHomeScreen())),
                child: const Text('Continuer comme passager'),
              ),
            ]),
          ),
        ),
      );
}

class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yobalema Passenger')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Où veux-tu aller ?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Lieu de départ', prefixIcon: Icon(Icons.my_location), border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Destination', prefixIcon: Icon(Icons.location_on), border: OutlineInputBorder())),
            const Spacer(),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.two_wheeler), label: const Text('Rechercher une moto')),
            const SizedBox(height: 8),
            const Text('Tarifs Yobalema: motos uniquement • commission plateforme 10 %', textAlign: TextAlign.center),
          ]),
        ),
      );
}

// Kept as an explicit dependency boundary for the existing shared backend client.
YobalemaApi passengerApi() => YobalemaApi();
