
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'api.dart';

void main() => runApp(const YobalemaApp());

class YobalemaApp extends StatelessWidget {
  const YobalemaApp({super.key});

  static const yellow = Color(0xFFFFCC00);
  static const ink = Color(0xFF111111);
  static const grey = Color(0xFFF4F4F4);
  static const green = Color(0xFF159947);
  static const red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yobalema',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: yellow,
          brightness: Brightness.light,
        ).copyWith(
          primary: ink,
          secondary: yellow,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: grey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: yellow, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

enum Role { passenger, driver }
enum ZoneType { city, periurban, village }

class Commune {
  final String name;
  final String department;
  final LatLng point;
  final ZoneType zone;
  const Commune(this.name, this.department, this.point, this.zone);
}

class PriceQuote {
  final int total;
  final int driver;
  final int platform;
  final double trafficFactor;
  final String explanation;
  const PriceQuote({
    required this.total,
    required this.driver,
    required this.platform,
    required this.trafficFactor,
    required this.explanation,
  });
}

class Ride {
  final String from;
  final String to;
  final int price;
  final DateTime date;
  Ride(this.from, this.to, this.price, this.date);
}

class RegionKaolack {
  static const communes = <Commune>[
    Commune('Kaolack', 'Kaolack', LatLng(14.1510, -16.0726), ZoneType.city),
    Commune('Kahone', 'Kaolack', LatLng(14.1560, -16.0400), ZoneType.periurban),
    Commune('Keur Socé', 'Kaolack', LatLng(14.0100, -16.0300), ZoneType.village),
    Commune('Ndiaffate', 'Kaolack', LatLng(14.1200, -16.0000), ZoneType.village),
    Commune('Ndiédieng', 'Kaolack', LatLng(14.0800, -15.9700), ZoneType.village),
    Commune('Latmingué', 'Kaolack', LatLng(14.2700, -15.9800), ZoneType.village),
    Commune('Thiaré', 'Kaolack', LatLng(13.9800, -15.9000), ZoneType.village),
    Commune('Keur Baka', 'Kaolack', LatLng(13.9900, -16.1000), ZoneType.village),
    Commune('Ndoffane', 'Kaolack', LatLng(13.8447, -15.9382), ZoneType.city),
    Commune('Dya', 'Kaolack', LatLng(14.0200, -16.1300), ZoneType.village),
    Commune('Ndiébel', 'Kaolack', LatLng(14.0900, -15.8800), ZoneType.village),
    Commune('Thiomby', 'Kaolack', LatLng(13.9000, -16.0200), ZoneType.village),
    Commune('Gandiaye', 'Kaolack', LatLng(14.2300, -16.3200), ZoneType.village),
    Commune('Sibassor', 'Kaolack', LatLng(14.1500, -16.0000), ZoneType.periurban),
    Commune('Nioro du Rip', 'Nioro du Rip', LatLng(13.7500, -15.7800), ZoneType.city),
    Commune('Keur Madiabel', 'Nioro du Rip', LatLng(13.8500, -15.8500), ZoneType.village),
    Commune('Médina Sabakh', 'Nioro du Rip', LatLng(13.8500, -15.5500), ZoneType.village),
    Commune('Ngayène', 'Nioro du Rip', LatLng(13.6500, -15.7000), ZoneType.village),
    Commune('Kayemor', 'Nioro du Rip', LatLng(13.6500, -15.9000), ZoneType.village),
    Commune('Paoskoto', 'Nioro du Rip', LatLng(13.6500, -15.6000), ZoneType.village),
    Commune('Gainthé Kaye', 'Nioro du Rip', LatLng(13.7000, -15.6500), ZoneType.village),
    Commune('Taïba Niassène', 'Nioro du Rip', LatLng(13.8500, -15.6500), ZoneType.village),
    Commune('Porokhane', 'Nioro du Rip', LatLng(13.8000, -15.7000), ZoneType.village),
    Commune('Darou Salam', 'Nioro du Rip', LatLng(13.7000, -15.8000), ZoneType.village),
    Commune('Dabaly', 'Nioro du Rip', LatLng(13.7500, -15.6500), ZoneType.village),
    Commune('Keur Maba Diakhou', 'Nioro du Rip', LatLng(13.6000, -15.8000), ZoneType.village),
    Commune('Keur Mandongo', 'Nioro du Rip', LatLng(13.6000, -15.7000), ZoneType.village),
    Commune('Ndramé Escale', 'Nioro du Rip', LatLng(13.5500, -15.6500), ZoneType.village),
    Commune('Wack Ngouna', 'Nioro du Rip', LatLng(13.6000, -15.6000), ZoneType.village),
    Commune('Guinguinéo', 'Guinguinéo', LatLng(14.2700, -15.9500), ZoneType.city),
    Commune('Mbadakhoune', 'Guinguinéo', LatLng(14.3000, -15.8500), ZoneType.village),
    Commune('Ndiago', 'Guinguinéo', LatLng(14.3500, -15.8500), ZoneType.village),
    Commune('Ngathie Naoudé', 'Guinguinéo', LatLng(14.3500, -15.9500), ZoneType.village),
    Commune('Khelcom Birane', 'Guinguinéo', LatLng(14.3000, -15.7000), ZoneType.village),
    Commune('Fass', 'Guinguinéo', LatLng(14.2500, -15.8000), ZoneType.village),
    Commune('Gagnick', 'Guinguinéo', LatLng(14.2500, -15.7000), ZoneType.village),
    Commune('Nguélou', 'Guinguinéo', LatLng(14.2000, -15.7000), ZoneType.village),
    Commune('Ourour', 'Guinguinéo', LatLng(14.2000, -15.8000), ZoneType.village),
    Commune('Dara Mboss', 'Guinguinéo', LatLng(14.3000, -15.6500), ZoneType.village),
    Commune('Panal Wolof', 'Guinguinéo', LatLng(14.2000, -15.6500), ZoneType.village),
    Commune('Mboss', 'Guinguinéo', LatLng(14.2300, -15.7800), ZoneType.village),
  ];

  static bool inKaolack(LatLng p) =>
      p.latitude >= 13.50 &&
      p.latitude <= 14.55 &&
      p.longitude >= -16.45 &&
      p.longitude <= -15.35;
}

class Pricing {
  static const double commission = 0.10;

  static double trafficFactor({
    required ZoneType zone,
    required int trafficLevel,
  }) {
    if (zone == ZoneType.village) return 1.0;
    if (trafficLevel <= 0) return 1.0;
    if (trafficLevel == 1) return 1.05;
    if (trafficLevel == 2) return 1.10;
    return 1.15;
  }

  static PriceQuote calculate({
    required double km,
    required ZoneType fromZone,
    required ZoneType toZone,
    required int trafficLevel,
    required bool night,
  }) {
    final zone = fromZone == ZoneType.city || toZone == ZoneType.city
        ? ZoneType.city
        : (fromZone == ZoneType.periurban || toZone == ZoneType.periurban
            ? ZoneType.periurban
            : ZoneType.village);

    double base;
    String explanation;

    if (zone == ZoneType.city) {
      if (km <= 2) {
        base = 300;
      } else if (km <= 4) {
        base = 400;
      } else if (km <= 6) {
        base = 500;
      } else if (km <= 10) {
        base = 700;
      } else {
        base = 700 + (km - 10) * 75;
      }
      explanation = 'Tarif urbain : distance + trafic plafonné.';
    } else if (zone == ZoneType.periurban) {
      base = 500 + km * 85;
      explanation = 'Tarif périurbain : distance + disponibilité.';
    } else {
      base = 350 + km * 95;
      explanation = 'Tarif village : distance + temps + conditions de route.';
    }

    var total = base * trafficFactor(zone: zone, trafficLevel: trafficLevel);
    if (night) {
      total += zone == ZoneType.village ? 100 : 200;
    }

    total = total.clamp(300, 5000);
    final rounded = ((total / 50).round() * 50).toInt();
    final driver = (rounded * 0.90).round();
    final platform = rounded - driver;

    return PriceQuote(
      total: rounded,
      driver: driver,
      platform: platform,
      trafficFactor: trafficFactor(zone: zone, trafficLevel: trafficLevel),
      explanation: explanation,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  Role role = Role.passenger;
  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final api = YobalemaApi();
  bool loading = false;

  Future<void> login() async {
    if (phone.text.trim().length < 8 || password.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre un téléphone valide et un mot de passe de 4 caractères minimum.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      Map<String, dynamic> data;
      try {
        data = await api.login(phone.text.trim(), password.text);
      } catch (_) {
        data = await api.register(
          phone: phone.text.trim(),
          password: password.text,
          name: name.text.trim().isEmpty ? 'Utilisateur Yobalema' : name.text.trim(),
          role: role == Role.driver ? 'DRIVER' : 'PASSENGER',
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            role: role,
            phone: phone.text.trim(),
            api: api,
            user: Map<String, dynamic>.from(data['user'] ?? {}),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    name.dispose();
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 82,
                    decoration: BoxDecoration(
                      color: YobalemaApp.yellow,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(Icons.two_wheeler, size: 48, color: YobalemaApp.ink),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Yobalema',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: YobalemaApp.ink),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'La mobilité qui rapproche Kaolack.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  SegmentedButton<Role>(
                    segments: const [
                      ButtonSegment(value: Role.passenger, label: Text('Passager'), icon: Icon(Icons.person)),
                      ButtonSegment(value: Role.driver, label: Text('Chauffeur'), icon: Icon(Icons.two_wheeler)),
                    ],
                    selected: {role},
                    onSelectionChanged: (v) => setState(() => role = v.first),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.badge)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Numéro de téléphone', prefixIcon: Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock)),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: loading ? null : login,
                    icon: loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward),
                    label: Text(loading ? 'Connexion...' : 'Continuer'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '© 2026 Yobalema — Créée par Babacar NDIAYE',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const _InfoCard(
                    icon: Icons.location_on,
                    title: 'Région de Kaolack uniquement',
                    text: 'Kaolack • Nioro du Rip • Guinguinéo',
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

class HomeScreen extends StatefulWidget {
  final Role role;
  final String phone;
  final YobalemaApi api;
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.role, required this.phone, required this.api, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final mapController = MapController();
  final history = <Ride>[];
  late Commune from;
  late Commune to;
  bool night = false;
  bool shareTrip = false;
  bool searching = false;
  bool online = false;
  bool backendReady = false;
  String? activeRideId;
  int trafficLevel = 1;
  double distanceKm = 44;
  PriceQuote? quote;
  Timer? gpsTimer;
  LatLng? liveDriverPosition;
  List<LatLng> roadRoute = const [];
  double? roadDistanceKm;
  double? roadDurationMin;
  bool routing = false;

  @override
  void initState() {
    super.initState();
    from = RegionKaolack.communes.firstWhere((c) => c.name == 'Ndoffane');
    to = RegionKaolack.communes.firstWhere((c) => c.name == 'Kaolack');
    _refreshRoute();
    _reprice();
    widget.api.connectSocket(
      onRideNew: widget.role == Role.driver ? _onRideNew : null,
      onRideOffer: widget.role == Role.driver ? _onRideOffer : null,
      onRideAccepted: _onRideAccepted,
      userId: widget.user['id']?.toString(),
      role: widget.role == Role.driver ? 'DRIVER' : 'PASSENGER',
      onRideStatus: _onRideStatus,
      onRideLocation: _onRideLocation,
    );
    backendReady = true;
  }

  Future<void> _refreshRoute() async {
    if (routing) return;
    routing = true;
    if (mounted) setState(() {});
    final result = await widget.api.roadRoute(
      fromLat: from.point.latitude,
      fromLng: from.point.longitude,
      toLat: to.point.latitude,
      toLng: to.point.longitude,
    );
    if (!mounted) return;
    setState(() {
      routing = false;
      if (result == null) {
        roadRoute = const [];
        roadDistanceKm = null;
        roadDurationMin = null;
        distanceKm = _straightLineKm(from.point, to.point);
      } else {
        final points = (result['points'] as List<dynamic>)
            .map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList(growable: false);
        roadRoute = points;
        roadDistanceKm = (result['distanceKm'] as num).toDouble();
        roadDurationMin = (result['durationMin'] as num).toDouble();
        distanceKm = roadDistanceKm!;
      }
    });
    await _reprice();
  }

  double _straightLineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180;
    final dLng = (b.longitude - a.longitude) * 3.141592653589793 / 180;
    final la1 = a.latitude * 3.141592653589793 / 180;
    final la2 = b.latitude * 3.141592653589793 / 180;
    final h = (1 - (dLat.cos() * 0 + 0)); 
    final x = (dLat / 2).sin() * (dLat / 2).sin() +
        la1.cos() * la2.cos() * (dLng / 2).sin() * (dLng / 2).sin();
    return r * 2 * x.sqrt().atan2((1 - x).sqrt());
  }

  Future<void> _reprice() async {
    final local = Pricing.calculate(
      km: distanceKm,
      fromZone: from.zone,
      toZone: to.zone,
      trafficLevel: trafficLevel,
      night: night,
    );
    if (mounted) setState(() => quote = local);
    try {
      final data = await widget.api.quote(
        fromName: from.name,
        toName: to.name,
        fromLat: from.point.latitude,
        fromLng: from.point.longitude,
        toLat: to.point.latitude,
        toLng: to.point.longitude,
        fromZone: _zone(from.zone),
        toZone: _zone(to.zone),
        trafficLevel: trafficLevel,
        night: night,
      );
      final total = (data['total'] as num).round();
      final driver = (data['driver'] as num).round();
      final platform = (data['platform'] as num).round();
      final factor = (data['trafficFactor'] as num?)?.toDouble() ?? 1.0;
      final serverKm = (data['distanceKm'] as num?)?.toDouble();
      if (mounted) {
        setState(() {
          quote = PriceQuote(
            total: total,
            driver: driver,
            platform: platform,
            trafficFactor: factor,
            explanation: data['explanation']?.toString() ?? local.explanation,
          );
          if (serverKm != null && roadRoute.isEmpty) distanceKm = serverKm;
        });
      }
    } catch (_) {}
  }

  String _zone(ZoneType z) => z == ZoneType.city ? 'CITY' : z == ZoneType.periurban ? 'PERIURBAN' : 'VILLAGE';

  Future<void> locateMe() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _toast('Active la localisation du téléphone.');
      return;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      _toast('Permission GPS refusée.');
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final point = LatLng(pos.latitude, pos.longitude);
    if (!RegionKaolack.inKaolack(point)) {
      _toast('Yobalema est actuellement disponible uniquement dans la région de Kaolack.');
      return;
    }
    mapController.move(point, 14);
    _toast('Position GPS détectée.');
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> requestRide() async {
    if (quote == null) return;
    setState(() => searching = true);
    try {
      final data = await widget.api.createRide(
        fromName: from.name,
        toName: to.name,
        fromLat: from.point.latitude,
        fromLng: from.point.longitude,
        toLat: to.point.latitude,
        toLng: to.point.longitude,
        fromZone: _zone(from.zone),
        toZone: _zone(to.zone),
        trafficLevel: trafficLevel,
        night: night,
        shareTrip: shareTrip,
      );
      final ride = Map<String, dynamic>.from(data['ride']);
      activeRideId = ride['id']?.toString();
      if (activeRideId != null) widget.api.joinRide(activeRideId!);
      final total = (ride['priceFcfa'] as num).round();
      setState(() {
        searching = false;
        history.insert(0, Ride(from.name, to.name, total, DateTime.now()));
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Course créée'),
          content: Text(
            '${from.name} → ${to.name}\nPrix : $total FCFA\n'
            '${roadDistanceKm != null ? 'Route : ${roadDistanceKm!.toStringAsFixed(1)} km\n' : ''}'
            '${roadDurationMin != null ? 'ETA : ${roadDurationMin!.toStringAsFixed(0)} min\n' : ''}'
            '\nRecherche d’un chauffeur en temps réel...',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris')),
          ],
        ),
      );
    } catch (e) {
      setState(() => searching = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onRideOffer(Map<String, dynamic> data) {
    if (!online || !mounted || data['rideId'] == null) return;
    final rideId = data['rideId'].toString();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Course pour vous'),
        content: Text(
          '${data['from'] ?? ''} → ${data['to'] ?? ''}\n'
          'Prix : ${data['priceFcfa'] ?? 0} FCFA\n'
          'Distance vers le départ : ${data['distanceKm'] ?? '--'} km',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.api.acceptRide(rideId);
                activeRideId = rideId;
                widget.api.joinRide(rideId);
                _toast('Course acceptée. Navigation vers le départ.');
              } catch (e) {
                _toast(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }

  void _onRideNew(Map<String, dynamic> data) {
    if (!online || !mounted || data['rideId'] == null) return;
    final rideId = data['rideId'].toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle course'),
        content: Text('${data['from'] ?? ''} → ${data['to'] ?? ''}\nPrix : ${data['priceFcfa'] ?? 0} FCFA'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Refuser')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.api.acceptRide(rideId);
                _toast('Course acceptée. Rendez-vous au départ.');
              } catch (e) {
                _toast(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }

  void _onRideAccepted(Map<String, dynamic> data) {
    if (activeRideId != data['rideId']?.toString()) return;
    _toast('Un chauffeur a accepté votre course.');
  }

  void _onRideStatus(Map<String, dynamic> data) {
    if (activeRideId != data['rideId']?.toString()) return;
    _toast('Statut de la course : ${data['status']}');
  }

  void _onRideLocation(Map<String, dynamic> data) {
    if (activeRideId != data['rideId']?.toString()) return;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return;
    if (!mounted) return;
    setState(() => liveDriverPosition = LatLng(lat, lng));
  }

  void driverPanel() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (context, modalSetState) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.two_wheeler, size: 50, color: YobalemaApp.ink),
              const Text('Espace chauffeur', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(online ? 'EN LIGNE — prêt à recevoir des courses' : 'HORS LIGNE'),
              Switch(
                value: online,
                activeThumbColor: YobalemaApp.yellow,
                onChanged: (v) async {
                  try {
                    await widget.api.setDriverStatus(v ? 'ONLINE' : 'OFFLINE');
                    if (v) {
                      try {
                        final pos = await Geolocator.getCurrentPosition();
                        liveDriverPosition = LatLng(pos.latitude, pos.longitude);
                        await widget.api.updateDriverLocation(pos.latitude, pos.longitude);
                        gpsTimer?.cancel();
                        gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
                          try {
                            final p = await Geolocator.getCurrentPosition();
                            liveDriverPosition = LatLng(p.latitude, p.longitude);
                            await widget.api.updateDriverLocation(p.latitude, p.longitude);
                            if (mounted) setState(() {});
                          } catch (_) {}
                        });
                      } catch (_) {}
                    } else {
                      gpsTimer?.cancel();
                      gpsTimer = null;
                    }
                    modalSetState(() => online = v);
                    setState(() {});
                    _toast(v ? 'Vous êtes maintenant en ligne.' : 'Vous êtes hors ligne.');
                  } catch (e) {
                    _toast(e.toString().replaceFirst('Exception: ', ''));
                  }
                },
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.account_balance_wallet),
                title: Text('Commission Yobalema'),
                subtitle: Text('10 % par course'),
                trailing: Text('90 %', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const ListTile(
                leading: Icon(Icons.verified_user, color: YobalemaApp.green),
                title: Text('Chauffeurs vérifiés'),
                subtitle: Text('Vérification à connecter au backend'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void historyPanel() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Mes courses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (history.isEmpty) const Text('Aucune course pour le moment.'),
          ...history.map((r) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: YobalemaApp.yellow,
              child: Icon(Icons.two_wheeler, color: YobalemaApp.ink),
            ),
            title: Text('${r.from} → ${r.to}'),
            subtitle: Text('${r.date.day}/${r.date.month}/${r.date.year}'),
            trailing: Text('${r.price} F', style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }

  Future<void> support() async {
    final uri = Uri(scheme: 'tel', path: '+221000000000');
    try {
      await launchUrl(uri);
    } catch (_) {
      _toast('Numéro support à configurer.');
    }
  }

  @override
  void dispose() {
    gpsTimer?.cancel();
    widget.api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = quote!;
    final displayRoute = roadRoute.length >= 2 ? roadRoute : [from.point, to.point];
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: from.point, initialZoom: 9.5),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.yobalema.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: displayRoute,
                    strokeWidth: routing ? 3 : 5,
                    color: YobalemaApp.yellow,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (liveDriverPosition != null)
                    Marker(
                      point: liveDriverPosition!,
                      width: 46,
                      height: 46,
                      child: const Icon(Icons.two_wheeler, size: 34, color: YobalemaApp.green),
                    ),
                  Marker(
                    point: from.point,
                    width: 42,
                    height: 42,
                    child: const Icon(Icons.location_pin, size: 42, color: YobalemaApp.ink),
                  ),
                  Marker(
                    point: to.point,
                    width: 42,
                    height: 42,
                    child: const Icon(Icons.flag, size: 38, color: YobalemaApp.yellow),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _CircleButton(icon: Icons.history, onTap: historyPanel),
                  const Spacer(),
                  _CircleButton(icon: Icons.my_location, onTap: locateMe),
                  const SizedBox(width: 8),
                  _CircleButton(icon: Icons.support_agent, onTap: support),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: backendReady ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 9, color: backendReady ? YobalemaApp.green : Colors.orange),
                        const SizedBox(width: 5),
                        Text(backendReady ? 'Serveur' : 'Local', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(icon: widget.role == Role.driver ? Icons.two_wheeler : Icons.person, onTap: driverPanel),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Votre trajet', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                        ),
                        Text('${q.total} F', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.alt_route, size: 17),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            roadDistanceKm != null
                                ? '${roadDistanceKm!.toStringAsFixed(1)} km sur route • ${roadDurationMin?.toStringAsFixed(0) ?? '--'} min'
                                : 'Calcul de l’itinéraire routier...',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (routing)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(q.explanation, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                    const SizedBox(height: 10),
                    _selectBox('Départ', from, (v) {
                      if (v == null) return;
                      setState(() => from = v);
                      _refreshRoute();
                    }),
                    const SizedBox(height: 8),
                    _selectBox('Destination', to, (v) {
                      if (v == null) return;
                      setState(() => to = v);
                      _refreshRoute();
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _smallChoice(
                            title: 'Trafic',
                            value: ['Fluide', 'Modéré', 'Important', 'Très fort'][trafficLevel],
                            icon: Icons.traffic,
                            onTap: () {
                              setState(() => trafficLevel = (trafficLevel + 1) % 4);
                              _reprice();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _smallChoice(
                            title: 'Moment',
                            value: night ? 'Nuit' : 'Jour',
                            icon: night ? Icons.nightlight : Icons.wb_sunny,
                            onTap: () {
                              setState(() => night = !night);
                              _reprice();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Partager mon trajet'),
                      subtitle: const Text('Prévenir un proche pendant la course'),
                      value: shareTrip,
                      activeThumbColor: YobalemaApp.yellow,
                      onChanged: (v) => setState(() => shareTrip = v),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.percent, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('90 % chauffeur • 10 % Yobalema')),
                          Text('${q.driver} F', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: searching ? null : requestRide,
                      icon: searching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.two_wheeler),
                      label: Text(searching ? 'Recherche d’un chauffeur...' : 'Commander Yobalema'),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Prix affiché avant validation • Région de Kaolack uniquement',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectBox(String label, Commune value, ValueChanged<Commune?> onChanged) {
    return DropdownButtonFormField<Commune>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(label == 'Départ' ? Icons.my_location : Icons.location_on),
      ),
      items: RegionKaolack.communes
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text('${c.name} • ${c.department}'),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _smallChoice({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: YobalemaApp.ink),
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _InfoCard({required this.icon, required this.title, required this.text,});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: YobalemaApp.yellow),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      );
}
