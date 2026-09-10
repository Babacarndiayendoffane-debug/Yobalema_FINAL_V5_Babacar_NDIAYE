import 'package:flutter/material.dart';
import '../../constants/yobalema_theme.dart';
import '../models/geo_position.dart';

/// Interactive Floating Real-Time GPS Diagnostic Overlay.
class GpsDebugOverlay extends StatefulWidget {
  final GeoPosition? rawPosition;
  final GeoPosition? filteredPosition;
  final GeoPosition? matchedPosition;
  final GeoPosition? interpolatedPosition;
  final String title;

  const GpsDebugOverlay({
    super.key,
    this.rawPosition,
    this.filteredPosition,
    this.matchedPosition,
    this.interpolatedPosition,
    this.title = 'GPS Telemetry Diagnostics',
  });

  @override
  State<GpsDebugOverlay> createState() => _GpsDebugOverlayState();
}

class _GpsDebugOverlayState extends State<GpsDebugOverlay> {
  bool _isExpanded = false;

  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 15.0) return YobalemaTheme.green;
    if (accuracy <= 50.0) return Colors.orange.shade800;
    return YobalemaTheme.red;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.matchedPosition ??
        widget.filteredPosition ??
        widget.rawPosition;

    if (active == null) {
      return const SizedBox.shrink();
    }

    final accColor = _getAccuracyColor(active.accuracy);

    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 80, left: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accColor.withValues(alpha: 0.8), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed, size: 14, color: accColor),
                      const SizedBox(width: 6),
                      Text(
                        'GPS: ±${active.accuracy.toStringAsFixed(1)}m',
                        style: TextStyle(
                          color: accColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  if (_isExpanded) ...[
                    const Divider(color: Colors.white24, height: 12),
                    _buildRow('Source', active.provider),
                    _buildRow('Latitude', active.latitude.toStringAsFixed(6)),
                    _buildRow('Longitude', active.longitude.toStringAsFixed(6)),
                    _buildRow('Précision (accuracy)', '${active.accuracy.toStringAsFixed(1)} m'),
                    _buildRow('Vitesse (speed)', '${active.speedKmh.toStringAsFixed(1)} km/h'),
                    _buildRow('Direction (heading)', '${active.heading.toStringAsFixed(0)}°'),
                    _buildRow('Horodatage (ts)', active.timestamp.toIso8601String().substring(11, 19)),
                    const SizedBox(height: 4),
                    const Text(
                      'Étapes de la chaîne géospatiale :',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildStageIndicator(
                      '1. RAW GPS',
                      widget.rawPosition != null
                          ? '${widget.rawPosition!.latitude.toStringAsFixed(4)}, ${widget.rawPosition!.longitude.toStringAsFixed(4)} (±${widget.rawPosition!.accuracy.toStringAsFixed(0)}m)'
                          : 'En attente fix',
                    ),
                    _buildStageIndicator(
                      '2. FILTERED',
                      widget.filteredPosition != null
                          ? '${widget.filteredPosition!.latitude.toStringAsFixed(4)}, ${widget.filteredPosition!.longitude.toStringAsFixed(4)}'
                          : 'Non filtré',
                    ),
                    _buildStageIndicator(
                      '3. DISPLAY/MATCHED',
                      '${active.latitude.toStringAsFixed(4)}, ${active.longitude.toStringAsFixed(4)}',
                    ),
                    if (widget.interpolatedPosition != null)
                      _buildStageIndicator(
                        '4. INTERPOLATED (Anim)',
                        '${widget.interpolatedPosition!.latitude.toStringAsFixed(4)}, ${widget.interpolatedPosition!.longitude.toStringAsFixed(4)}',
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageIndicator(String stage, String val) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 4),
      child: Text(
        '• $stage ➔ $val',
        style: const TextStyle(
          color: Color(0xFF81C784),
          fontSize: 9,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
