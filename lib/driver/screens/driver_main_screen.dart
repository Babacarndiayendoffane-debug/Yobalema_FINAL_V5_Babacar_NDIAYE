
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/yobalema_api.dart';
import '../../core/constants/yobalema_theme.dart';
import '../../core/geo/geo.dart';
import '../../core/models/route_result.dart';
import '../../core/services/routing_service.dart';
import '../../core/utils/error_helper.dart';

class DriverMainScreen extends StatefulWidget {
  final String phone;
  final YobalemaApi api;
  final Map<String, dynamic> user;
  final VoidCallback? onLogout;

  const DriverMainScreen({
    super.key,
    required this.phone,
    required this.api,
    required this.user,
    this.onLogout,
  });

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  final mapController = MapController();
  final routingService = RoutingService();

  late final DriverTrackingService _trackingService =
      DriverTrackingService(api: widget.api);
  late final MapCameraTracker cameraTracker =
      MapCameraTracker(mapController: mapController);
  double driverHeading = 0.0;
  double driverSpeedKmh = 0.0;
  GeoPosition? currentDriverGeoPosition;
  double? dynamicRemainingKm;
  int? dynamicEtaMinutes;
  StreamSubscription<GeoPosition>? _locationSubscription;

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
  LatLng driverPosition =
      const LatLng(14.1510, -16.0726); // Centre Kaolack default

  @override
  void initState() {
    super.initState();
    _trackingService.initialize(driverId: widget.user['id']?.toString() ?? '');
    _locationSubscription = LocationService().positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        currentDriverGeoPosition = pos;
        driverPosition = pos.toLatLng();
        driverHeading = pos.heading;
        driverSpeedKmh = pos.speedKmh;

        if (activeRide != null) {
          final targetLat = (activeRideStatus == 'IN_PROGRESS')
              ? ((activeRide!['toLat'] as num?)?.toDouble() ??
                  driverPosition.latitude)
              : ((activeRide!['fromLat'] as num?)?.toDouble() ??
                  driverPosition.latitude);
          final targetLng = (activeRideStatus == 'IN_PROGRESS')
              ? ((activeRide!['toLng'] as num?)?.toDouble() ??
                  driverPosition.longitude)
              : ((activeRide!['fromLng'] as num?)?.toDouble() ??
                  driverPosition.longitude);

          final distM = pos.distanceToLatLng(LatLng(targetLat, targetLng));
          dynamicRemainingKm =
              double.parse((distM / 1000.0).toStringAsFixed(1));
          final speedMps = pos.speed > 1.0 ? pos.speed : (35.0 / 3.6);
          dynamicEtaMinutes = (distM / speedMps / 60.0).round().clamp(1, 999);
        }
      });
      cameraTracker.onPositionUpdate(pos.toLatLng());
    });
    _initDriverSession();
  }
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _trackingService.dispose();
    gpsTimer?.cancel();
    pollTimer?.cancel();
    widget.api.dispose();
    super.dispose();
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
          _trackingService.startDriverTracking(
              isOnline: true, activeRideId: activeRideId);
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
    if (!online || activeRideId != null) return;
    try {
      final rides = await widget.api.getAvailableRides();
      if (!mounted) return;
      setState(() => availableRides = rides);
    } catch (_) {}
  }

  Future<void> _toggleOnline(bool val) async {
    setState(() => online = val);
    try {
      await widget.api.setDriverStatus(val ? 'ONLINE' : 'OFFLINE');
      if (val) {
        _trackingService.startDriverTracking(
            isOnline: true, activeRideId: activeRideId);
        _loadAvailableRides();
        _toast('Vous êtes EN LIGNE. Prêt à recevoir des courses !',
            bg: YobalemaTheme.green);
      } else {
        _trackingService.stopTracking();
        setState(() => availableRides = []);
        _toast('Vous êtes HORS LIGNE.');
      }
    } catch (e) {
      if (mounted) {
        _toast('Erreur statut : ${cleanErrorMessage(e)}',
            bg: YobalemaTheme.red);
      }
    }
  }

  void _onRideNew(Map<String, dynamic> data) => _showIncomingRideDialog(data);
  void _onRideOffer(Map<String, dynamic> data) => _showIncomingRideDialog(data);

  void _onRideStatus(Map<String, dynamic> data) {
    if (!mounted) return;
    if (activeRideId != data['rideId']?.toString()) return;
    final st = data['status']?.toString();
    setState(() => activeRideStatus = st);
    if (st == 'CANCELLED') {
      _toast('La course a été annulée par le passager.',
          bg: YobalemaTheme.red);
      _trackingService.setActiveRide(null);
      setState(() {
        activeRide = null;
        activeRideId = null;
        activeRideStatus = null;
        activeRoute = null;
      });
      _loadAvailableRides();
    }
  }
  void _showIncomingRideDialog(Map<String, dynamic> data) {
    if (!mounted || !online || activeRideId != null) return;

    final ride = Map<String, dynamic>.from(data['ride'] ?? data);
    final rideId = ride['id']?.toString() ?? '';
    final fromName = ride['fromName']?.toString() ?? 'Départ inconnu';
    final toName = ride['toName']?.toString() ?? 'Destination inconnue';
    final price = (ride['priceFcfa'] as num?)?.toInt() ?? 0;
    final driverShare = (price * 0.90).round();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFF9C4), shape: BoxShape.circle),
                  child: const Icon(Icons.notification_important,
                      color: YobalemaTheme.ink, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nouvelle course disponible !',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: YobalemaTheme.surface,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radio_button_checked,
                          color: YobalemaTheme.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(fromName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: YobalemaTheme.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(toName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gain Chauffeur (90%) :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$driverShare FCFA',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: YobalemaTheme.green),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Ignorer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _acceptRide(rideId, ride);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: YobalemaTheme.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Accepter la course',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRide(String rideId, Map<String, dynamic> ride) async {
    try {
      await widget.api.acceptRide(rideId);
      widget.api.joinRide(rideId);
      _trackingService.setActiveRide(rideId);

      final fromLat = (ride['fromLat'] as num?)?.toDouble() ??
          driverPosition.latitude;
      final fromLng = (ride['fromLng'] as num?)?.toDouble() ??
          driverPosition.longitude;
      final toLat =
          (ride['toLat'] as num?)?.toDouble() ?? driverPosition.latitude;
      final toLng =
          (ride['toLng'] as num?)?.toDouble() ?? driverPosition.longitude;

      final route = await routingService.getRoute(
          LatLng(fromLat, fromLng), LatLng(toLat, toLng));

      setState(() {
        activeRideId = rideId;
        activeRide = ride;
        activeRideStatus = 'ACCEPTED';
        activeRoute = route;
        availableRides = [];
      });

      _fitBounds(route.points);
      _toast('Course acceptée ! Rendez-vous au point de départ.',
          bg: YobalemaTheme.green);
    } catch (e) {
      _toast('Impossible d\'accepter : ${cleanErrorMessage(e)}',
          bg: YobalemaTheme.red);
      _loadAvailableRides();
    }
  }
  Future<void> _notifyDriverArrived() async {
    if (activeRideId == null) return;
    try {
      await widget.api.rideStatus(activeRideId!, 'DRIVER_ARRIVING');
      setState(() => activeRideStatus = 'DRIVER_ARRIVING');
      _toast('Passager notifié de votre arrivée !',
          bg: YobalemaTheme.primary);
      _showPinVerificationModal();
    } catch (e) {
      _toast('Erreur statut : ${cleanErrorMessage(e)}');
    }
  }

  void _showPinVerificationModal() {
    final pinCtrl = TextEditingController();
    bool verifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: minAxisSize,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Vérification Code PIN Passager',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Demandez le code PIN à 6 chiffres au passager à sa montée à bord.',
                style:
                    TextStyle(color: YobalemaTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: '000000'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: verifying
                    ? null
                    : () async {
                        final code = pinCtrl.text.trim();
                        if (code.length != 6) {
                          _toast('Veuillez saisir un code à 6 chiffres.');
                          return;
                        }
                        setMState(() => verifying = true);
                        try {
                          await widget.api.verifyPickup(activeRideId!, code);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() => activeRideStatus = 'IN_PROGRESS');
                          _toast(
                              'Code validé ! Course en cours vers la destination.',
                              bg: YobalemaTheme.green);
                        } catch (e) {
                          setMState(() => verifying = false);
                          _toast('Code PIN invalide (${cleanErrorMessage(e)})',
                              bg: YobalemaTheme.red);
                        }
                      },
                child: verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Valider le départ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeRide() async {
    if (activeRideId == null) return;
    try {
      await widget.api.rideStatus(activeRideId!, 'COMPLETED');
      _toast('Course terminée avec succès ! Gain ajouté au portefeuille.',
          bg: YobalemaTheme.green);
      _trackingService.setActiveRide(null);
      setState(() {
        activeRide = null;
        activeRideId = null;
        activeRideStatus = null;
        activeRoute = null;
      });
      _loadWallet();
      _loadAvailableRides();
    } catch (e) {
      _toast('Erreur finalisation : ${cleanErrorMessage(e)}',
          bg: YobalemaTheme.red);
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final bounds = LatLngBounds.fromPoints(points);
        mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)));
      } catch (_) {}
    });
  }

  void _toast(String s, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(s),
          backgroundColor: bg ?? YobalemaTheme.ink,
          duration: const Duration(seconds: 3)),
    );
  }

  static const minAxisSize = MainAxisSize.min;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. FULLSCREEN DRIVER MAP WITH ACCURACY HALO
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: driverPosition,
              initialZoom: 13.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  setState(() => cameraTracker.onUserManualPan());
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yobalema.driver',
              ),

              // Cercle de précision GPS réel (Accuracy Radius)
              if (currentDriverGeoPosition != null &&
                  currentDriverGeoPosition!.accuracy > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: driverPosition,
                      radius: currentDriverGeoPosition!.accuracy,
                      useRadiusInMeter: true,
                      color: (online ? YobalemaTheme.green : Colors.grey)
                          .withValues(alpha: 0.12),
                      borderColor: (online ? YobalemaTheme.green : Colors.grey)
                          .withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Polyline de la course
              if (activeRoute != null && activeRoute!.points.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: activeRoute!.points,
                    strokeWidth: 5.5,
                    color: YobalemaTheme.ink,
                    borderColor: YobalemaTheme.primary,
                    borderStrokeWidth: 2.0,
                  ),
                ]),

              // Marqueurs GPS Chauffeur et points de course
              MarkerLayer(markers: [
                Marker(
                  point: driverPosition,
                  width: 52,
                  height: 52,
                  child: VehicleMarkerWidget(
                    headingDegrees: driverHeading,
                    primaryColor:
                        online ? YobalemaTheme.green : Colors.grey.shade700,
                    icon: Icons.two_wheeler,
                  ),
                ),
                if (activeRide != null) ...[
                  Marker(
                    point: LatLng(
                      (activeRide!['fromLat'] as num?)?.toDouble() ??
                          driverPosition.latitude,
                      (activeRide!['fromLng'] as num?)?.toDouble() ??
                          driverPosition.longitude,
                    ),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.radio_button_checked,
                        size: 34, color: YobalemaTheme.green),
                  ),
                  Marker(
                    point: LatLng(
                      (activeRide!['toLat'] as num?)?.toDouble() ??
                          driverPosition.latitude,
                      (activeRide!['toLng'] as num?)?.toDouble() ??
                          driverPosition.longitude,
                    ),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on,
                        size: 38, color: YobalemaTheme.red),
                  ),
                ],
              ]),
            ],
          ),

          // 2. TOP DRIVER BAR (ONLINE TOGGLE + WALLET BADGE)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Online/Offline switch
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: YobalemaTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 10,
                            color:
                                online ? YobalemaTheme.green : Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          online ? 'EN LIGNE' : 'HORS LIGNE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: online
                                ? YobalemaTheme.green
                                : Colors.grey.shade700,
                          ),
                        ),
                        Switch(
                          value: online,
                          activeTrackColor: YobalemaTheme.green,
                          onChanged: _toggleOnline,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Wallet Badge
                  InkWell(
                    onTap: _showWalletSheet,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: YobalemaTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet,
                              size: 18, color: YobalemaTheme.ink),
                          const SizedBox(width: 6),
                          Text(
                            '$walletBalance F',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: YobalemaTheme.ink),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (widget.onLogout != null) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onLogout!,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.logout,
                              size: 18, color: YobalemaTheme.ink),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. SCIENTIFIC GPS DEBUG TELEMETRY OVERLAY
          GpsDebugOverlay(
            rawPosition: LocationService().lastRawPosition,
            filteredPosition: LocationService().lastFilteredPosition,
            matchedPosition: currentDriverGeoPosition,
            title: 'Diagnostic GPS Chauffeur',
          ),

          // 4. FLOATING RECENTER BUTTON
          if (!cameraTracker.isFollowing)
            Positioned(
              right: 16,
              bottom: 120,
              child: FloatingActionButton.extended(
                heroTag: 'driver_recenter_btn',
                onPressed: () {
                  setState(
                      () => cameraTracker.recenter(driverPosition, zoom: 15.0));
                },
                backgroundColor: YobalemaTheme.ink,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.my_location, size: 20),
                label: const Text('Recentrer',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),

          // 5. AVAILABLE RIDES CAROUSEL (IF NO ACTIVE RIDE & ONLINE)
          if (online && activeRideId == null && availableRides.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: YobalemaTheme.bottomSheetShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.radar, color: YobalemaTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${availableRides.length} course(s) en attente',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...availableRides.take(2).map((r) {
                      final price = (r['priceFcfa'] as num?)?.toInt() ?? 0;
                      final driverEarn = (price * 0.90).round();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${r['fromName']} ➔ ${r['toName']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(
                            'Gain net : $driverEarn FCFA (Commission 10% déduite)'),
                        trailing: ElevatedButton(
                          onPressed: () =>
                              _acceptRide(r['id']?.toString() ?? '', r),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: YobalemaTheme.green,
                            minimumSize: const Size(90, 40),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Prendre',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // 6. ACTIVE RIDE BOTTOM CONTROLLER
          if (activeRideId != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: YobalemaTheme.bottomSheetShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: YobalemaTheme.primary,
                          child:
                              Icon(Icons.navigation, color: YobalemaTheme.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeRideStatus == 'ACCEPTED'
                                    ? 'En route vers le passager'
                                    : activeRideStatus == 'DRIVER_ARRIVING'
                                        ? 'Au point de départ'
                                        : 'Course en cours',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              Text(
                                '${activeRide?['fromName']} ➔ ${activeRide?['toName']}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: YobalemaTheme.textMuted),
                              ),
                              if (dynamicRemainingKm != null &&
                                  dynamicEtaMinutes != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 14, color: YobalemaTheme.ink),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Arrivée estimée : ~$dynamicEtaMinutes min ($dynamicRemainingKm km)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: YobalemaTheme.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (activeRideStatus == 'ACCEPTED')
                      ElevatedButton.icon(
                        onPressed: _notifyDriverArrived,
                        icon: const Icon(Icons.place),
                        label: const Text('Je suis arrivé au départ'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: YobalemaTheme.primary,
                            foregroundColor: YobalemaTheme.ink),
                      )
                    else if (activeRideStatus == 'DRIVER_ARRIVING')
                      ElevatedButton.icon(
                        onPressed: _showPinVerificationModal,
                        icon: const Icon(Icons.pin),
                        label: const Text('Saisir le code PIN du passager'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: YobalemaTheme.ink),
                      )
                    else if (activeRideStatus == 'IN_PROGRESS')
                      ElevatedButton.icon(
                        onPressed: _completeRide,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Terminer la course'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: YobalemaTheme.green),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showWalletSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Portefeuille Chauffeur',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: YobalemaTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                children: [
                  const Text('Solde disponible',
                      style: TextStyle(
                          color: YobalemaTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    '$walletBalance FCFA',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: YobalemaTheme.green),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Commission Yobalema fixée à 10% sur chaque course.',
                      style: TextStyle(
                          fontSize: 11, color: YobalemaTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Dernières transactions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: walletEntries.isEmpty
                  ? const Center(child: Text('Aucune transaction récente.'))
                  : ListView.builder(
                      itemCount: walletEntries.length,
                      itemBuilder: (_, i) {
                        final e = walletEntries[i];
                        return ListTile(
                          leading: const Icon(Icons.arrow_downward,
                              color: YobalemaTheme.green),
                          title: Text('${e['amountFcfa']} FCFA',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              e['description']?.toString() ?? 'Course effectuée'),
                          trailing: Text(
                              e['createdAt']?.toString().substring(0, 10) ??
                                  ''),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
