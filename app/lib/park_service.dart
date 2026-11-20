import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Posizione GPS ricevuta dal lato nativo Android.
class ParkPoint {
  const ParkPoint({
    required this.lat,
    required this.lon,
    required this.acc,
    required this.time,
  });

  final double lat;
  final double lon;
  final int acc;
  final DateTime time;

  LatLng get latLng => LatLng(lat, lon);

  static ParkPoint? tryParseJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final lat = (decoded['lat'] as num?)?.toDouble();
      final lon = (decoded['lon'] as num?)?.toDouble();
      final acc = (decoded['acc'] as num?)?.round() ?? 0;
      final timeMs = (decoded['time'] as num?)?.toInt();
      if (lat == null || lon == null || timeMs == null) return null;
      if (!lat.isFinite || !lon.isFinite) return null;
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
      return ParkPoint(
        lat: lat,
        lon: lon,
        acc: acc < 0 ? 0 : acc,
        time: DateTime.fromMillisecondsSinceEpoch(timeMs),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParkPoint &&
          other.lat == lat &&
          other.lon == lon &&
          other.acc == acc &&
          other.time == time;

  @override
  int get hashCode => Object.hash(lat, lon, acc, time);
}

/// Bridge tipizzato sul MethodChannel nativo `park`.
class ParkService {
  const ParkService([this._channel = const MethodChannel('park')]);

  final MethodChannel _channel;

  Future<ParkPoint?> getParked() async {
    try {
      final raw = await _channel.invokeMethod<String>('get');
      return ParkPoint.tryParseJson(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<ParkPoint?> getHere() async {
    try {
      final raw = await _channel.invokeMethod<String>('here');
      return ParkPoint.tryParseJson(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<ParkPoint?> markHere() async {
    try {
      final raw = await _channel.invokeMethod<String>('mark');
      return ParkPoint.tryParseJson(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> navigate() async {
    try {
      await _channel.invokeMethod<void>('navigate');
    } on PlatformException {
      // Gestito silenziosamente se l'intent non è disponibile.
    } on MissingPluginException {
      // Ignorato in ambiente senza plugin nativo.
    }
  }

  Future<List<String>> getMissing() async {
    try {
      final list = await _channel.invokeListMethod<String>('missing');
      return list ?? const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> fix() async {
    try {
      await _channel.invokeMethod<void>('fix');
    } on PlatformException {
      // Ignorato se il sistema rifiuta l'intent.
    } on MissingPluginException {
      // Ignorato in ambiente senza plugin nativo.
    }
  }
}
