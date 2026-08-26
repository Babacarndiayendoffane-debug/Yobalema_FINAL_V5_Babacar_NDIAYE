import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../api.dart';
import '../../main.dart';
import '../auth/auth_home.dart';

class DriverScreen extends StatefulWidget {
  final String phone;
  final YobalemaApi api;
  final Map<String, dynamic> user;

  const DriverScreen({
    super.key,
    required this.phone,
    required this.api,
    required this.user,
  });

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final mapController = MapController();
  final routingService = RoutingService();

  bool online = false;
  bool backendReady = false;
  bool loadingRides = false;

  int walletBalance = 0;
  List<dynamic> walletEntries = [];
  List<dynamic> availableRides = [];

  Map<String, dynamic>? activeRide;
  String? activeRideId;
  String? activeRideStatus;
  RouteResult? activeRoute;

  Timer? gpsTimer;
  Timer? pollTimer;
  LatLng driverPosition = const LatLng(14.1510, -16.0726); // Kaolack centre default

  static const yellow = Color(0xFFFFCC00);
  static const ink = Color(0xFF111111);
  static const green = Color(0xFF159947);
  static const greyBg = Color(0xFFF7F7F7);

  @override
  void initState() {
    super.initState();
    _initDriverSession();
  }

  Future<void> _initDriverSession() async {
    final health = await widget.api.checkHealth();
    if (!mounted) return;
    setState(() => backendReady = health);

    widget.api.connectSocket(
      onRideNew: _onRideNew,
      onRideOffer: _onRideOffer,
      onRideStatus: _onRideStatus,
      userId: widget.user['id']?.toString(),
      role: 'DRIVER',
    );

    try {
      final me = await widget.api.getMe();
      if (!mounted) return;
      if (me['driver'] != null) {
        setState(() {
          online = me['driver']['status'] == 'ONLINE';
        });
        if (online) {
          _startGpsBroadcast();
          _loadAvailableRides();
        }
      }
    } catch (_) {}

    _loadWallet();
    _startPeriodicPolling();
  }

  void _startPeriodicPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (online && activeRideId == null) {
        _loadAvailableRides();
      }
      if (activeRideId != null) {
        _checkActiveRideStatus();
      }
    });
  }

  Future<void> _checkActiveRideStatus() async {
    if (activeRideId == null) return;
    try {
      final r = await widget.api.getRide(activeRideId!);
      if (!mounted) return;
      final st = r['status']?.toString();
      if (st != null && st != activeRideStatus) {
        _onRideStatus({'rideId': activeRideId, 'status': st});
      }
    } catch (_) {}
  }

  Future<void> _loadWallet() async {
    try {
      final data = await widget.api.driverWallet();
      if (!mounted) return;
      setState(() {
        walletBalance = (data['balanceFcfa'] as num?)?.toInt() ?? 0;
        walletEntries = (data['entries'] as List<dynamic>?) ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadAvailableRides() async {
    if (!mounted || loadingRides) return;
    setState(() => loadingRides = true);
    try {
      final list = await widget.api.getAvailableRides();
      if (!mounted) return;
      setState(() {
        availableRides = list;
        loadingRides = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingRides = false);
    }
  }

  void _startGpsBroadcast() {
    gpsTimer?.cancel();
    gpsTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted || !online) {
        gpsTimer?.cancel();
        return;
      }
      try {
        final p = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        driverPosition = LatLng(p.latitude, p.longitude);
        await widget.api.updateDriverLocation(p.latitude, p.longitude);
        if (activeRideId != null) {
          widget.api.emitLocation(activeRideId!, p.latitude, p.longitude);
        }
        setState(() {});
      } catch (_) {}
    });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    try {
      await widget.api.setDriverStatus(value ? 'ONLINE' : 'OFFLINE');
      if (!mounted) return;
      setState(() => online = value);

      if (value) {
        _startGpsBroadcast();
        _loadAvailableRides();
        _toast('Vous êtes maintenant EN LIGNE.', bg: green);
      } else {
        gpsTimer?.cancel();
        gpsTimer = null;
        setState(() => availableRides.clear());
        _toast('Vous êtes HORS LIGNE.');
      }
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''), bg: Colors.red.shade700);
    }
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    final rideId = ride['id']?.toString();
    if (rideId == null) return;

    try {
      await widget.api.acceptRide(rideId);
      if (!mounted) return;

      widget.api.joinRide(rideId);
      setState(() {
        activeRide = Map<String, dynamic>.from(ride);
        activeRideId = rideId;
        activeRideStatus = 'ACCEPTED';
        availableRides.removeWhere((r) => r['id']?.toString() == rideId);
      });

      _toast('Course acceptée ! En route vers le départ.', bg: green);
      _fetchActiveRoute(ride);
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''), bg: Colors.red.shade700);
    }
  }

  Future<void> _fetchActiveRoute(Map<String, dynamic> ride) async {
    final fromLat = (ride['fromLat'] as num?)?.toDouble();
    final fromLng = (ride['fromLng'] as num?)?.toDouble();
    final toLat = (ride['toLat'] as num?)?.toDouble();
    final toLng = (ride['toLng'] as num?)?.toDouble();

    if (fromLat != null && fromLng != null && toLat != null && toLng != null) {
      final start = LatLng(fromLat, fromLng);
      final dest = LatLng(toLat, toLng);
      final route = await routingService.getRoute(start, dest);
      if (!mounted) return;
      setState(() => activeRoute = route);

      try {
        final bounds = LatLngBounds.fromPoints(route.points);
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40),
          ),
        );
      } catch (_) {}
    }
  }

  void _onRideNew(Map<String, dynamic> data) {
    if (!mounted || !online) return;
    _toast('Nouvelle course disponible : ${data['from']} -> ${data['to']}');
    _loadAvailableRides();
  }

  void _onRideOffer(Map<String, dynamic> data) {
    if (!mounted || !online || data['rideId'] == null) return;
    final price = (data['priceFcfa'] as num?)?.toInt() ?? 0;
    final driverGain = (price * 0.9).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: ink),
            SizedBox(width: 8),
            Text('Nouvelle course !', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['from'] ?? ''} -> ${data['to'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Prix total : ${_formatPrice(price)} FCFA'),
            Text('Votre gain (90%) : ${_formatPrice(driverGain)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: green)),
            Text('Paiement : ${data['paymentMethod'] ?? 'CASH'}'),
            if (data['distanceKm'] != null) Text('Distance : ${data['distanceKm']} km'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Refuser')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptRide(data);
            },
            child: const Text('Accepter la course'),
          ),
        ],
      ),
    );
  }

  void _onRideStatus(Map<String, dynamic> data) {
    if (!mounted) return;
    if (activeRideId != data['rideId']?.toString()) return;
    final st = data['status']?.toString();
    setState(() => activeRideStatus = st);

    if (st == 'CANCELLED') {
      setState(() {
        activeRide = null;
        activeRideId = null;
        activeRideStatus = null;
        activeRoute = null;
      });
      _toast('La course a été annulée par le passager.');
    }
  }

  void _showDriverVerifyPinDialog() {
    if (!mounted) return;
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisir le code PIN client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Demandez le code PIN à 6 chiffres affiché sur le téléphone du passager pour démarrer la course.'),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: '••••••', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final code = pinCtrl.text.trim();
              if (code.length != 6) {
                _toast('Le code PIN doit comporter 6 chiffres.');
                return;
              }
              Navigator.pop(ctx);
              try {
                await widget.api.verifyPickup(activeRideId!, code);
                if (!mounted) return;
                setState(() => activeRideStatus = 'IN_PROGRESS');
                _toast('Code PIN validé ! Course démarrée.', bg: green);
              } catch (e) {
                if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''), bg: Colors.red.shade700);
              }
            },
            child: const Text('Valider & Démarrer'),
          ),
        ],
      ),
    );
  }

  void _showWalletDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: green),
            SizedBox(width: 8),
            Text('Portefeuille Chauffeur'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('Solde Total Gains', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('${_formatPrice(walletBalance)} FCFA', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: green)),
                    const SizedBox(height: 4),
                    const Text('Commission garantie : 90 % chauffeur - 10 % Yobalema', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Historique des gains :', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              walletEntries.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aucune transaction enregistrée.'),
                    )
                  : SizedBox(
                      height: 180,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: walletEntries.length,
                        itemBuilder: (ctx, i) {
                          final e = walletEntries[i];
                          return ListTile(
                            dense: true,
                            title: Text(e['note']?.toString() ?? 'Course terminée'),
                            trailing: Text('+${e['amountFcfa']} F', style: const TextStyle(fontWeight: FontWeight.bold, color: green)),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showRideCompletedConfirmation(int gain) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Course terminée !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Félicitations pour cette course.'),
            const SizedBox(height: 8),
            Text('Gain crédité sur votre portefeuille : +${_formatPrice(gain)} FCFA (90%)', style: const TextStyle(fontWeight: FontWeight.bold, color: green)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(String s, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), backgroundColor: bg, duration: const Duration(seconds: 3)),
    );
  }

  String _formatPrice(int amount) {
    final s = amount.toString();
    if (s.length > 3) {
      return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
    }
    return s;
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

  void _switchToPassenger() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerScreen(
          phone: widget.phone,
          api: widget.api,
          user: widget.user,
        ),
      ),
    );
  }

  @override
  void dispose() {
    gpsTimer?.cancel();
    pollTimer?.cancel();
    widget.api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Espace Chauffeur', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        actions: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _showWalletDialog,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: green.withAlpha(76)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: green, size: 16),
                  const SizedBox(width: 4),
                  Text('${_formatPrice(walletBalance)} F', style: const TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Basculer en mode Passager',
            onPressed: _switchToPassenger,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statut En Ligne / Hors Ligne
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: online ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: online ? green : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online ? 'EN LIGNE — Prêt à recevoir des courses' : 'HORS LIGNE — En pause',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: online ? green : Colors.grey.shade700),
                      ),
                      Text(
                        online ? 'Position GPS diffusée en direct' : 'Activez pour recevoir les commandes',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: online,
                  activeThumbColor: green,
                  onChanged: _toggleOnlineStatus,
                ),
              ],
            ),
          ),

          // Contenu principal
          Expanded(
            child: activeRideId != null ? _buildActiveRideView() : _buildAvailableRidesView(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideView() {
    final ride = activeRide ?? {};
    final price = (ride['priceFcfa'] as num?)?.toInt() ?? 0;
    final driverGain = (price * 0.9).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler, color: ink, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Course en cours — ${_formatStatus(activeRideStatus)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 18, color: ink),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Départ : ${ride['fromName'] ?? ride['from'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Color(0xFFD32F2F)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Arrivée : ${ride['toName'] ?? ride['to'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: greyBg, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Montant client', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            Text('${_formatPrice(price)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Votre gain net (90%)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            Text('+${_formatPrice(driverGain)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: green, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Actions du chauffeur selon l'état
          if (activeRideStatus == 'ACCEPTED') ...[
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await widget.api.rideStatus(activeRideId!, 'DRIVER_ARRIVING');
                  if (!mounted) return;
                  setState(() => activeRideStatus = 'DRIVER_ARRIVING');
                  _toast('Statut mis à jour : Arrivé au départ', bg: yellow);
                } catch (e) {
                  if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''), bg: Colors.red.shade700);
                }
              },
              icon: const Icon(Icons.navigation),
              label: const Text('JE SUIS ARRIVÉ AU DÉPART'),
              style: ElevatedButton.styleFrom(backgroundColor: ink, minimumSize: const Size.fromHeight(52)),
            ),
          ],

          if (activeRideStatus == 'DRIVER_ARRIVING') ...[
            ElevatedButton.icon(
              onPressed: _showDriverVerifyPinDialog,
              icon: const Icon(Icons.pin),
              label: const Text('SAISIR LE CODE PIN CLIENT'),
              style: ElevatedButton.styleFrom(backgroundColor: green, minimumSize: const Size.fromHeight(52)),
            ),
          ],

          if (activeRideStatus == 'IN_PROGRESS') ...[
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await widget.api.rideStatus(activeRideId!, 'COMPLETED');
                  if (!mounted) return;
                  setState(() {
                    activeRide = null;
                    activeRideId = null;
                    activeRideStatus = null;
                    activeRoute = null;
                  });
                  _toast('Course terminée avec succès !', bg: green);
                  _loadWallet();
                  _showRideCompletedConfirmation(driverGain);
                } catch (e) {
                  if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''), bg: Colors.red.shade700);
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('TERMINER LA COURSE'),
              style: ElevatedButton.styleFrom(backgroundColor: green, minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableRidesView() {
    if (!online) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.power_settings_new, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Vous êtes hors ligne', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Basculez l\'interrupteur ci-dessus pour passer EN LIGNE et recevoir les demandes de courses.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _toggleOnlineStatus(true),
                icon: const Icon(Icons.flash_on),
                label: const Text('Passer En Ligne'),
                style: ElevatedButton.styleFrom(backgroundColor: green),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Courses disponibles en attente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAvailableRides,
                tooltip: 'Actualiser',
              ),
            ],
          ),
        ),
        Expanded(
          child: availableRides.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_outlined, size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Aucune course en attente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(
                          'Les nouvelles demandes de passagers dans la région de Kaolack apparaîtront ici automatiquement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: availableRides.length,
                  itemBuilder: (ctx, i) {
                    final r = availableRides[i];
                    final price = (r['priceFcfa'] as num?)?.toInt() ?? 0;
                    final driverGain = (price * 0.9).round();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.directions_car, color: ink, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${r['fromName'] ?? ''} ➔ ${r['toName'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Prix : ${_formatPrice(price)} FCFA', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                    Text('Votre gain (90%) : ${_formatPrice(driverGain)} FCFA', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: green)),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () => _acceptRide(r),
                                  style: ElevatedButton.styleFrom(backgroundColor: ink),
                                  child: const Text('Accepter'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatStatus(String? st) {
    switch (st) {
      case 'ACCEPTED':
        return 'En route vers le départ';
      case 'DRIVER_ARRIVING':
        return 'Arrivé au départ — En attente du code PIN';
      case 'IN_PROGRESS':
        return 'Trajet en cours vers la destination';
      case 'COMPLETED':
        return 'Terminée';
      default:
        return 'Assignée';
    }
  }
}
