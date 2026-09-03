import 'dart:math' as math;

import 'inspection_session.dart';

/// The one word at the top of the verdict screen.
enum InspectionLight { good, watch, problem }

/// Why the result is worth less than a full one. Every caveat is said out
/// loud on the verdict and in the report: the PRD's word for this test is
/// "estimation", and it must never dress up as a measurement.
enum InspectionCaveat {
  /// No load big enough to measure sag was ever seen.
  noHeavyLoad,

  /// The lights step never saw a draw.
  noLightLoad,

  /// The pack never went quiet long enough for a clean resting picture.
  restNoisy,

  /// The load was never released, so nothing recovered.
  noRecovery,

  /// The step between rest and load was too small for a resistance figure.
  currentStepTooSmall,

  /// Fewer readings than the analysis wants.
  fewReadings,
}

/// One cell, through the test.
class CellInspection {
  const CellInspection({
    required this.index,
    required this.restVolts,
    this.lightSagVolts,
    this.heavySagVolts,
    this.resistanceOhms,
    this.recoverySeconds,
    this.recovered = true,
  });

  /// 1-based, the number on the label.
  final int index;

  /// Median voltage at rest.
  final double restVolts;

  /// Drop from rest with the lights on, when that step happened.
  final double? lightSagVolts;

  /// Drop from rest under the hard pull, when that step happened.
  final double? heavySagVolts;

  /// Sag over the current step: an apparent internal resistance, in ohms,
  /// wiring included. Null when the step was too small to divide by.
  final double? resistanceOhms;

  /// Seconds after release until the cell was back within the settle band
  /// of its resting voltage. Null when there was no recovery window.
  final double? recoverySeconds;

  /// False when the cell never got back inside the settle band.
  final bool recovered;

  Map<String, Object?> toJson() => {
    'i': index,
    'rest': _r(restVolts, 3),
    if (lightSagVolts != null) 'light': _r(lightSagVolts!, 3),
    if (heavySagVolts != null) 'heavy': _r(heavySagVolts!, 3),
    if (resistanceOhms != null) 'ir': _r(resistanceOhms!, 4),
    if (recoverySeconds != null) 'rec': _r(recoverySeconds!, 1),
    if (!recovered) 'unrecovered': true,
  };

  static CellInspection fromJson(Map<String, Object?> m) => CellInspection(
    index: m['i'] as int,
    restVolts: (m['rest'] as num).toDouble(),
    lightSagVolts: (m['light'] as num?)?.toDouble(),
    heavySagVolts: (m['heavy'] as num?)?.toDouble(),
    resistanceOhms: (m['ir'] as num?)?.toDouble(),
    recoverySeconds: (m['rec'] as num?)?.toDouble(),
    recovered: m['unrecovered'] != true,
  );
}

/// What the BMS said about itself, carried alongside the physics so the
/// verdict can set one against the other. All of it is editable from the
/// official app, and the screen says so.
class ReportedFigures {
  const ReportedFigures({
    this.model = '',
    this.serialNumber = '',
    this.softwareVersion = '',
    this.cycleCount,
    this.configuredCapacityAh,
    this.soc,
    this.soh,
  });

  final String model;
  final String serialNumber;
  final String softwareVersion;
  final int? cycleCount;
  final double? configuredCapacityAh;
  final double? soc;
  final double? soh;

  Map<String, Object?> toJson() => {
    'model': model,
    'serial': serialNumber,
    'sw': softwareVersion,
    'cycles': cycleCount,
    'capAh': configuredCapacityAh,
    'soc': soc,
    'soh': soh,
  };

  static ReportedFigures fromJson(Map<String, Object?> m) => ReportedFigures(
    model: (m['model'] as String?) ?? '',
    serialNumber: (m['serial'] as String?) ?? '',
    softwareVersion: (m['sw'] as String?) ?? '',
    cycleCount: (m['cycles'] as num?)?.toInt(),
    configuredCapacityAh: (m['capAh'] as num?)?.toDouble(),
    soc: (m['soc'] as num?)?.toDouble(),
    soh: (m['soh'] as num?)?.toDouble(),
  );
}

/// Everything the quick test concluded, with the numbers behind it.
class InspectionResult {
  const InspectionResult({
    required this.at,
    required this.cells,
    required this.restDeltaVolts,
    required this.peakDischargeAmps,
    required this.currentStepAmps,
    required this.caveats,
    required this.reported,
    this.restCurrentAmps = 0,
    this.lightLoadAmps,
    this.medianHeavySagVolts,
    this.medianResistanceOhms,
    this.medianRecoverySeconds,
    this.maxTemperature,
    this.faultsSeen = const [],
    this.durationSeconds = 0,
    this.readings = 0,
  });

  final DateTime at;
  final List<CellInspection> cells;

  /// Spread between cell resting voltages.
  final double restDeltaVolts;

  /// Mean current in the rest window (should be near zero).
  final double restCurrentAmps;

  /// Mean draw with the lights on, when that step happened.
  final double? lightLoadAmps;

  /// The biggest draw seen at any point.
  final double peakDischargeAmps;

  /// Mean draw in the hard-pull window minus rest: what the sag was over.
  final double currentStepAmps;

  final double? medianHeavySagVolts;
  final double? medianResistanceOhms;
  final double? medianRecoverySeconds;
  final double? maxTemperature;

  /// Fault names active at any point during the test, deduplicated.
  final List<String> faultsSeen;

  final List<InspectionCaveat> caveats;
  final ReportedFigures reported;
  final int durationSeconds;
  final int readings;

  bool get hasHeavyLoad => !caveats.contains(InspectionCaveat.noHeavyLoad);

  int get cellCount => cells.length;

  /// The cell that sagged most under the hard pull, or null without one.
  CellInspection? get worstSag {
    final withSag = cells.where((c) => c.heavySagVolts != null).toList();
    if (withSag.isEmpty) return null;
    return withSag.reduce(
      (a, b) => a.heavySagVolts! >= b.heavySagVolts! ? a : b,
    );
  }

  /// Extra sag of the worst cell over the median, in volts.
  double? get worstSagExcess {
    final worst = worstSag;
    final median = medianHeavySagVolts;
    if (worst == null || median == null) return null;
    return worst.heavySagVolts! - median;
  }

  /// The lowest cell at rest, 1-based.
  int get lowestRestCell => cells.isEmpty
      ? 0
      : cells.reduce((a, b) => a.restVolts <= b.restVolts ? a : b).index;

  /// The cell slowest to climb back, when recovery was measured.
  CellInspection? get slowestRecovery {
    final timed = cells.where((c) => c.recoverySeconds != null).toList();
    if (timed.isEmpty) return null;
    return timed.reduce(
      (a, b) => a.recoverySeconds! >= b.recoverySeconds! ? a : b,
    );
  }

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'cells': [for (final c in cells) c.toJson()],
    'restDelta': _r(restDeltaVolts, 3),
    'restAmps': _r(restCurrentAmps, 2),
    'lightAmps': lightLoadAmps == null ? null : _r(lightLoadAmps!, 2),
    'peakAmps': _r(peakDischargeAmps, 1),
    'stepAmps': _r(currentStepAmps, 1),
    'medSag': medianHeavySagVolts == null ? null : _r(medianHeavySagVolts!, 3),
    'medIr': medianResistanceOhms == null ? null : _r(medianResistanceOhms!, 4),
    'medRec': medianRecoverySeconds == null
        ? null
        : _r(medianRecoverySeconds!, 1),
    'maxT': maxTemperature == null ? null : _r(maxTemperature!, 1),
    'faults': faultsSeen,
    'caveats': [for (final c in caveats) c.name],
    'reported': reported.toJson(),
    'seconds': durationSeconds,
    'readings': readings,
  };

  static InspectionResult fromJson(Map<String, Object?> m) => InspectionResult(
    at: DateTime.parse(m['at'] as String),
    cells: [
      for (final c in m['cells'] as List<dynamic>)
        CellInspection.fromJson((c as Map).cast<String, Object?>()),
    ],
    restDeltaVolts: (m['restDelta'] as num).toDouble(),
    restCurrentAmps: ((m['restAmps'] as num?) ?? 0).toDouble(),
    lightLoadAmps: (m['lightAmps'] as num?)?.toDouble(),
    peakDischargeAmps: (m['peakAmps'] as num).toDouble(),
    currentStepAmps: (m['stepAmps'] as num).toDouble(),
    medianHeavySagVolts: (m['medSag'] as num?)?.toDouble(),
    medianResistanceOhms: (m['medIr'] as num?)?.toDouble(),
    medianRecoverySeconds: (m['medRec'] as num?)?.toDouble(),
    maxTemperature: (m['maxT'] as num?)?.toDouble(),
    faultsSeen: [
      for (final f in (m['faults'] as List<dynamic>?) ?? []) f as String,
    ],
    caveats: [
      for (final c in (m['caveats'] as List<dynamic>?) ?? [])
        InspectionCaveat.values.firstWhere(
          (v) => v.name == c,
          orElse: () => InspectionCaveat.fewReadings,
        ),
    ],
    reported: ReportedFigures.fromJson(
      ((m['reported'] as Map?) ?? const {}).cast<String, Object?>(),
    ),
    durationSeconds: ((m['seconds'] as num?) ?? 0).toInt(),
    readings: ((m['readings'] as num?) ?? 0).toInt(),
  );
}

/// Turns a finished session's buffer into a result.
///
/// Runs once, at the end, over everything that was captured. The medians
/// rather than means throughout: a pack under inspection is a pack in a
/// stranger's yard, with a vendor's hand on the throttle, and one wild
/// reading must not move the picture.
class InspectionAnalysis {
  const InspectionAnalysis({this.thresholds = InspectionThresholds.defaults});

  final InspectionThresholds thresholds;

  InspectionResult compute(
    InspectionSession session, {
    ReportedFigures reported = const ReportedFigures(),
  }) {
    final th = thresholds;
    final samples = session.samples;
    final caveats = <InspectionCaveat>[];
    final at = session.startedAt ?? DateTime.now().toUtc();

    if (samples.isEmpty) {
      return InspectionResult(
        at: at,
        cells: const [],
        restDeltaVolts: 0,
        peakDischargeAmps: 0,
        currentStepAmps: 0,
        caveats: const [InspectionCaveat.fewReadings],
        reported: reported,
      );
    }

    final cellCount = samples.map((s) => s.cells.length).reduce(math.max);
    final consistent = samples
        .where((s) => s.cells.length == cellCount)
        .toList();
    if (consistent.length < 10) caveats.add(InspectionCaveat.fewReadings);

    // --- Rest: the quiet readings of the rest step ---
    var rest = consistent
        .where(
          (s) =>
              s.step == InspectionStep.rest &&
              s.current.abs() < th.restCurrentAmps,
        )
        .toList();
    if (rest.length < 5) {
      // Not enough quiet: fall back to the quietest readings anywhere, and
      // say so.
      caveats.add(InspectionCaveat.restNoisy);
      rest = [...consistent]
        ..sort((a, b) => a.current.abs().compareTo(b.current.abs()));
      rest = rest.take(math.max(5, rest.length ~/ 5)).toList();
    }
    final restCells = _medianPerCell(rest, cellCount);
    final restAmps = _mean(rest.map((s) => s.current.abs()));
    final restDelta = restCells.isEmpty
        ? 0.0
        : restCells.reduce(math.max) - restCells.reduce(math.min);

    // --- Light load ---
    final light = consistent
        .where(
          (s) =>
              s.step == InspectionStep.lightLoad &&
              s.current.abs() >= th.lightLoadMinAmps,
        )
        .toList();
    List<double>? lightSag;
    double? lightAmps;
    if (light.isNotEmpty &&
        !session.skippedSteps.contains(InspectionStep.lightLoad)) {
      final lightCells = _medianPerCell(light, cellCount);
      lightSag = [
        for (var i = 0; i < cellCount; i++) restCells[i] - lightCells[i],
      ];
      lightAmps = _mean(light.map((s) => s.current.abs()));
    } else {
      caveats.add(InspectionCaveat.noLightLoad);
    }

    // --- Heavy load: the held window is the tail of the heavy step ---
    final heavy = consistent
        .where(
          (s) =>
              s.step == InspectionStep.heavyLoad &&
              s.current.abs() >= th.heavyLoadMinAmps,
        )
        .toList();
    List<double>? heavySag;
    List<double?>? resistance;
    var stepAmps = 0.0;
    double? medianSag;
    double? medianIr;
    if (heavy.isNotEmpty &&
        !session.skippedSteps.contains(InspectionStep.heavyLoad)) {
      // The lowest each cell went under the pull. Minimum, not median: the
      // sag at the hardest moment is the figure a buyer needs, and every
      // cell is read at the same moments so they stay comparable.
      final heavyMin = List<double>.generate(
        cellCount,
        (i) => heavy.map((s) => s.cells[i]).reduce(math.min),
      );
      heavySag = [
        for (var i = 0; i < cellCount; i++) restCells[i] - heavyMin[i],
      ];
      medianSag = _median(heavySag);
      stepAmps = _mean(heavy.map((s) => s.current.abs())) - restAmps;
      if (stepAmps >= th.minimumStepAmps) {
        resistance = [for (final sag in heavySag) math.max(0, sag) / stepAmps];
        medianIr = _median(resistance.whereType<double>().toList());
      } else {
        caveats.add(InspectionCaveat.currentStepTooSmall);
      }
    } else {
      caveats.add(InspectionCaveat.noHeavyLoad);
    }

    // --- Recovery: time for each cell to climb back after release ---
    List<double?>? recovery;
    List<bool>? recovered;
    double? medianRecovery;
    final release = _releaseMoment(consistent, th);
    if (release != null &&
        !session.skippedSteps.contains(InspectionStep.recovery)) {
      final after = consistent
          .where(
            (s) =>
                s.step == InspectionStep.recovery &&
                !s.at.isBefore(release) &&
                s.current.abs() < th.restCurrentAmps,
          )
          .toList();
      if (after.length >= 3) {
        recovery = List<double?>.filled(cellCount, null);
        recovered = List<bool>.filled(cellCount, false);
        for (var i = 0; i < cellCount; i++) {
          final target = restCells[i] - th.recoverySettleVolts;
          for (final s in after) {
            if (s.cells[i] >= target) {
              recovery[i] = s.at.difference(release).inMilliseconds / 1000;
              recovered[i] = true;
              break;
            }
          }
          // Never got there: time it at the end of the window, flagged.
          recovery[i] ??=
              after.last.at.difference(release).inMilliseconds / 1000;
        }
        medianRecovery = _median(recovery.whereType<double>().toList());
      } else {
        caveats.add(InspectionCaveat.noRecovery);
      }
    } else {
      caveats.add(InspectionCaveat.noRecovery);
    }

    final cells = <CellInspection>[
      for (var i = 0; i < cellCount; i++)
        CellInspection(
          index: i + 1,
          restVolts: restCells[i],
          lightSagVolts: lightSag?[i],
          heavySagVolts: heavySag?[i],
          resistanceOhms: resistance?[i],
          recoverySeconds: recovery?[i],
          recovered: recovered?[i] ?? true,
        ),
    ];

    final temps = consistent.map((s) => s.maxTemperature).whereType<double>();
    final faults = <String>{for (final s in consistent) ...s.faults}.toList()
      ..sort();

    return InspectionResult(
      at: at,
      cells: cells,
      restDeltaVolts: restDelta,
      restCurrentAmps: restAmps,
      lightLoadAmps: lightAmps,
      peakDischargeAmps: session.peakDischargeAmps,
      currentStepAmps: stepAmps,
      medianHeavySagVolts: medianSag,
      medianResistanceOhms: medianIr,
      medianRecoverySeconds: medianRecovery,
      maxTemperature: temps.isEmpty ? null : temps.reduce(math.max),
      faultsSeen: faults,
      caveats: caveats,
      reported: reported,
      durationSeconds: samples.last.at.difference(samples.first.at).inSeconds,
      readings: samples.length,
    );
  }

  /// The first quiet reading of the recovery step.
  static DateTime? _releaseMoment(
    List<InspectionSample> samples,
    InspectionThresholds th,
  ) {
    for (final s in samples) {
      if (s.step == InspectionStep.recovery &&
          s.current.abs() < th.restCurrentAmps) {
        return s.at;
      }
    }
    return null;
  }

  static List<double> _medianPerCell(List<InspectionSample> rows, int n) {
    if (rows.isEmpty) return List<double>.filled(n, 0);
    return List<double>.generate(
      n,
      (i) => _median([for (final s in rows) s.cells[i]]),
    );
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static double _mean(Iterable<double> values) {
    var sum = 0.0;
    var n = 0;
    for (final v in values) {
      sum += v;
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }
}

double _r(double v, int digits) => double.parse(v.toStringAsFixed(digits));
