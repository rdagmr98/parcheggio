import 'package:flutter/material.dart';

import '../theme.dart';

/// Marker dell'auto parcheggiata: cerchio rosso Audi con pulsazione radar sobria
/// e icona auto ad alto contrasto su mappa scura.
class CarBeaconMarker extends StatefulWidget {
  const CarBeaconMarker({super.key});

  @override
  State<CarBeaconMarker> createState() => _CarBeaconMarkerState();
}

class _CarBeaconMarkerState extends State<CarBeaconMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Posizione auto parcheggiata',
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Onda radar che si espande e sfuma con calma.
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_pulseController.value);
                final size = 40.0 + (46.0 * t);
                final opacity = (1.0 - t) * 0.42;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.audiRed.withValues(alpha: opacity * 0.45),
                    border: Border.all(
                      color: AppColors.audiRedBright.withValues(alpha: opacity),
                      width: 1.4,
                    ),
                  ),
                );
              },
            ),
            // Alone radiale rosso fisso.
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.audiRed.withValues(alpha: 0.42),
                    AppColors.audiRed.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            // Foto frontale dell'A3 (assets/auto.jpg) con cornice rosso Audi.
            Container(
              width: 70,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.audiRed,
                border: Border.all(color: AppColors.audiRedBright, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.audiRed.withValues(alpha: 0.45),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/auto.jpg', fit: BoxFit.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto blu pulito per la posizione attuale dell'utente.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'La tua posizione',
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.userBlue.withValues(alpha: 0.20),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.userBlue,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
