import 'package:latlong2/latlong.dart';

const List<String> _italianWeekdays = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];

const List<String> _italianMonths = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

const Distance _geodesicDistance = Distance(roundResult: false);

/// Velocità media a piedi: 5 km/h = 5000 / 60 metri al minuto.
const double _walkingMetersPerMinute = 5000.0 / 60.0;

/// Oltre 5 km (~1 ora) omettiamo il tempo a piedi per tenere il dato pulito.
const double _maxWalkingTimeMeters = 5000.0;

/// Formatta un numero con la virgola decimale italiana.
String formatItalianDecimal(double value, {int decimals = 1}) {
  return value.toStringAsFixed(decimals).replaceAll('.', ',');
}

/// Formatta l'orario come "18:42" o "9:05" (senza zero iniziale sulle ore).
String formatItalianTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.hour}:$mm';
}

/// Formatta giorno e ora in italiano naturale:
/// - "oggi alle 18:42"
/// - "ieri alle 9:05"
/// - "lunedì 17 novembre alle 8:30"
/// - "lunedì 17 novembre 2025 alle 8:30" (se di un altro anno)
String formatItalianDateTime(DateTime dateTime, DateTime now) {
  final local = dateTime.toLocal();
  final localNow = now.toLocal();
  final targetDay = DateTime(local.year, local.month, local.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final timeText = formatItalianTime(local);

  if (targetDay == today) {
    return 'oggi alle $timeText';
  }
  if (targetDay == yesterday) {
    return 'ieri alle $timeText';
  }

  final weekday = _italianWeekdays[local.weekday - 1];
  final month = _italianMonths[local.month - 1];
  final yearSuffix = local.year != localNow.year ? ' ${local.year}' : '';
  return '$weekday ${local.day} $month$yearSuffix alle $timeText';
}

/// Formatta la durata trascorsa dal parcheggio:
/// - "da meno di 1 min"
/// - "da 14 min"
/// - "da 2 h"
/// - "da 2 h 15 min"
/// - "da 1 giorno" / "da 2 g 4 h"
String formatElapsed(DateTime since, DateTime now) {
  final diff = now.difference(since);
  final totalMinutes = diff.inMinutes;
  if (totalMinutes < 1) {
    return 'da meno di 1 min';
  }
  if (totalMinutes < 60) {
    return 'da $totalMinutes min';
  }
  if (totalMinutes < 24 * 60) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return 'da $hours h';
    }
    return 'da $hours h $minutes min';
  }
  final days = totalMinutes ~/ (24 * 60);
  final hours = (totalMinutes % (24 * 60)) ~/ 60;
  if (hours == 0) {
    return days == 1 ? 'da 1 giorno' : 'da $days giorni';
  }
  return 'da $days g $hours h';
}

/// Risultato strutturato per distanza e tempo di cammino a 5 km/h.
class DistanceReadout {
  const DistanceReadout({
    required this.meters,
    required this.distanceLabel,
    required this.walkingLabel,
  });

  final double meters;
  final String distanceLabel;
  final String? walkingLabel;

  /// Es. "a 350 m · 5 min a piedi" oppure "a 2,4 km" / "a 6,8 km".
  String get fullText => walkingLabel == null
      ? 'a $distanceLabel'
      : 'a $distanceLabel · $walkingLabel';
}

/// Calcola la distanza geodetica in metri tra due coordinate.
double calculateDistanceMeters(LatLng from, LatLng to) {
  final meters = _geodesicDistance.distance(from, to);
  if (!meters.isFinite || meters < 0) return 0;
  return meters;
}

/// Costruisce il readout di distanza e tempo a piedi a 5 km/h con virgola italiana.
DistanceReadout formatDistanceReadout(double meters) {
  final safeMeters = meters < 0 || !meters.isFinite ? 0.0 : meters;

  final String distanceLabel;
  if (safeMeters < 1000) {
    distanceLabel = '${safeMeters.round()} m';
  } else if (safeMeters < 100000) {
    distanceLabel = '${formatItalianDecimal(safeMeters / 1000.0)} km';
  } else {
    distanceLabel = '${(safeMeters / 1000.0).round()} km';
  }

  String? walkingLabel;
  if (safeMeters < 20) {
    walkingLabel = 'qui vicino';
  } else if (safeMeters <= _maxWalkingTimeMeters) {
    final walkMinutes = (safeMeters / _walkingMetersPerMinute).ceil();
    if (walkMinutes < 60) {
      walkingLabel = '$walkMinutes min a piedi';
    } else {
      final h = walkMinutes ~/ 60;
      final m = walkMinutes % 60;
      walkingLabel = m == 0 ? '$h h a piedi' : '$h h $m min a piedi';
    }
  }

  return DistanceReadout(
    meters: safeMeters,
    distanceLabel: distanceLabel,
    walkingLabel: walkingLabel,
  );
}

/// Formatta la precisione GPS in modo discreto ("±12 m").
String formatAccuracy(int accuracyMeters) {
  final clamped = accuracyMeters < 0 ? 0 : accuracyMeters;
  return '±$clamped m';
}

/// Converte una chiave di `missing` nel nome italiano chiaro per l'utente.
String formatMissingItem(String key) {
  switch (key) {
    case 'posizione':
      return 'Posizione';
    case 'sempre':
      return 'Posizione «Consenti sempre»';
    case 'bluetooth':
      return 'Bluetooth';
    case 'notifiche':
      return 'Notifiche';
    case 'batteria':
      return 'Esclusione batteria';
    default:
      return key;
  }
}

/// Sintesi compatta in italiano per l'avviso sui permessi mancanti.
String formatMissingSummary(List<String> missing) {
  if (missing.isEmpty) return '';
  final labels = missing.map(formatMissingItem).toList(growable: false);
  if (labels.length == 1) {
    return 'Manca: ${labels.first}';
  }
  return 'Mancano: ${labels.join(', ')}';
}
