import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcheggio/formatters.dart';
import 'package:parcheggio/main.dart';
import 'package:parcheggio/park_service.dart';
import 'package:parcheggio/widgets/glass_panel.dart';
import 'package:parcheggio/widgets/map_markers.dart';

const MethodChannel _parkChannel = MethodChannel('park');

const Size _foldCoverSize = Size(402, 1029);
const Size _foldInnerSize = Size(805, 967);

/// TileProvider offline deterministico per i test: evita chiamate di rete.
class _OfflineTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(TileProvider.transparentImage);
  }
}

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _encodePoint({
  required double lat,
  required double lon,
  required int acc,
  required DateTime time,
}) {
  return jsonEncode({
    'lat': lat,
    'lon': lon,
    'acc': acc,
    'time': time.millisecondsSinceEpoch,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_parkChannel, null);
  });

  group('Formattazione italiana e parsing', () {
    test('formatItalianDateTime gestisce oggi, ieri, giorno della settimana e anno', () {
      final now = DateTime(2026, 11, 20, 20, 57);

      expect(
        formatItalianDateTime(DateTime(2026, 11, 20, 18, 42), now),
        'oggi alle 18:42',
      );
      expect(
        formatItalianDateTime(DateTime(2026, 11, 19, 9, 5), now),
        'ieri alle 9:05',
      );
      // 17 novembre 2026 è martedì; 16 novembre 2026 è lunedì.
      expect(
        formatItalianDateTime(DateTime(2026, 11, 16, 8, 30), now),
        'lunedì 16 novembre alle 8:30',
      );
      expect(
        formatItalianDateTime(DateTime(2025, 11, 17, 8, 30), now),
        'lunedì 17 novembre 2025 alle 8:30',
      );
      // Controllo cambio giorno a cavallo della mezzanotte.
      expect(
        formatItalianDateTime(
          DateTime(2026, 11, 19, 23, 55),
          DateTime(2026, 11, 20, 0, 5),
        ),
        'ieri alle 23:55',
      );
    });

    test('formatElapsed formatta correttamente minuti, ore e giorni', () {
      final now = DateTime(2026, 11, 20, 20, 57);

      expect(
        formatElapsed(now.subtract(const Duration(seconds: 20)), now),
        'da meno di 1 min',
      );
      expect(
        formatElapsed(now.subtract(const Duration(minutes: 18)), now),
        'da 18 min',
      );
      expect(
        formatElapsed(now.subtract(const Duration(hours: 2)), now),
        'da 2 h',
      );
      expect(
        formatElapsed(
          now.subtract(const Duration(hours: 2, minutes: 15)),
          now,
        ),
        'da 2 h 15 min',
      );
      expect(
        formatElapsed(now.subtract(const Duration(days: 1)), now),
        'da 1 giorno',
      );
      expect(
        formatElapsed(now.subtract(const Duration(days: 2, hours: 3)), now),
        'da 2 g 3 h',
      );
    });

    test('formatDistanceReadout usa virgola italiana e cammino a 5 km/h', () {
      final d350 = formatDistanceReadout(350);
      expect(d350.distanceLabel, '350 m');
      expect(d350.walkingLabel, '5 min a piedi');
      expect(d350.fullText, 'a 350 m · 5 min a piedi');

      final d2400 = formatDistanceReadout(2400);
      expect(d2400.distanceLabel, '2,4 km');
      expect(d2400.walkingLabel, '29 min a piedi');

      final dFar = formatDistanceReadout(6800);
      expect(dFar.distanceLabel, '6,8 km');
      expect(dFar.walkingLabel, isNull);
      expect(dFar.fullText, 'a 6,8 km');
    });

    test('formatMissingSummary traduce in italiano chiaro', () {
      expect(
        formatMissingSummary(['sempre']),
        'Manca: Posizione «Consenti sempre»',
      );
      expect(
        formatMissingSummary(['posizione', 'bluetooth', 'notifiche', 'batteria']),
        'Mancano: Posizione, Bluetooth, Notifiche, Esclusione batteria',
      );
    });

    test('ParkPoint.tryParseJson valida coordinate e campi', () {
      final valid = ParkPoint.tryParseJson(
        '{"lat":45.4642,"lon":9.19,"acc":12,"time":1700000000000}',
      );
      expect(valid, isNotNull);
      expect(valid!.acc, 12);
      expect(ParkPoint.tryParseJson(null), isNull);
      expect(ParkPoint.tryParseJson('not-json'), isNull);
      expect(
        ParkPoint.tryParseJson('{"lat":999,"lon":9.19,"acc":12,"time":1000}'),
        isNull,
      );
    });
  });

  group('Widget test UI Parcheggio su dimensioni Fold5', () {
    final fixedNow = DateTime(2026, 11, 20, 20, 57);
    final parkedTime = DateTime(2026, 11, 20, 18, 42);

    void mockChannel({
      String? parkedJson,
      String? hereJson,
      List<String> missing = const [],
      Future<String?> Function()? onHere,
      Future<String?> Function()? onMark,
      List<String>? callLog,
    }) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_parkChannel, (call) async {
            callLog?.add(call.method);
            switch (call.method) {
              case 'get':
                return parkedJson;
              case 'here':
                if (onHere != null) return await onHere();
                return hereJson;
              case 'mark':
                if (onMark != null) return await onMark();
                return hereJson;
              case 'missing':
                return missing;
              case 'navigate':
              case 'fix':
                return null;
              default:
                return null;
            }
          });
    }

    testWidgets('Parcheggio presente su schermo esterno Fold5 (402x1029)', (
      tester,
    ) async {
      _setScreenSize(tester, _foldCoverSize);
      final calls = <String>[];

      mockChannel(
        parkedJson: _encodePoint(
          lat: 45.4642,
          lon: 9.1900,
          acc: 12,
          time: parkedTime,
        ),
        // ~350 m a sud dell'auto
        hereJson: _encodePoint(
          lat: 45.46105,
          lon: 9.1900,
          acc: 8,
          time: fixedNow,
        ),
        callLog: calls,
      );

      await tester.pumpWidget(
        ParcheggioApp(
          tileProvider: _OfflineTileProvider(),
          clock: () => fixedNow,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));

      expect(tester.takeException(), isNull);
      expect(calls, containsAll(['get', 'here', 'missing']));
      expect(find.text('PARCHEGGIO'), findsOneWidget);
      expect(find.text('PARCHEGGIATA'), findsOneWidget);
      expect(find.text('oggi alle 18:42'), findsOneWidget);
      expect(find.text('da 2 h 15 min'), findsOneWidget);
      expect(find.text('Precisione ±12 m'), findsOneWidget);
      expect(find.textContaining('350 m'), findsOneWidget);
      expect(find.textContaining('5 min a piedi'), findsOneWidget);
      expect(find.text("Portami all'auto"), findsOneWidget);
      expect(find.text('Segna qui'), findsOneWidget);
      expect(find.text('© OpenStreetMap © CARTO'), findsOneWidget);
      expect(find.byType(CarBeaconMarker), findsOneWidget);
      expect(find.byType(UserLocationDot), findsOneWidget);
      expect(find.byType(RecenterMapButton), findsOneWidget);
      expect(find.byType(MissingPermissionsBanner), findsNothing);

      // Tocca ricentra e poi "Portami all'auto" -> chiama navigate.
      await tester.tap(find.byType(RecenterMapButton));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text("Portami all'auto"));
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, contains('navigate'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Parcheggio presente su schermo interno Fold5 (805x967)', (
      tester,
    ) async {
      _setScreenSize(tester, _foldInnerSize);
      final calls = <String>[];

      mockChannel(
        parkedJson: _encodePoint(
          lat: 45.4642,
          lon: 9.1900,
          acc: 15,
          time: DateTime(2026, 11, 19, 9, 5),
        ),
        // ~2,4 km a sud dell'auto
        hereJson: _encodePoint(
          lat: 45.4426,
          lon: 9.1900,
          acc: 10,
          time: fixedNow,
        ),
        missing: const ['sempre', 'batteria'],
        callLog: calls,
      );

      await tester.pumpWidget(
        ParcheggioApp(
          tileProvider: _OfflineTileProvider(),
          clock: () => fixedNow,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));

      expect(tester.takeException(), isNull);
      expect(find.text('ieri alle 9:05'), findsOneWidget);
      expect(find.textContaining('2,4 km'), findsOneWidget);
      expect(find.text('Precisione ±15 m'), findsOneWidget);
      expect(find.byType(MissingPermissionsBanner), findsOneWidget);
      expect(find.textContaining('Consenti sempre'), findsOneWidget);
      expect(find.textContaining('Esclusione batteria'), findsOneWidget);

      // Tocca "Attiva" sull'avviso permessi -> chiama fix.
      await tester.tap(find.text('Attiva'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, contains('fix'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Parcheggio assente su schermo esterno Fold5 (402x1029)', (
      tester,
    ) async {
      _setScreenSize(tester, _foldCoverSize);

      mockChannel(
        parkedJson: null,
        hereJson: _encodePoint(
          lat: 45.4642,
          lon: 9.1900,
          acc: 9,
          time: fixedNow,
        ),
        missing: const ['posizione', 'bluetooth', 'notifiche', 'batteria'],
      );

      await tester.pumpWidget(
        ParcheggioApp(
          tileProvider: _OfflineTileProvider(),
          clock: () => fixedNow,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));

      expect(tester.takeException(), isNull);
      expect(find.text('NESSUNA SOSTA'), findsOneWidget);
      expect(find.text('Nessun parcheggio salvato'), findsOneWidget);
      expect(find.textContaining('Bluetooth'), findsAtLeastNWidgets(1));
      expect(find.text('Segna qui'), findsOneWidget);
      expect(find.text("Portami all'auto"), findsNothing);
      expect(find.byType(CarBeaconMarker), findsNothing);
      expect(find.byType(UserLocationDot), findsOneWidget);
      expect(find.byType(MissingPermissionsBanner), findsOneWidget);
    });

    testWidgets('Parcheggio assente su schermo interno Fold5 (805x967)', (
      tester,
    ) async {
      _setScreenSize(tester, _foldInnerSize);

      mockChannel(parkedJson: null, hereJson: null, missing: const []);

      await tester.pumpWidget(
        ParcheggioApp(
          tileProvider: _OfflineTileProvider(),
          clock: () => fixedNow,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));

      expect(tester.takeException(), isNull);
      expect(find.text('Nessun parcheggio salvato'), findsOneWidget);
      expect(find.text('Segna qui'), findsOneWidget);
      expect(find.byType(MissingPermissionsBanner), findsNothing);
      expect(find.byType(CarBeaconMarker), findsNothing);
    });

    testWidgets(
      'Segna qui chiede conferma se esiste parcheggio e segna diretto se vuoto',
      (tester) async {
        _setScreenSize(tester, _foldCoverSize);
        final calls = <String>[];
        final updatedJson = _encodePoint(
          lat: 45.4700,
          lon: 9.1950,
          acc: 7,
          time: fixedNow,
        );

        mockChannel(
          parkedJson: _encodePoint(
            lat: 45.4642,
            lon: 9.1900,
            acc: 12,
            time: parkedTime,
          ),
          hereJson: updatedJson,
          onMark: () async => updatedJson,
          callLog: calls,
        );

        await tester.pumpWidget(
          ParcheggioApp(
            tileProvider: _OfflineTileProvider(),
            clock: () => fixedNow,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));

        await tester.tap(find.text('Segna qui'));
        await tester.pump(const Duration(milliseconds: 250));

        // Deve comparire il dialog di conferma prima di chiamare `mark`.
        expect(find.text('Sostituire la sosta?'), findsOneWidget);
        expect(calls.contains('mark'), isFalse);

        // Conferma sul dialog -> chiama `mark` e aggiorna l'orario mostrato.
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Segna qui'),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        expect(calls, contains('mark'));
        expect(find.text('oggi alle 20:57'), findsOneWidget);
        expect(find.text('Precisione ±7 m'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Segna qui in stato vuoto salva direttamente senza dialog di conferma',
      (tester) async {
        _setScreenSize(tester, _foldCoverSize);
        final calls = <String>[];
        final markedJson = _encodePoint(
          lat: 45.4650,
          lon: 9.1910,
          acc: 6,
          time: fixedNow,
        );

        mockChannel(
          parkedJson: null,
          hereJson: markedJson,
          onMark: () async => markedJson,
          callLog: calls,
        );

        await tester.pumpWidget(
          ParcheggioApp(
            tileProvider: _OfflineTileProvider(),
            clock: () => fixedNow,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));

        expect(find.text('Nessun parcheggio salvato'), findsOneWidget);

        await tester.tap(find.text('Segna qui'));
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(AlertDialog), findsNothing);
        expect(calls, contains('mark'));
        expect(find.text('PARCHEGGIATA'), findsOneWidget);
        expect(find.text('oggi alle 20:57'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Nessun overflow con scala testo elevata su schermo esterno (402x1029)',
      (tester) async {
        _setScreenSize(tester, _foldCoverSize);
        mockChannel(
          parkedJson: _encodePoint(
            lat: 45.4642,
            lon: 9.1900,
            acc: 18,
            time: DateTime(2026, 11, 16, 8, 30),
          ),
          hereJson: _encodePoint(
            lat: 45.46105,
            lon: 9.1900,
            acc: 10,
            time: fixedNow,
          ),
          missing: const ['posizione', 'bluetooth', 'notifiche', 'batteria'],
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: _foldCoverSize,
              textScaler: TextScaler.linear(1.35),
            ),
            child: ParcheggioApp(
              tileProvider: _OfflineTileProvider(),
              clock: () => fixedNow,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));

        expect(tester.takeException(), isNull);
        expect(find.text('lunedì 16 novembre alle 8:30'), findsOneWidget);
        expect(find.byType(MissingPermissionsBanner), findsOneWidget);
      },
    );

    testWidgets(
      'here non blocca la UI e il ritorno in primo piano ricarica i dati',
      (tester) async {
        _setScreenSize(tester, _foldCoverSize);
        final hereCompleter = Completer<String?>();
        final calls = <String>[];
        var missingList = <String>['batteria'];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_parkChannel, (call) async {
              calls.add(call.method);
              switch (call.method) {
                case 'get':
                  return _encodePoint(
                    lat: 45.4642,
                    lon: 9.1900,
                    acc: 10,
                    time: parkedTime,
                  );
                case 'here':
                  if (!hereCompleter.isCompleted) {
                    return await hereCompleter.future;
                  }
                  return _encodePoint(
                    lat: 45.46105,
                    lon: 9.1900,
                    acc: 6,
                    time: fixedNow,
                  );
                case 'missing':
                  return missingList;
                default:
                  return null;
              }
            });

        await tester.pumpWidget(
          ParcheggioApp(
            tileProvider: _OfflineTileProvider(),
            clock: () => fixedNow,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));

        // La card parcheggio è subito visibile anche mentre `here` è in corso.
        expect(find.text('oggi alle 18:42'), findsOneWidget);
        expect(find.text('Rilevo la tua posizione…'), findsOneWidget);
        expect(find.byType(MissingPermissionsBanner), findsOneWidget);

        // Quando `here` arriva, appare la distanza.
        hereCompleter.complete(
          _encodePoint(lat: 45.46105, lon: 9.1900, acc: 6, time: fixedNow),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.textContaining('350 m'), findsOneWidget);

        // Simula il ritorno in primo piano dopo aver risolto i permessi.
        missingList = const [];
        calls.clear();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 350));

        expect(calls, containsAll(['get', 'here', 'missing']));
        expect(find.byType(MissingPermissionsBanner), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
