// Anteprime PNG della UI con font veri: flutter test --update-goldens test/preview_test.dart -> test/preview/*.png
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcheggio/main.dart';

const fonts = 'C:/tools/flutter/bin/cache/artifacts/material_fonts';

Future<void> font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File('$fonts/$f').readAsBytesSync())));
  }
  await l.load();
}

void main() {
  final now = DateTime(2026, 11, 20, 20, 57);
  final car = {'lat': 42.4207, 'lon': 12.1077, 'acc': 12, 'time': DateTime(2026, 11, 20, 18, 42).millisecondsSinceEpoch};
  final me = {'lat': 42.4209, 'lon': 12.1079, 'acc': 6, 'time': now.millisecondsSinceEpoch};

  setUpAll(() async {
    await font('Roboto', ['roboto-light.ttf', 'roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']);
    await font('MaterialIcons', ['materialicons-regular.otf']);
  });

  for (final (name, size, park, missing) in [
    ('esterno', const Size(402, 1029), true, <String>[]),
    ('interno', const Size(805, 967), true, <String>[]),
    ('esterno_vuoto', const Size(402, 1029), false, <String>[]),
    ('esterno_permessi', const Size(402, 1029), true, ['sempre', 'batteria']),
  ]) {
    testWidgets(name, (t) async {
      t.view.physicalSize = size * 2.25;
      t.view.devicePixelRatio = 2.25;
      addTearDown(t.view.reset);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('park'), (c) async => switch (c.method) {
                'get' => park ? jsonEncode(car) : null,
                'here' => jsonEncode(me),
                'missing' => missing,
                _ => null,
              });
      await t.pumpWidget(ParcheggioApp(clock: () => now));
      for (var i = 0; i < 6; i++) {
        await t.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await t.pump(const Duration(milliseconds: 300));
      }
      await expectLater(find.byType(ParcheggioApp), matchesGoldenFile('preview/$name.png'));
    });
  }
}
