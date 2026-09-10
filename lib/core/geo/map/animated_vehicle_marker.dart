import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/yobalema_theme.dart';

/// Visually rich, smooth-rotating vehicle marker widget.
class VehicleMarkerWidget extends StatelessWidget {
  final double headingDegrees;
  final bool isSelected;
  final double size;
  final Color primaryColor;
  final IconData icon;

  const VehicleMarkerWidget({
    super.key,
    required this.headingDegrees,
    this.isSelected = false,
    this.size = 44.0,
    this.primaryColor = YobalemaTheme.ink,
    this.icon = Icons.two_wheeler,
  });

  @override
  Widget build(BuildContext context) {
    final rotationRad = headingDegrees * (math.pi / 180.0);

    return SizedBox(
      width: size + 16,
      height: size + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Directional pointer / halo
          Transform.rotate(
            angle: rotationRad,
            child: Container(
              width: size + 10,
              height: size + 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.25),
                    primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: YobalemaTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Main badge
          Transform.rotate(
            angle: rotationRad,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: size * 0.58,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
