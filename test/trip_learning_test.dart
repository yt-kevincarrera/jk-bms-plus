import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/long_term_analysis.dart';
import 'package:jk_bms/src/metrics/trip_learning.dart';

Trip _trip(
  int id, {
  required DateTime at,
  double km = 10,
  double outWh = 180,
  String? energySource,
  bool? representative,
}) => Trip(
  id: id,
  deviceId: 'AA:BB',
  startedAt: at,
  endedAt: at.add(const Duration(minutes: 30)),
  distanceKm: km,
  movingSeconds: 1500,
  totalSeconds: 1800,
  maxSpeedKmh: 40,
  energyOutWh: outWh,
  energyInWh: 0,
  startSoc: 90,
  endSoc: 70,
  minPackVoltage: 70,
  maxPackVoltage: 82,
  maxDischargeCurrent: 30,
  maxTemperature: 30,
  maxDeltaVolts: 0.02,
  climbM: 10,
  descentM: 10,
  note: '',
  demo: false,
  energySource: energySource,
  representative: representative,
  summarySeen: true,
);

void main() {
  final day = DateTime.utc(2026, 9, 1);

  group('the rides a saved pack learns from', () {
    test('are the live service\'s: oldest first, whatever order they came in',
        () {
      // The saved-pack screen fed the rides newest first to an estimator that
      // weights the later ones, so its range followed the oldest ride.
      final newestFirst = [
        _trip(3, at: day.add(const Duration(days: 2)), outWh: 300),
        _trip(2, at: day.add(const Duration(days: 1)), outWh: 180),
        _trip(1, at: day, outWh: 120),
      ];
      final fromList = TripLearning.estimatorFrom(newestFirst);
      final fromSorted =
          TripLearning.estimatorFrom(newestFirst.reversed.toList());
      expect(fromList.whPerKm, fromSorted.whPerKm);
      expect(
        TripLearning.forLearning(newestFirst).map((t) => t.id),
        [1, 2, 3],
      );
    });

    test('leave out a ride marked as an exception', () {
      // Marking one on the saved-pack screen used to change nothing while the
      // confirmation said the range had moved.
      final trips = [
        _trip(1, at: day, outWh: 180),
        _trip(2, at: day.add(const Duration(days: 1)), outWh: 600,
            representative: false),
      ];
      expect(TripLearning.estimatorFrom(trips).whPerKm, closeTo(18, 0.01));
    });

    test('leave out a ride whose energy was never measured', () {
      final unmeasured = _trip(1, at: day, outWh: 0,
          energySource: 'partialCoulombCount');
      expect(TripLearning.teaches(unmeasured), isFalse);
      expect(TripLearning.isMeasured(unmeasured), isFalse);
    });
  });

  group('the consumption trend', () {
    const analysis = LongTermAnalysis();

    test('plots only measured rides that count, at a believable figure', () {
      final trips = [
        _trip(1, at: day, outWh: 180),
        // An exception, a ride the link dropped on, and a figure no bike
        // produces: none of them say anything about the bike over time.
        _trip(2, at: day.add(const Duration(days: 1)), outWh: 400,
            representative: false),
        _trip(3, at: day.add(const Duration(days: 2)), outWh: 10,
            energySource: 'partialCoulombCount'),
        _trip(4, at: day.add(const Duration(days: 3)), outWh: 30),
      ];
      final points = analysis.consumptionOverTime(trips);
      expect(points, hasLength(1));
      expect(points.single.whPerKm, closeTo(18, 0.01));
    });
  });
}
