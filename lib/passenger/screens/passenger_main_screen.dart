import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/yobalema_api.dart';
import '../../core/constants/kaolack_boundary.dart';
import '../../core/constants/kaolack_places.dart';
import '../../core/constants/yobalema_theme.dart';
import '../../core/geo/geo.dart';
import '../../core/models/commune.dart';
import '../../core/models/price_quote.dart';
import '../../core/models/ride_model.dart';
import '../../core/models/route_result.dart';
import '../../core/services/pricing_engine.dart';
import '../../core/services/routing_service.dart';
import '../../core/utils/error_helper.dart';
import 'passenger_search_modal.dart';

class PassengerMainScreen extends StatefulWidget {
  final String phone;
  final YobalemaApi api;
  final Map<String, dynamic> user;
  final VoidCallback? onLogout;

  const PassengerMainScreen({
    super.key,
    required this.phone,
    required this.api,
    required this.user,
    this.onLogout,
  });

  @override
  State<PassengerMainScreen> createState() => _PassengerMainScreenState();
}

class _PassengerMainScreenState extends State<PassengerMainScreen>
    with TickerProviderStateMixin {
  final mapController = MapController();
  final routingService = RoutingService();
  final history = <RideModel>[];

  late final MapCameraTracker cameraTracker =
      MapCameraTracker(mapController: mapController);
  AnimationController? markerAnimController;
  GeoPosition? prevDriverGeoPosition;
  GeoPosition? targetDriverGeoPosition;
  GeoPosition? interpolatedDriverPosition;
  GeoPosition? currentPassengerGeoPosition;
  double? dynamicRemainingKm;
  int? dynamicEtaMinutes;

  late Commune from;
  late Commune to;
  String paymentMethod = 'CASH';

  bool shareTrip = false;
  bool searching = false;
  bool backendReady = false;
  bool isRoutingLoading = false;

  String? activeRideId;
  String? activeRideStatus;
  String? pickupPin;
  Map<String, dynamic>? activeDriverInfo;

  double distanceKm = 37.0;
  PriceQuote? quote;
  RouteResult? currentRoute;

  Timer? pollTimer;
  LatLng? liveDriverPosition;

  @override
  void initState() {
    super.initState();
    // Default initial preview: Kaolack Centre -> Ndoffane
    from = KaolackPlaces.allPlaces.firstWhere(
      (p) => p.name.contains('Kaolack Centre'),
      orElse: () => KaolackPlaces.allPlaces[0],
    );
    to = KaolackPlaces.allPlaces.firstWhere(
      (p) => p.name.contains('Ndoffane'),
      orElse: () => KaolackPlaces.allPlaces[18],
    );

    markerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    markerAnimController!.addListener(() {
      if (prevDriverGeoPosition != null && targetDriverGeoPosition != null) {
        setState(() {
          interpolatedDriverPosition = PositionInterpolator.interpolatePosition(
            prevDriverGeoPosition!,
            targetDriverGeoPosition!,
            markerAnimController!.value,
          );
          liveDriverPosition = interpolatedDriverPosition?.toLatLng();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recalculateRouteAndPrice();
      _initRealtime();
    });
  }
  @override
  void dispose() {
    markerAnimController?.dispose();
    pollTimer?.cancel();
    widget.api.dispose();
    super.dispose();
  }

  Future<void> _initRealtime() async {
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
              date: DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _recalculateRouteAndPrice() async {
    if (!KaolackBoundary.isInside(from.point) ||
        !KaolackBoundary.isInside(to.point)) {
      if (mounted) {
        setState(() {
          currentRoute = null;
          quote = null;
          isRoutingLoading = false;
        });
        _toast(
          'Yobalema est disponible uniquement dans la région de Kaolack.',
          bg: Colors.orange.shade900,
        );
      }
      return;
    }

    if (mounted) setState(() => isRoutingLoading = true);

    final route = await routingService.getRoute(from.point, to.point);
    if (!mounted) return;

    distanceKm = route.distanceKm;
    currentRoute = route;
    isRoutingLoading = false;

    final isNight = Pricing.isNightTime();
    final traffic = Pricing.estimatedTrafficLevel();

    final localQuote = Pricing.calculate(
      km: distanceKm,
      fromZone: from.zone,
      toZone: to.zone,
      trafficLevel: traffic,
      night: isNight,
      serviceType: 'MOTO',
    );

    setState(() => quote = localQuote);
    _fitRouteBounds(route.points);

    try {
      final data = await widget.api.quote(
        fromName: from.name,
        toName: to.name,
        fromLat: from.point.latitude,
        fromLng: from.point.longitude,
        toLat: to.point.latitude,
        toLng: to.point.longitude,
        fromZone: from.zoneString,
        toZone: to.zoneString,
        trafficLevel: traffic,
        night: isNight,
        distanceKm: distanceKm,
      );
      if (!mounted) return;
      final totalValue = data['total'];
      final driverValue = data['driver'];
      final platformValue = data['platform'];
      if (totalValue is num && driverValue is num && platformValue is num) {
        final factorValue = data['trafficFactor'];
        final factor = factorValue is num ? factorValue.toDouble() : 1.0;
        setState(() {
          quote = PriceQuote(
            total: totalValue.round(),
            driver: driverValue.round(),
            platform: platformValue.round(),
            trafficFactor: factor,
            explanation:
                data['explanation']?.toString() ?? localQuote.explanation,
            serviceType: 'MOTO',
          );
        });
      } else {
        debugPrint('Réponse de devis distante incomplète : conservation du devis local.');
      }
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
              top: 90,
              bottom: 340,
              left: 40,
              right: 40,
            ),
          ),
        );
      } catch (_) {}
    });
  }
  Future<void> requestRide() async {
    if (!KaolackBoundary.isInside(from.point) ||
        !KaolackBoundary.isInside(to.point)) {
      _toast(
        'Impossible de commander : Yobalema est disponible uniquement dans la région de Kaolack.',
        bg: YobalemaTheme.red,
      );
      return;
    }

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
        fromZone: from.zoneString,
        toZone: to.zoneString,
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
        history.insert(
          0,
          RideModel(
            id: activeRideId ?? '',
            from: from.name,
            to: to.name,
            price: total,
            status: 'REQUESTED',
            paymentMethod: paymentMethod,
            date: DateTime.now(),
            distanceKm: distanceKm,
          ),
        );
      });

      _toast('Recherche d\'un chauffeur moto à proximité...',
          bg: YobalemaTheme.ink);
    } catch (e) {
      if (mounted) {
        setState(() => searching = false);
        _toast(cleanErrorMessage(e), bg: YobalemaTheme.red);
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
          _onRideStatus({'rideId': rideId, 'status': st, 'ride': r});
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
      if (mounted) _toast('Code PIN : ${cleanErrorMessage(e)}');
    }
  }

  void _onRideAccepted(Map<String, dynamic> data) {
    if (!mounted) return;
    if (activeRideId != data['rideId']?.toString()) return;
    setState(() {
      activeRideStatus = 'ACCEPTED';
      activeDriverInfo = Map<String, dynamic>.from(data['driver'] ?? {});
    });
    _generatePickupPin();
    _toast('Un conducteur moto a accepté votre course !',
        bg: YobalemaTheme.green);
  }

  void _onRideStatus(Map<String, dynamic> data) {
    if (!mounted) return;
    if (activeRideId != data['rideId']?.toString()) return;
    final st = data['status']?.toString();
    setState(() => activeRideStatus = st);

    if (st == 'DRIVER_ARRIVING') {
      _toast('Votre conducteur moto arrive au point de rendez-vous !',
          bg: YobalemaTheme.primary);
    } else if (st == 'IN_PROGRESS') {
      _toast('Course moto démarrée ! Bonne route.', bg: YobalemaTheme.green);
    } else if (st == 'COMPLETED') {
      pollTimer?.cancel();
      _showRideCompletedDialog();
    } else if (st == 'CANCELLED') {
      pollTimer?.cancel();
      _toast('La course a été annulée.');
      setState(() {
        activeRideId = null;
        activeRideStatus = null;
        pickupPin = null;
      });
    }
  }
  void _onRideLocation(Map<String, dynamic> data) {
    if (!mounted) return;
    final newGeo = GeoPosition.fromJson(data);
    if (!newGeo.isValid) return;

    setState(() {
      if (interpolatedDriverPosition == null) {
        prevDriverGeoPosition = newGeo;
        targetDriverGeoPosition = newGeo;
        interpolatedDriverPosition = newGeo;
        liveDriverPosition = newGeo.toLatLng();
      } else {
        prevDriverGeoPosition =
            interpolatedDriverPosition ?? targetDriverGeoPosition;
        targetDriverGeoPosition = newGeo;
        markerAnimController?.forward(from: 0.0);
      }

      final targetPoint =
          (activeRideStatus == 'IN_PROGRESS') ? to.point : from.point;
      final distM = newGeo.distanceToLatLng(targetPoint);
      dynamicRemainingKm = double.parse((distM / 1000.0).toStringAsFixed(1));
      final speedMps = newGeo.speed > 1.0 ? newGeo.speed : (35.0 / 3.6);
      dynamicEtaMinutes = (distM / speedMps / 60.0).round().clamp(1, 999);
    });

    cameraTracker.onPositionUpdate(newGeo.toLatLng());
  }

  Future<void> locateMe() async {
    try {
      final pos = await LocationService().getCurrentPosition(
        mode: LocationTrackingMode.searching,
      );
      if (!mounted) return;
      final point = pos.toLatLng();

      if (!KaolackBoundary.isInside(point)) {
        _toast(
          'Votre position GPS (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}) est en dehors de la région de Kaolack.',
          bg: Colors.orange.shade800,
        );
        return;
      }

      setState(() {
        currentPassengerGeoPosition = pos;
        from = Commune(
          'Ma position actuelle GPS',
          'Kaolack',
          point,
          ZoneType.city,
          'Kaolack',
          'Coordonnées GPS directes (Précision: ${pos.accuracy.toStringAsFixed(0)}m)',
        );
      });
      _recalculateRouteAndPrice();
      cameraTracker.recenter(point, zoom: 14.5);
      _toast(
        'Point de départ calé sur votre GPS réel (±${pos.accuracy.toStringAsFixed(0)}m).',
        bg: YobalemaTheme.green,
      );
    } catch (e) {
      if (mounted) _toast('GPS : ${cleanErrorMessage(e)}', bg: YobalemaTheme.red);
    }
  }

  void _onMapTapped(TapPosition tapPos, LatLng point) {
    if (!KaolackBoundary.isInside(point)) {
      _toast(
        'Ce point est en dehors de la région administrative de Kaolack.',
        bg: Colors.orange.shade800,
      );
      return;
    }

    setState(() {
      to = Commune(
        'Point sélectionné sur carte',
        'Kaolack',
        point,
        ZoneType.city,
        'Kaolack',
        'Sélection directe sur carte (${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)})',
      );
    });
    _recalculateRouteAndPrice();
    _toast('Destination mise à jour sur le point sélectionné.',
        bg: YobalemaTheme.ink);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: YobalemaTheme.green, size: 28),
              SizedBox(width: 10),
              Text('Trajet Moto terminé !',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Votre course est arrivée à destination. Merci d\'avoir voyagé avec Yobalema !',
                style: TextStyle(fontSize: 13, color: YobalemaTheme.textMuted),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('Notez votre conducteur :',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    icon: Icon(
                      star <= rating ? Icons.star : Icons.star_border,
                      color: YobalemaTheme.primary,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => rating = star),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  hintText: 'Commentaire facultatif (ex: Chauffeur très prudent)',
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (activeRideId != null) {
                  try {
                    await widget.api.rateRide(
                      activeRideId!,
                      rating,
                      comment: commentCtrl.text.trim().isNotEmpty
                          ? commentCtrl.text.trim()
                          : null,
                    );
                  } catch (_) {}
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                setState(() {
                  activeRideId = null;
                  activeRideStatus = null;
                  pickupPin = null;
                  activeDriverInfo = null;
                  liveDriverPosition = null;
                  interpolatedDriverPosition = null;
                });
                _loadHistory();
                _toast('Merci pour votre avis !', bg: YobalemaTheme.green);
              },
              child: const Text('Envoyer mon avis'),
            ),
          ],
        ),
      ),
    );
  }
  void _callSupport() => _launchUrl('tel:+221339410000');

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Impossible d\'ouvrir le lien : $url');
    }
  }

  void _toast(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg ?? YobalemaTheme.ink,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatStatus(String? st) {
    switch (st) {
      case 'REQUESTED':
        return 'Recherche d\'un chauffeur moto...';
      case 'ACCEPTED':
        return 'Conducteur en route pour vous chercher';
      case 'DRIVER_ARRIVING':
        return 'Le conducteur est au point de rendez-vous';
      case 'IN_PROGRESS':
        return 'Course en cours vers votre destination';
      case 'COMPLETED':
        return 'Course terminée';
      case 'CANCELLED':
        return 'Course annulée';
      default:
        return 'Course active';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. OPENSTREETMAP INTERACTIVE MAP WITH ACCURACY HALO & ROUTE POLYLINE
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: from.point,
              initialZoom: 12.0,
              onTap: _onMapTapped,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  setState(() => cameraTracker.onUserManualPan());
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yobalema.app',
              ),
              // Cercle de précision GPS réel (Accuracy Radius)
              if (currentPassengerGeoPosition != null &&
                  currentPassengerGeoPosition!.accuracy > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: currentPassengerGeoPosition!.toLatLng(),
                      radius: currentPassengerGeoPosition!.accuracy,
                      useRadiusInMeter: true,
                      color: YobalemaTheme.green.withValues(alpha: 0.12),
                      borderColor: YobalemaTheme.green.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              // Tracé routier réel OSRM
              if (currentRoute != null && currentRoute!.points.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: currentRoute!.points,
                      strokeWidth: 5.0,
                      color: YobalemaTheme.ink,
                    ),
                  ],
                ),
              // Markers: Conducteur Moto, Départ, Destination
              MarkerLayer(markers: [
                if (interpolatedDriverPosition != null ||
                    liveDriverPosition != null)
                  Marker(
                    point: interpolatedDriverPosition?.toLatLng() ??
                        liveDriverPosition!,
                    width: 54,
                    height: 54,
                    child: VehicleMarkerWidget(
                      headingDegrees:
                          interpolatedDriverPosition?.heading ?? 0.0,
                      primaryColor: YobalemaTheme.ink,
                      icon: Icons.two_wheeler,
                    ),
                  ),
                Marker(
                  point: from.point,
                  width: 46,
                  height: 46,
                  child: const Icon(Icons.radio_button_checked,
                      size: 34, color: YobalemaTheme.green),
                ),
                Marker(
                  point: to.point,
                  width: 46,
                  height: 46,
                  child: const Icon(Icons.location_on,
                      size: 40, color: YobalemaTheme.red),
                ),
              ]),
            ],
          ),

          // 2. TOP FLOATING APP BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _circleAction(
                    icon: Icons.history,
                    onTap: _showHistorySheet,
                  ),
                  const SizedBox(width: 8),
                  if (widget.onLogout != null) ...[
                    _circleAction(
                      icon: Icons.logout,
                      onTap: widget.onLogout!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  _circleAction(
                    icon: Icons.my_location,
                    onTap: locateMe,
                  ),
                  const SizedBox(width: 8),
                  _circleAction(
                    icon: Icons.support_agent,
                    onTap: _callSupport,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: backendReady
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: YobalemaTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 8,
                            color: backendReady
                                ? YobalemaTheme.green
                                : Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          backendReady ? 'En direct' : 'Local',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: backendReady
                                ? YobalemaTheme.green
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. SCIENTIFIC GPS DEBUG TELEMETRY OVERLAY
          GpsDebugOverlay(
            rawPosition: LocationService().lastRawPosition,
            filteredPosition: LocationService().lastFilteredPosition,
            matchedPosition: currentPassengerGeoPosition,
            interpolatedPosition: interpolatedDriverPosition,
            title: 'Diagnostic GPS Passager',
          ),
          // 4. FLOATING RECENTER BUTTON
          if (!cameraTracker.isFollowing &&
              (liveDriverPosition != null || activeRideId != null))
            Positioned(
              right: 16,
              bottom: 310,
              child: FloatingActionButton.extended(
                heroTag: 'passenger_recenter_btn',
                onPressed: () {
                  final target = liveDriverPosition ?? from.point;
                  setState(() => cameraTracker.recenter(target, zoom: 15.0));
                },
                backgroundColor: YobalemaTheme.ink,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.my_location, size: 20),
                label: const Text('Recentrer',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),

          // 5. ACTIVE RIDE STATUS CARD
          if (activeRideId != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: YobalemaTheme.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: YobalemaTheme.primary,
                          child: Icon(Icons.two_wheeler,
                              color: YobalemaTheme.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatStatus(activeRideStatus),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              Text(
                                '${from.shortName} ➔ ${to.shortName}',
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
                                      'Arrivée dans ~$dynamicEtaMinutes min ($dynamicRemainingKm km)',
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
                    if (activeRideStatus == 'ACCEPTED' ||
                        activeRideStatus == 'DRIVER_ARRIVING') ...[
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: YobalemaTheme.primary, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Donnez ce code PIN au conducteur moto à la montée :',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: YobalemaTheme.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pickupPin ?? '••••••',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: YobalemaTheme.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 6. BOTTOM PERSISTENT SLIDING SHEET
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: YobalemaTheme.bottomSheetShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Address Selector
                  _buildAddressPill(
                    icon: Icons.radio_button_checked,
                    iconColor: YobalemaTheme.green,
                    label: 'Départ',
                    value: from.name,
                    onTap: () async {
                      final chosen = await PassengerSearchModal.show(
                        context,
                        title: 'Choisir le point de départ',
                        current: from,
                      );
                      if (chosen != null) {
                        setState(() => from = chosen);
                        _recalculateRouteAndPrice();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildAddressPill(
                    icon: Icons.location_on,
                    iconColor: YobalemaTheme.red,
                    label: 'Destination',
                    value: to.name,
                    onTap: () async {
                      final chosen = await PassengerSearchModal.show(
                        context,
                        title: 'Choisir la destination',
                        current: to,
                      );
                      if (chosen != null) {
                        setState(() => to = chosen);
                        _recalculateRouteAndPrice();
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  // Route Details: Road Distance & Real OSRM indicator
                  if (currentRoute != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: YobalemaTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.alt_route,
                                    size: 14, color: YobalemaTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  currentRoute!.formattedDistance,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: YobalemaTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 14, color: YobalemaTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  currentRoute!.formattedDuration,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            currentRoute!.isFallback
                                ? 'Route locale (hors-ligne)'
                                : 'Itinéraire routier réel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: currentRoute!.isFallback
                                  ? Colors.orange.shade800
                                  : YobalemaTheme.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Pricing & Payment Method Row
                  Row(
                    children: [
                      // Estimated Fare
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: YobalemaTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Prix estimé',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: YobalemaTheme.textMuted)),
                              const SizedBox(height: 2),
                              if (isRoutingLoading)
                                const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: YobalemaTheme.ink),
                                )
                              else
                                Text(
                                  '${quote?.total ?? 0} FCFA',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: YobalemaTheme.ink,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Payment Selector (Cash, Wave, OM)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: YobalemaTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: paymentMethod,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 18),
                              items: const [
                                DropdownMenuItem(
                                  value: 'CASH',
                                  child: Text('Espèces',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ),
                                DropdownMenuItem(
                                  value: 'WAVE',
                                  child: Text('Wave',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ),
                                DropdownMenuItem(
                                  value: 'ORANGE_MONEY',
                                  child: Text('Orange Money',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => paymentMethod = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Order CTA Button
                  ElevatedButton(
                    onPressed: (searching || activeRideId != null)
                        ? null
                        : requestRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: YobalemaTheme.primary,
                      foregroundColor: YobalemaTheme.ink,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: searching
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: YobalemaTheme.ink,
                            ),
                          )
                        : const Text(
                            'COMMANDER MAINTENANT',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: YobalemaTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: YobalemaTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: YobalemaTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _circleAction({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: YobalemaTheme.ink),
        ),
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes courses récentes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: history.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucune course effectuée.',
                        style: TextStyle(color: YobalemaTheme.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (_, i) {
                        final r = history[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: YobalemaTheme.surface,
                            child: Icon(Icons.two_wheeler,
                                color: YobalemaTheme.ink),
                          ),
                          title: Text('${r.from} ➔ ${r.to}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${r.price} FCFA • ${r.status}',
                            style: const TextStyle(
                                fontSize: 12, color: YobalemaTheme.textMuted),
                          ),
                          trailing: const Icon(Icons.check_circle,
                              color: YobalemaTheme.green, size: 20),
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
