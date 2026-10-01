import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/l10n/app_localizations.dart';
import 'package:jk_bms/l10n/app_localizations_es.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/ui/widgets/trip_map.dart';

/// A made-up track in open sea off 0,0, so nothing here is anybody's street:
/// the repository is public and a real ride's fixes are where someone lives.
List<TripPoint> track(List<double> speeds, {List<double>? amps}) => [
  for (var i = 0; i < speeds.length; i++)
    TripPoint(
      id: i,
      tripId: 1,
      timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: i * 2)),
      latitude: 0.5 + i * 0.0002,
      longitude: 0.5 + i * 0.0001,
      speedKmh: speeds[i],
      altitudeM: 0,
      packVoltage: 72,
      current: amps?[i] ?? -10,
      soc: 50,
    ),
];

void main() {
  test('points with no position are not drawn', () {
    final points = [
      ...track([10, 20]),
      TripPoint(
        id: 9,
        tripId: 1,
        timestamp: DateTime.utc(2026),
        latitude: 0,
        longitude: 0,
        speedKmh: 0,
        altitudeM: 0,
        packVoltage: 72,
        current: 0,
        soc: 50,
      ),
      TripPoint(
        id: 10,
        tripId: 1,
        timestamp: DateTime.utc(2026),
        latitude: 95,
        longitude: 0.5,
        speedKmh: 0,
        altitudeM: 0,
        packVoltage: 72,
        current: 0,
        soc: 50,
      ),
    ];
    expect(drawablePoints(points), hasLength(2));
  });

  test('the colour follows the value, and a flat ride does not divide by 0',
      () {
    expect(tripMapBin(0, 0, 40), 0);
    expect(tripMapBin(40, 0, 40), tripMapPalette.length - 1);
    expect(tripMapBin(25, 0, 40), 2);
    expect(tripMapBin(30, 30, 30), 0);
  });

  test('power is watts out of the pack, whatever is charging', () {
    final p = track([10], amps: [-12.5]).single;
    expect(tripMapValue(p, TripMapColoring.power), closeTo(900, 1e-9));
    final regen = track([10], amps: [5]).single;
    expect(tripMapValue(regen, TripMapColoring.power), 0);
  });

  test('the route is runs of one colour that join without gaps', () {
    final points = track([5, 5, 5, 40, 40, 5]);
    final runs = tripMapRuns(points, TripMapColoring.speed);
    expect(runs.length, greaterThan(1));
    // Every run starts where the previous one ended.
    for (var i = 1; i < runs.length; i++) {
      expect(runs[i].points.first, runs[i - 1].points.last);
    }
    // And together they cover every point once, plus the shared joins.
    final total = runs.fold<int>(0, (n, r) => n + r.points.length);
    expect(total, points.length + runs.length - 1);
  });

  testWidgets('draws the route with start and finish, and credits the map',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              TripMap(points: track([5, 12, 30, 45, 20]), showTiles: false),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    final t = AppL10nEs();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    expect(find.text('OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('5 km/h'), findsOneWidget);
    expect(find.text('45 km/h'), findsOneWidget);

    await tester.tap(find.text(t.tripMapByPower));
    await tester.pump();
    expect(find.text('720 W'), findsWidgets);
    expect(find.text(t.tripMapPowerHint), findsOneWidget);
  });

  testWidgets('a ride with fewer than two fixes draws nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: TripMap(points: track([10]), showTiles: false)),
      ),
    );
    expect(find.byType(FlutterMap), findsNothing);
  });
}
