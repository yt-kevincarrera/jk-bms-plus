import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/data/database.dart';
import 'package:jk_bms/src/metrics/range_estimator.dart';
import 'package:jk_bms/src/metrics/trip_recorder.dart';
import 'package:jk_bms/src/ui/widgets/trip_summary_view.dart';

void main() {
  group('the summary of a ride', () {
    test('reads the same from a stored row as from a fresh stop', () {
      // The sheet used to be built only from what stopTrip returned, so a ride
      // that closed itself had a summary nobody could ever see. The two paths
      // have to agree, or the pocket ride would get a second-class version of
      // the same screen.
      final outcome = _outcome(km: 20, energyOutWh: 350, energyInWh: 0);
      final stored = _storedTrip(km: 20, energyOutWh: 350, energyInWh: 0);

      final fromStop = TripSummaryView.fromOutcome(outcome, tripId: 7);
      final fromRow = TripSummaryView.fromStored(stored);

      expect(fromRow.distanceKm, fromStop.distanceKm);
      expect(fromRow.whPerKm, fromStop.whPerKm);
      expect(fromRow.movingDuration, fromStop.movingDuration);
    });

    test('a stored row carries the answer already given', () {
      final stored = _storedTrip(
        km: 20,
        energyOutWh: 350,
        energyInWh: 0,
        representative: false,
      );
      expect(TripSummaryView.fromStored(stored).representative, isFalse);
    });

    test('carries what the pack did, from either path', () {
      // These fields are not read from summary.x / trip.x by the sheet
      // directly, they are what the "how the pack behaved" section is built
      // from. Dropping them silently would leave that section blank instead
      // of failing loudly, so they get their own check.
      final outcome = _outcome(km: 20, energyOutWh: 350, energyInWh: 0);
      final stored = _storedTrip(km: 20, energyOutWh: 350, energyInWh: 0);

      final fromStop = TripSummaryView.fromOutcome(outcome, tripId: 7);
      final fromRow = TripSummaryView.fromStored(stored);

      expect(fromRow.startSoc, fromStop.startSoc);
      expect(fromRow.endSoc, fromStop.endSoc);
      expect(fromRow.minPackVoltage, fromStop.minPackVoltage);
      expect(fromRow.maxPackVoltage, fromStop.maxPackVoltage);
      expect(fromRow.maxDischargeCurrent, fromStop.maxDischargeCurrent);
      expect(fromRow.maxTemperature, fromStop.maxTemperature);
      expect(fromRow.maxDeltaVolts, fromStop.maxDeltaVolts);
      expect(fromRow.socUsed, fromStop.socUsed);
      expect(fromRow.socPerKm, fromStop.socPerKm);
      expect(fromRow.sagVolts, fromStop.sagVolts);
    });

    test('carries what the ride taught the range estimate, from either path', () {
      // TripLearnedSection takes a whole TripConclusions, not its fields one
      // by one. Losing it here would render the sheet's "learned" section
      // blank for a ride that just stopped, which today it never is.
      final outcome = _outcome(km: 20, energyOutWh: 350, energyInWh: 0);
      final stored = _storedTrip(km: 20, energyOutWh: 350, energyInWh: 0);

      final fromStop = TripSummaryView.fromOutcome(outcome, tripId: 7);
      final fromRow = TripSummaryView.fromStored(stored);

      expect(fromStop.conclusions, isNotNull);
      expect(fromRow.conclusions?.whPerKmBefore, fromStop.conclusions?.whPerKmBefore);
      expect(fromRow.conclusions?.whPerKmAfter, fromStop.conclusions?.whPerKmAfter);
      expect(fromRow.conclusions?.learnedKm, fromStop.conclusions?.learnedKm);
      expect(fromRow.conclusions?.rangeKmAtEnd, fromStop.conclusions?.rangeKmAtEnd);
      expect(fromRow.conclusions?.confidence, fromStop.conclusions?.confidence);
    });

    test('a stored row from before conclusions were kept has none to show', () {
      final ancient = _storedTrip(
        km: 20,
        energyOutWh: 350,
        energyInWh: 0,
        hasConclusions: false,
      );
      expect(TripSummaryView.fromStored(ancient).conclusions, isNull);
    });
  });
}

TripOutcome _outcome({
  required double km,
  required double energyOutWh,
  required double energyInWh,
}) {
  final summary = TripSummary(
    startedAt: DateTime.utc(2026, 3, 1, 8),
    movingDuration: const Duration(minutes: 40),
    totalDuration: const Duration(minutes: 48),
    distanceKm: km,
    maxSpeedKmh: 42,
    energyOutWh: energyOutWh,
    energyInWh: energyInWh,
    startSoc: 90,
    endSoc: 70,
    minPackVoltage: 74.5,
    maxPackVoltage: 82.1,
    maxDischargeCurrent: 18.3,
    maxTemperature: 31.5,
    maxDeltaVolts: 0.042,
    climbM: 120,
    descentM: 95,
  );
  const conclusions = TripConclusions(
    whPerKmBefore: 22.0,
    whPerKmAfter: 21.5,
    learnedKm: 340,
    rangeKmAtEnd: 55,
    confidence: RangeConfidence.medium,
  );
  return TripOutcome(summary: summary, conclusions: conclusions);
}

Trip _storedTrip({
  required double km,
  required double energyOutWh,
  required double energyInWh,
  bool? representative,
  bool hasConclusions = true,
}) {
  return Trip(
    id: 7,
    startedAt: DateTime.utc(2026, 3, 1, 8),
    endedAt: DateTime.utc(2026, 3, 1, 8, 48),
    distanceKm: km,
    movingSeconds: const Duration(minutes: 40).inSeconds,
    totalSeconds: const Duration(minutes: 48).inSeconds,
    maxSpeedKmh: 42,
    energyOutWh: energyOutWh,
    energyInWh: energyInWh,
    startSoc: 90,
    endSoc: 70,
    minPackVoltage: 74.5,
    maxPackVoltage: 82.1,
    maxDischargeCurrent: 18.3,
    maxTemperature: 31.5,
    maxDeltaVolts: 0.042,
    climbM: 120,
    descentM: 95,
    note: '',
    demo: false,
    whPerKmBefore: hasConclusions ? 22.0 : null,
    whPerKmAfter: hasConclusions ? 21.5 : null,
    learnedKm: hasConclusions ? 340 : null,
    rangeKmAtEnd: hasConclusions ? 55 : null,
    confidence: hasConclusions ? RangeConfidence.medium.name : null,
    representative: representative,
    summarySeen: false,
  );
}
