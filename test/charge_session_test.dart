import 'package:flutter_test/flutter_test.dart';
import 'package:jk_bms/src/metrics/charge_session.dart';
import 'package:jk_bms/src/model/bms_snapshot.dart';
import 'package:jk_bms/src/model/bms_warning.dart';
import 'package:jk_bms/src/protocol/protocol_variant.dart';

BmsSnapshot snap(
  DateTime at, {
  double current = 12,
  double soc = 50,
  double baseCell = 3.8,
  double delta = 0.008,
  int weakIndex = 6,
  bool balancing = false,
}) {
  final cells = List.filled(20, baseCell + delta);
  cells[weakIndex] = baseCell;
  return BmsSnapshot(
    timestamp: at,
    variant: JkProtocolVariant.jk02_24s,
    frameCounter: 1,
    cellVoltages: cells,
    cellResistances: List.filled(20, 0.0025),
    enabledCellMask: 0xFFFFF,
    packVoltage: cells.reduce((a, b) => a + b),
    current: current,
    temperatures: const [25, 24],
    temperatureSensorMask: 7,
    mosfetTemp: 27,
    soc: soc,
    soh: 97,
    remainingCapacityAh: 45 * soc / 100,
    nominalCapacityAh: 45,
    cycleCount: 60,
    cycleCapacityAh: 2700,
    balancingAction: balancing ? 1 : 0,
    balanceCurrent: balancing ? 0.5 : 0,
    chargeMosfetOn: true,
    dischargeMosfetOn: true,
    balancerActive: balancing,
    heatingOn: false,
    warnings: BmsWarnings.none,
    wireResistanceWarningMask: 0,
    heatingCurrent: 0,
    totalRuntimeSeconds: 3600,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 22);

  group('ChargeSessionRecorder', () {
    test('ignores a pack that is not charging', () {
      final r = ChargeSessionRecorder();
      expect(r.addSnapshot(snap(t0, current: -20)), isNull);
      expect(r.isRecording, isFalse);
    });

    test('starts when current begins flowing in', () {
      final r = ChargeSessionRecorder();
      r.addSnapshot(snap(t0, current: 12));
      expect(r.isRecording, isTrue);
    });

    test('says nothing about a two-minute top-up', () {
      final r = ChargeSessionRecorder();
      r.addSnapshot(snap(t0, soc: 60));
      r.addSnapshot(snap(t0.add(const Duration(minutes: 2)), soc: 61));
      final report =
          r.addSnapshot(snap(t0.add(const Duration(minutes: 3)), current: 0));
      expect(report, isNull);
    });

    test('reports a full charge, with amp-hours in', () {
      final r = ChargeSessionRecorder();
      var at = t0;
      // 12 A for one hour, in ten-second slices.
      for (var i = 0; i <= 360; i++) {
        r.addSnapshot(
          snap(at, current: 12, soc: 40 + i / 360 * 50, baseCell: 3.8),
        );
        at = at.add(const Duration(seconds: 10));
      }
      final report = r.addSnapshot(snap(at, current: 0, soc: 90));

      expect(report, isNotNull);
      expect(report!.ahIn, closeTo(12, 0.2));
      expect(report.startSoc, 40);
      expect(report.endSoc, 90);
      expect(report.peakCurrent, 12);
    });

    test('says when the charge never reached the revealing part', () {
      final r = ChargeSessionRecorder();
      var at = t0;
      // Stops at 3.9 V per cell, below the high-voltage mark.
      for (var i = 0; i <= 60; i++) {
        r.addSnapshot(snap(at, soc: 40 + i.toDouble(), baseCell: 3.85));
        at = at.add(const Duration(seconds: 30));
      }
      final report = r.addSnapshot(snap(at, current: 0, soc: 90));

      expect(report!.reachedTop, isFalse);
      expect(report.spreadOpened, isNull);
    });

    test('catches a spread that only opens near the top', () {
      final r = ChargeSessionRecorder();
      var at = t0;

      // Most of the charge: cells within 8 mV of each other.
      for (var i = 0; i < 60; i++) {
        r.addSnapshot(snap(at, soc: 40 + i.toDouble(), baseCell: 3.7));
        at = at.add(const Duration(seconds: 30));
      }
      // Above 4.0 V the weak cell falls behind badly.
      for (var i = 0; i < 30; i++) {
        r.addSnapshot(
          snap(at, soc: 95, baseCell: 4.05, delta: 0.090, weakIndex: 6),
        );
        at = at.add(const Duration(seconds: 30));
      }
      final report = r.addSnapshot(snap(at, current: 0, soc: 100));

      expect(report!.reachedTop, isTrue);
      expect(report.deltaAtStart, lessThan(0.02));
      expect(report.worstDeltaHigh, closeTo(0.090, 0.001));
      expect(report.spreadOpened, greaterThan(0.05));
      // The signature of capacity mismatch rather than a bad connection.
      expect(report.opensAtTop, isTrue);
      // Cell 7, 1-based, is the one holding the pack back.
      expect(report.weakCellAtTop, 7);
    });

    test('does not call an already-wide pack a top-of-charge problem', () {
      final r = ChargeSessionRecorder();
      var at = t0;
      // Wide from the very beginning: that is resistance, not capacity.
      for (var i = 0; i < 60; i++) {
        r.addSnapshot(snap(at, soc: 40 + i.toDouble(), delta: 0.060));
        at = at.add(const Duration(seconds: 30));
      }
      for (var i = 0; i < 20; i++) {
        r.addSnapshot(snap(at, soc: 98, baseCell: 4.05, delta: 0.070));
        at = at.add(const Duration(seconds: 30));
      }
      final report = r.addSnapshot(snap(at, current: 0, soc: 100));

      expect(report!.opensAtTop, isFalse);
    });

    test('counts how long the balancer worked', () {
      final r = ChargeSessionRecorder();
      var at = t0;
      for (var i = 0; i < 40; i++) {
        r.addSnapshot(
          snap(at, soc: 60 + i.toDouble(), baseCell: 4.05, balancing: true),
        );
        at = at.add(const Duration(seconds: 30));
      }
      final report = r.addSnapshot(snap(at, current: 0, soc: 100));

      expect(report!.balancerWorkedSeconds, greaterThan(1000));
    });

    test('does not integrate across a long gap', () {
      final r = ChargeSessionRecorder();
      r.addSnapshot(snap(t0, soc: 40));
      // An hour of silence: the app was closed.
      r.addSnapshot(snap(t0.add(const Duration(hours: 1)), soc: 80));
      final report = r.addSnapshot(
        snap(t0.add(const Duration(hours: 1, minutes: 1)), current: 0, soc: 80),
      );

      // Charge did move, so there is a report, but no invented amp-hours.
      expect(report, isNotNull);
      expect(report!.ahIn, closeTo(0, 0.01));
    });
  });
}
