import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../api.dart';
import '../../main.dart';
import '../auth/auth_home.dart';

class PassengerScreen extends StatefulWidget {
  final String phone;
  final YobalemaApi api;
  final Map<String, dynamic> user;

  const PassengerScreen({
    super.key,
    required this.phone,
    required this.api,
    required this.user,
  });

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final mapController = MapController();
  final routingService = RoutingService();
  final history = <RideModel>[];

  late Commune from;
  late Commune to;
  bool shareTrip = false;
  bool searching = false;
  bool backendReady = false;
  bool isRoutingLoading = false;

  String paymentMethod = 'CASH'; // CASH, WAVE, ORANGE_MONEY
  String? activeRideId;
  String? activeRideStatus;
  String? pickupPin; // 6-digit OTP given to driver

  double distanceKm = 37.0;
  PriceQuote? quote;
  RouteResult? currentRoute;

  Timer? pollTimer;
  LatLng? liveDriverPosition;

  static const yellow = Color(0xFFFFCC00);
  static const ink = Color(0xFF111111);
  static const green = Color(0xFF159947);

  @override
  void initState() {
    super.initState();
    from = RegionKaolack.communes.firstWhere((c) => c.name.contains('Ndoffane'));
    to = RegionKaolack.communes.firstWhere((c) => c.name.contains('Kaolack'));
    distanceKm = 41.2;
    quote = Pricing.calculate(km: distanceKm, fromZone: from.zone, toZone: to.zone);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reprice();
      _initRealtimeAndBackend();
    });
  }

  Future<void> _initRealtimeAndBackend() async {
    final health = await widget.api.checkHealth();
    if (!mounted) return;
    setState(() => backendReady = health);

    widget.api.connectSocket(
      onRideAccepted: _onRideAccepted,
      onRideStatus: _onRideStatus,
      onRideLocation: _onRideLocation,
      userId: widget.user['id']?.toString(),
      role: 'PASSENGER',
    );

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final list = await widget.api.ridesHistory();
      if (!mounted) return;
      setState(() {
        history.clear();
        for (final item in list) {
          history.add(
            RideModel(
              id: item['id']?.toString() ?? '',
              from: item['fromName']?.toString() ?? '',
              to: item['toName']?.toString() ?? '',
              price: (item['priceFcfa'] as num?)?.toInt() ?? 0,
              status: item['status']?.toString() ?? '',
              paymentMethod: item['paymentMethod']?.toString() ?? 'CASH',
              date: DateTime.tryParse(item['createdAt']?.toString() ?? '') ?? DateTime.now(),
            ),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _reprice() async {
    if (mounted) setState(() => isRoutingLoading = true);

    // Calcul de l'itinéraire routier réel
    final route = await routingService.getRoute(from.point, to.point);
    if (!mounted) return;

    distanceKm = route.distanceKm;
    currentRoute = route;
    isRoutingLoading = false;

    // Détermination automatique Jour/Nuit et Trafic estimé
    final isNight = Pricing.isNightTime();
    final traffic = Pricing.estimatedTrafficLevel();

    final local = Pricing.calculate(
      km: distanceKm,
      fromZone: from.zone,
      toZone: to.zone,
      trafficLevel: traffic,
      night: isNight,
    );
    setState(() => quote = local);

    _fitRouteBounds(route.points);

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
        trafficLevel: traffic,
        night: isNight,
        distanceKm: distanceKm,
      );
      if (!mounted) return;
      final total = (data['total'] as num).round();
      final driver = (data['driver'] as num).round();
      final platform = (data['platform'] as num).round();
      final factor = (data['trafficFactor'] as num?)?.toDouble() ?? 1.0;
      setState(() {
        quote = PriceQuote(
          total: total,
          driver: driver,
          platform: platform,
          trafficFactor: factor,
          explanation: data['explanation']?.toString() ?? local.explanation,
        );
      });
    } catch (_) {}
  }

  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final bounds = LatLngBounds.fromPoints(points);
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(
              top: 80,
              bottom: 270,
              left: 36,
              right: 36,
            ),
          ),
        );
      } catch (_) {}
    });
  }

  String _zone(ZoneType z) => z == ZoneType.city ? 'CITY' : z == ZoneType.periurban ? 'PERIURBAN' : 'VILLAGE';

  Future<void> locateMe() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) _toast('Veuillez activer la localisation GPS.');
        return;
      }
      var p = await Geolocator.checkPermission();
      if (!mounted) return;
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (!mounted) return;
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        if (mounted) _toast('Permission GPS non accordée.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      mapController.move(point, 13);
      _toast('Position GPS détectée.');
    } catch (e) {
      if (mounted) _toast('Localisation : ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _toast(String s, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
  }

  Future<void> requestRide() async {
    if (quote == null) return;
    if (!mounted) return;
    setState(() => searching = true);

    try {
      final isNight = Pricing.isNightTime();
      final traffic = Pricing.estimatedTrafficLevel();

      final data = await widget.api.createRide(
        fromName: from.name,
        toName: to.name,
        fromLat: from.point.latitude,
        fromLng: from.point.longitude,
        toLat: to.point.latitude,
        toLng: to.point.longitude,
        fromZone: _zone(from.zone),
        toZone: _zone(to.zone),
        trafficLevel: traffic,
        night: isNight,
        shareTrip: shareTrip,
        paymentMethod: paymentMethod,
        distanceKm: distanceKm,
      );
      if (!mounted) return;

      final ride = Map<String, dynamic>.from(data['ride'] ?? {});
      activeRideId = ride['id']?.toString();
      activeRideStatus = 'REQUESTED';

      if (activeRideId != null) {
        widget.api.joinRide(activeRideId!);
        _startRidePolling(activeRideId!);
      }

      final total = (ride['priceFcfa'] as num?)?.toInt() ?? quote!.total;
      setState(() {
        searching = false;
        history.insert(0, RideModel(
          id: activeRideId ?? '',
          from: from.name,
          to: to.name,
          price: total,
          status: 'REQUESTED',
          paymentMethod: paymentMethod,
          date: DateTime.now(),
        ));
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Course commandée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trajet : ${from.name} -> ${to.name}'),
              const SizedBox(height: 4),
              Text('Prix : ${_formatPrice(total)} FCFA (${_paymentLabel(paymentMethod)})'),
              const SizedBox(height: 8),
              const Text('Recherche d\'un chauffeur en temps réel...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => searching = false);
        _toast(e.toString().replaceFirst('Exception: ', ''), bg: Colors.red.shade700);
      }
    }
  }

  void _startRidePolling(String rideId) {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) {
        pollTimer?.cancel();
        return;
      }
      try {
        final r = await widget.api.getRide(rideId);
        if (!mounted) return;
        final st = r['status']?.toString();
        if (st != null && st != activeRideStatus) {
          _onRideStatus({'rideId': rideId, 'status': st});
        }
      } catch (_) {}
    });
  }

  Future<void> _generatePickupPin() async {
    if (activeRideId == null || !mounted) return;
    try {
      final res = await widget.api.requestPickupOtp(activeRideId!);
      if (!mounted) return;
      if (res['devOtp'] != null) {
        setState(() => pickupPin = res['devOtp'].toString());
      }
    } catch (e) {
      if (mounted) _toast('Génération code PIN : $e');
    }
  }

  void _onRideAccepted(Map<String, dynamic> data) {
    if (!mounted) return;
    if (activeRideId != data['rideId']?.toString()) return;
    setState(() => activeRideStatus = 'ACCEPTED');
    _generatePickupPin();
    _toast('Un chauffeur a accepté votre course !', bg: green);
  }

  void _onRideStatus(Map<String, dynamic> data) {
    if (!mounted) return;
    if (activeRideId != data['rideId']?.toString()) return;
    final st = data['status']?.toString();
    setState(() => activeRideStatus = st);

    if (st == 'DRIVER_ARRIVING') {
      _toast('Votre chauffeur est arrivé au point de départ !', bg: yellow);
    } else if (st == 'IN_PROGRESS') {
      _toast('Course démarrée ! En route.', bg: green);
    } else if (st == 'COMPLETED') {
      pollTimer?.cancel();
      _showRideCompletedDialog();
    } else if (st == 'CANCELLED') {
      pollTimer?.cancel();
      _toast('La course a été annulée.');
    }
  }

  void _onRideLocation(Map<String, dynamic> data) {
    if (!mounted) return;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      setState(() => liveDriverPosition = LatLng(lat, lng));
    }
  }

  void _showRideCompletedDialog() {
    if (!mounted) return;
    int rating = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Course terminée !'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Merci d\'avoir voyagé avec Yobalema.'),
              const SizedBox(height: 12),
              if (paymentMethod != 'CASH')
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text('Paiement ${_paymentLabel(paymentMethod)} enregistré.'),
                ),
              const SizedBox(height: 12),
              const Text('Évaluez votre expérience :', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                    onPressed: () => setDialogState(() => rating = index + 1),
                  );
                }),
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(hintText: 'Commentaire (optionnel)'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (activeRideId != null) {
                  try {
                    await widget.api.rateRide(activeRideId!, rating, comment: commentCtrl.text.trim());
                  } catch (_) {}
                }
                if (!mounted) return;
                setState(() {
                  activeRideId = null;
                  activeRideStatus = null;
                  pickupPin = null;
                });
                _toast('Merci pour votre avis !', bg: green);
                _loadHistory();
              },
              child: const Text('Envoyer l\'avis'),
            ),
          ],
        ),
      ),
    );
  }

  void historyPanel() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Mes courses', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (history.isEmpty) const Text('Aucune course enregistrée pour le moment.'),
          ...history.map((r) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: yellow,
                    child: Icon(Icons.directions_car, color: ink),
                  ),
                  title: Text('${r.from} -> ${r.to}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${r.date.day}/${r.date.month}/${r.date.year} • ${_paymentLabel(r.paymentMethod)} • Statut: ${_formatStatus(r.status)}'),
                  trailing: Text('${_formatPrice(r.price)} F', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> support() async {
    final uri = Uri(scheme: 'tel', path: '+221330000000');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) _toast('Numéro support : +221 33 000 00 00');
    }
  }

  Future<void> logout() async {
    await widget.api.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => AuthHome(
          api: widget.api,
          onAuthenticated: (ctx, user, role, api) {
            openHomeScreen(ctx, user: user, role: role, api: api);
          },
        ),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    widget.api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = quote ?? Pricing.calculate(km: distanceKm, fromZone: from.zone, toZone: to.zone);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: from.point,
              initialZoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yobalema.app',
              ),
              PolylineLayer(polylines: [
                if (currentRoute != null && currentRoute!.points.isNotEmpty)
                  Polyline(
                    points: currentRoute!.points,
                    strokeWidth: 5,
                    color: currentRoute!.isFallback ? const Color(0xFFE65100) : yellow,
                    borderColor: const Color(0xFF111111),
                    borderStrokeWidth: 1.5,
                  )
                else
                  Polyline(
                    points: [from.point, to.point],
                    strokeWidth: 4,
                    color: yellow,
                  ),
              ]),
              MarkerLayer(markers: [
                if (liveDriverPosition != null)
                  Marker(
                    point: liveDriverPosition!,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.two_wheeler, size: 38, color: green),
                  ),
                Marker(
                  point: from.point,
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.location_pin, size: 44, color: ink),
                ),
                Marker(
                  point: to.point,
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.flag, size: 40, color: Color(0xFFD32F2F)),
                ),
              ]),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _PassengerCircleButton(icon: Icons.history, onTap: historyPanel),
                  const SizedBox(width: 8),
                  _PassengerCircleButton(icon: Icons.logout, onTap: logout),
                  const Spacer(),
                  _PassengerCircleButton(icon: Icons.my_location, onTap: locateMe),
                  const SizedBox(width: 8),
                  _PassengerCircleButton(icon: Icons.support_agent, onTap: support),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: backendReady ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 9, color: backendReady ? green : Colors.orange),
                        const SizedBox(width: 5),
                        Text(backendReady ? 'Serveur OK' : 'Local', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PassengerCircleButton(
                    icon: Icons.person,
                    onTap: () => _toast('Connecté en tant que Passager (${widget.phone})'),
                  ),
                ],
              ),
            ),
          ),

          if (activeRideId != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: ink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Statut de la course : ${_formatStatus(activeRideStatus)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (activeRideStatus == 'ACCEPTED' || activeRideStatus == 'DRIVER_ARRIVING')
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              const Text('Code PIN de départ à donner au chauffeur :', style: TextStyle(fontSize: 12, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(
                                pickupPin ?? 'Génération en cours...',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: ink),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Prix estimé',
                                    style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                                  ),
                                  if (isRoutingLoading) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatPrice(q.total)} FCFA',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink),
                              ),
                            ],
                          ),
                        ),
                        if (currentRoute != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(currentRoute!.formattedDistance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(currentRoute!.formattedDuration, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                              ],
                            ),
                          ),
                      ],
                    ),

                    if (currentRoute?.isFallback == true) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 12, color: Color(0xFFE65100)),
                              SizedBox(width: 4),
                              Text(
                                'Estimation locale hors-ligne',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    _selectBox('Départ', from, (v) {
                      if (v == null) return;
                      setState(() => from = v);
                      _reprice();
                    }),
                    const SizedBox(height: 8),

                    _selectBox('Destination', to, (v) {
                      if (v == null) return;
                      setState(() => to = v);
                      _reprice();
                    }),
                    const SizedBox(height: 10),

                    _paymentSelector(),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: searching ? null : requestRide,
                      icon: searching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.directions_car),
                      label: Text(searching
                          ? 'Recherche d\'un chauffeur...'
                          : 'Commander Yobalema (${_paymentLabel(paymentMethod)})'),
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

  String _formatPrice(int amount) {
    final s = amount.toString();
    if (s.length > 3) {
      return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
    }
    return s;
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'WAVE':
        return 'Wave';
      case 'ORANGE_MONEY':
        return 'Orange Money';
      default:
        return 'Espèces';
    }
  }

  Widget _paymentSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 20, color: ink),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Mode de paiement',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: paymentMethod,
              isDense: true,
              borderRadius: BorderRadius.circular(14),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Espèces', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'WAVE', child: Text('Wave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'ORANGE_MONEY', child: Text('Orange Money', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => paymentMethod = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String? st) {
    switch (st) {
      case 'REQUESTED':
        return 'Recherche de chauffeur...';
      case 'ACCEPTED':
        return 'Chauffeur trouvé';
      case 'DRIVER_ARRIVING':
        return 'Chauffeur sur le point d\'arriver';
      case 'IN_PROGRESS':
        return 'Course en cours';
      case 'COMPLETED':
        return 'Course terminée';
      case 'CANCELLED':
        return 'Course annulée';
      default:
        return 'En attente';
    }
  }

  Widget _selectBox(String label, Commune value, ValueChanged<Commune?> onChanged) {
    return DropdownButtonFormField<Commune>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(label == 'Départ' ? Icons.my_location : Icons.location_on),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: RegionKaolack.communes
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text('${c.name} - ${c.department}', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _PassengerCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PassengerCircleButton({required this.icon, required this.onTap});

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
            child: Icon(icon, color: const Color(0xFF111111)),
          ),
        ),
      );
}
