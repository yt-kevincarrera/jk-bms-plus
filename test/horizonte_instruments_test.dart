import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/ui/theme.dart';
import 'package:jk_bms/src/ui/widgets/instruments.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  test('text and signal roles remain readable on both sets of surfaces', () {
    for (final brightness in Brightness.values) {
      final p = AppTheme.palette(brightness);
      for (final surface in [p.surface, p.surfaceRaised, p.surfaceHigh]) {
        for (final text in [
          p.textPrimary,
          p.textSecondary,
          p.textFaint,
          p.good,
          p.watch,
          p.bad,
        ]) {
          expect(
            contrast(text, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness: $text on $surface',
          );
        }
      }
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'range and trip instruments fit 320 dp at 200% text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(brightness: brightness),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        RangeInstrument(
                          rangeLabel: 'Autonomía actual estimada',
                          rangeValue: '58',
                          soc: 72,
                          socLabel: 'Carga',
                          band: 'Entre 51 y 65 km',
                          capacity: '32,4 Ah',
                        ),
                        TripInstruments(
                          distanceLabel: 'Distancia',
                          distance: '12,80',
                          consumptionLabel: 'Consumo',
                          consumption: '--',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('58'), findsOneWidget);
        expect(find.text('12,80'), findsOneWidget);
        expect(find.text('--'), findsOneWidget);
      },
    );
  }

  testWidgets('separate theme contexts cannot change each other', (
    tester,
  ) async {
    Color? light, dark;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Theme(
              data: AppTheme.build(brightness: Brightness.light),
              child: Builder(
                builder: (context) {
                  light = context.colors.textPrimary;
                  return const SizedBox();
                },
              ),
            ),
            Theme(
              data: AppTheme.build(),
              child: Builder(
                builder: (context) {
                  dark = context.colors.textPrimary;
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
    expect(light, AppTheme.palette(Brightness.light).textPrimary);
    expect(dark, AppTheme.palette(Brightness.dark).textPrimary);
    expect(light, isNot(dark));
  });
}
