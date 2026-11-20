import 'dart:ui';

import 'package:flutter/material.dart';

import '../formatters.dart';
import '../park_service.dart';
import '../theme.dart';

/// Superficie in vetro scuro satinato con bordo sottile stile cockpit automotive.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.padding = EdgeInsets.zero,
    this.blurSigma = 20,
    this.opacity = 0.86,
    this.borderColor,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final double opacity;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.glassElevated.withValues(alpha: opacity),
                  AppColors.glassBase.withValues(
                    alpha: (opacity + 0.06).clamp(0.0, 0.96),
                  ),
                ],
              ),
              border: Border.all(
                color: borderColor ?? AppColors.hairline(0.11),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Intestazione minimale fluttuante in alto sulla mappa.
class BrandHeaderBadge extends StatelessWidget {
  const BrandHeaderBadge({super.key, this.isBusy = false});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      blurSigma: 16,
      opacity: 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 2.5,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.audiRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'PARCHEGGIO',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.brandBadge,
            ),
          ),
          if (isBusy) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Avviso integrato e discreto per i permessi mancanti al rilevamento automatico.
class MissingPermissionsBanner extends StatelessWidget {
  const MissingPermissionsBanner({
    super.key,
    required this.missing,
    required this.onFix,
  });

  final List<String> missing;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final summary = formatMissingSummary(missing);
    return GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      blurSigma: 18,
      opacity: 0.88,
      borderColor: AppColors.warningAmber.withValues(alpha: 0.30),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.warningAmber,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RILEVAMENTO AUTOMATICO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.microLabel.copyWith(
                    fontSize: 9.5,
                    color: AppColors.warningAmber,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontSize: 13,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.warningAmber.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.warningAmber.withValues(alpha: 0.45),
              ),
            ),
            child: InkWell(
              onTap: onFix,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                child: Text(
                  'Attiva',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warningAmber,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsante vetro scuro per ricentrare la mappa su auto/utente.
class RecenterMapButton extends StatelessWidget {
  const RecenterMapButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ricentra mappa',
      child: GlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        blurSigma: 16,
        opacity: 0.84,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.my_location_rounded,
                size: 21,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Attribuzione piccola e discreta per OpenStreetMap / CARTO.
class AttributionBadge extends StatelessWidget {
  const AttributionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgObsidian.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline(0.06)),
      ),
      child: Text(
        '© OpenStreetMap © CARTO',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          color: AppColors.textSecondary.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

/// Pannello principale (in basso su schermo stretto, laterale su schermo aperto).
class ParkingInfoPanel extends StatelessWidget {
  const ParkingInfoPanel({
    super.key,
    required this.parked,
    required this.here,
    required this.now,
    required this.isLocatingHere,
    required this.isMarking,
    required this.onNavigate,
    required this.onMark,
  });

  final ParkPoint? parked;
  final ParkPoint? here;
  final DateTime now;
  final bool isLocatingHere;
  final bool isMarking;
  final VoidCallback onNavigate;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      blurSigma: 22,
      opacity: 0.88,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (parked == null) {
      return _EmptyParkingContent(
        key: const ValueKey('empty'),
        here: here,
        isLocatingHere: isLocatingHere,
        isMarking: isMarking,
        onMark: onMark,
      );
    }
    return _ParkedContent(
      key: ValueKey('parked-${parked!.time.millisecondsSinceEpoch}'),
      parked: parked!,
      here: here,
      now: now,
      isLocatingHere: isLocatingHere,
      isMarking: isMarking,
      onNavigate: onNavigate,
      onMark: onMark,
    );
  }
}

class _ParkedContent extends StatelessWidget {
  const _ParkedContent({
    super.key,
    required this.parked,
    required this.here,
    required this.now,
    required this.isLocatingHere,
    required this.isMarking,
    required this.onNavigate,
    required this.onMark,
  });

  final ParkPoint parked;
  final ParkPoint? here;
  final DateTime now;
  final bool isLocatingHere;
  final bool isMarking;
  final VoidCallback onNavigate;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final dateTimeLabel = formatItalianDateTime(parked.time, now);
    final elapsedLabel = formatElapsed(parked.time, now);
    final accuracyLabel = 'Precisione ${formatAccuracy(parked.acc)}';

    final DistanceReadout? distanceReadout = here == null
        ? null
        : formatDistanceReadout(
            calculateDistanceMeters(here!.latLng, parked.latLng),
          );

    // Date lunghe (es. "mercoledì 18 novembre alle 8:30") usano un corpo
    // leggermente più contenuto per restare ariose e leggibili.
    final bool isLongDate = dateTimeLabel.length > 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Riga superiore: stato + precisione GPS discreta.
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.audiRed,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.audiRed.withValues(alpha: 0.65),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'PARCHEGGIATA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.microLabel,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                accuracyLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Dato protagonista 1: giorno e ora del parcheggio.
        Text(
          dateTimeLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: isLongDate
              ? AppTypography.titleLight.copyWith(fontSize: 23)
              : AppTypography.heroDisplay.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 6),

        // Durata trascorsa (aggiornata ogni minuto).
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                elapsedLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const _HairlineDivider(),
        const SizedBox(height: 14),

        // Dato protagonista 2: distanza dall'utente e tempo a piedi.
        Row(
          children: [
            const Expanded(
              child: Text(
                'DISTANZA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.microLabel,
              ),
            ),
            if (isLocatingHere && distanceReadout != null)
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previousChildren, ?currentChild],
          ),
          child: _buildDistanceRow(distanceReadout),
        ),

        const SizedBox(height: 20),

        // Azione primaria grande nella zona del pollice.
        _PrimaryActionButton(
          label: "Portami all'auto",
          icon: Icons.directions_walk_rounded,
          onPressed: onNavigate,
        ),
        const SizedBox(height: 10),

        // Azione secondaria discreta.
        _SecondaryActionButton(
          label: isMarking ? 'Salvataggio posizione…' : 'Segna qui',
          icon: Icons.add_location_alt_outlined,
          isLoading: isMarking,
          onPressed: isMarking ? null : onMark,
        ),
      ],
    );
  }

  Widget _buildDistanceRow(DistanceReadout? readout) {
    if (readout != null) {
      return Align(
        key: ValueKey('dist-${readout.fullText}'),
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'a ',
                style: AppTypography.body.copyWith(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              TextSpan(
                text: readout.distanceLabel,
                style: AppTypography.heroMetric,
              ),
              if (readout.walkingLabel != null)
                TextSpan(
                  text: ' · ${readout.walkingLabel}',
                  style: AppTypography.body.copyWith(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (isLocatingHere) {
      return Row(
        key: const ValueKey('dist-loading'),
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.7,
              color: AppColors.userBlue.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rilevo la tua posizione…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Align(
      key: const ValueKey('dist-unavailable'),
      alignment: Alignment.centerLeft,
      child: Text(
        'Posizione attuale non disponibile',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

class _EmptyParkingContent extends StatelessWidget {
  const _EmptyParkingContent({
    super.key,
    required this.here,
    required this.isLocatingHere,
    required this.isMarking,
    required this.onMark,
  });

  final ParkPoint? here;
  final bool isLocatingHere;
  final bool isMarking;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'NESSUNA SOSTA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.microLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Nessun parcheggio salvato',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleLight,
        ),
        const SizedBox(height: 8),
        const Text(
          'Alla prossima sosta la posizione arriverà da sola quando il telefono si stacca dal Bluetooth dell\'auto.',
          style: AppTypography.body,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (isLocatingHere) ...[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.userBlue.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rilevo la tua posizione…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ] else if (here != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.userBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Posizione attuale attiva · ${formatAccuracy(here!.acc)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ] else ...[
              Icon(
                Icons.bluetooth_connected_rounded,
                size: 14,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Puoi anche salvare il punto manualmente qui sotto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _PrimaryActionButton(
          label: isMarking ? 'Salvataggio posizione…' : 'Segna qui',
          icon: Icons.add_location_alt_outlined,
          isLoading: isMarking,
          onPressed: isMarking ? null : onMark,
        ),
      ],
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled
              ? const [AppColors.audiRedBright, AppColors.audiRed]
              : [
                  AppColors.audiRed.withValues(alpha: 0.50),
                  AppColors.audiRedDark.withValues(alpha: 0.50),
                ],
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.audiRed.withValues(alpha: 0.36),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      ),
                    ),
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

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.hairline(0.11)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Icon(icon, size: 17, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog di conferma sobrio prima di sovrascrivere una sosta già salvata.
Future<bool> showConfirmOverwriteDialog(
  BuildContext context, {
  required String existingDateTimeLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.68),
    builder: (dialogContext) {
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.audiRed.withValues(alpha: 0.16),
                border: Border.all(
                  color: AppColors.audiRed.withValues(alpha: 0.40),
                ),
              ),
              child: const Icon(
                Icons.add_location_alt_outlined,
                size: 18,
                color: AppColors.audiRedBright,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sostituire la sosta?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Il parcheggio salvato ($existingDateTimeLabel) verrà sostituito con la posizione attuale.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Annulla',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.audiRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Segna qui'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
