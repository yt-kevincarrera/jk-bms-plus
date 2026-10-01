import 'dart:math' as math;

import 'inspection_session.dart';

/// The one word at the top of the verdict screen.
/// The headline. Four states, not three, and the fourth exists because a test
/// that measured nothing used to come out green.
///
/// The verdict starts at good and rises only when a finding fires, and nothing
/// can fire on data that was never captured. A real inspection of a real pack
/// ran for 318 seconds, recorded both "not measured" caveats and a null median
/// sag, and showed a green light. For a tool whose whole purpose is not buying
/// a battery blind, that is the worst answer it can give.
enum InspectionLight {
  /// Nothing was found wrong, and enough was measured for that to mean
  /// something.
  good,

  watch,

  problem,

  /// The test never got the load it needed, so there is no opinion here about
  /// the pack in either direction. Not a fourth colour on the same scale as
  /// the others: it is a statement about the test, not about the battery.
  unmeasured,
}

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

  /// No hard pull happened, so there was nothing to recover from. Kept apart
  /// from [noRecovery]: "the load was never released" about a load that never
  /// came is a sentence about something that did not happen.
  recoveryNoLoad,

  /// The rider ended the test before the hard pull.
  endedBeforeLoad,

  /// The rider ended the test while the cells were still climbing back.
  endedBeforeRecovery,

  /// The link dropped while the cells were climbing back, so the times are
  /// the length of the outage rather than anything the cells did.
  recoveryLinkGap,

  /// The link dropped at least once during the test. The steps it fell in
  /// started their clocks again, and the verdict says so.
  linkGaps,

  /// The step between rest and load was too small for a resistance figure.
  currentStepTooSmall,

  /// Fewer readings than the analysis wants.
  fewReadings,

  /// The hard pull was a charger rather than a load. A valid way to move the
  /// current, and worth saying out loud: the cells were lifted rather than
  /// pulled down, and a buyer reading the sheet should know which.
  heavyWasCharge,
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
    this.cycleCapacityAh,
    this.soc,
    this.soh,
  });

  final String model;
  final String serialNumber;
  final String softwareVersion;
  final int? cycleCount;

  /// What the BMS is configured to hold, as the status frame reports it.
  final double? configuredCapacityAh;

  /// Every amp-hour the BMS has counted through the pack, ever. Like the
  /// cycle count it only goes up by itself, and unlike it an ANT keeps one.
  /// Null on runs saved before it was recorded.
  final double? cycleCapacityAh;
  final double? soc;
  final double? soh;

  Map<String, Object?> toJson() => {
    'model': model,
    'serial': serialNumber,
    'sw': softwareVersion,
    'cycles': cycleCount,
    'capAh': configuredCapacityAh,
    // Left out when unknown rather than written as null, so a certificate
    // payload from a run without it reads exactly as it did before.
    if (cycleCapacityAh != null) 'cycAh': cycleCapacityAh,
    'soc': soc,
    'soh': soh,
  };

  static ReportedFigures fromJson(Map<String, Object?> m) => ReportedFigures(
    model: (m['model'] as String?) ?? '',
    serialNumber: (m['serial'] as String?) ?? '',
    softwareVersion: (m['sw'] as String?) ?? '',
    cycleCount: (m['cycles'] as num?)?.toInt(),
    configuredCapacityAh: (m['capAh'] as num?)?.toDouble(),
    cycleCapacityAh: (m['cycAh'] as num?)?.toDouble(),
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
    this.maxTemperatureStep,
    this.faultsSeen = const [],
    this.durationSeconds = 0,
    this.readings = 0,
    this.simulated,
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

  /// Typical draw in the held hard-pull window minus rest: what the sag was
  /// over. The median of the held window; runs saved by older versions carry
  /// the mean of every reading above the bar instead.
  final double currentStepAmps;

  final double? medianHeavySagVolts;
  final double? medianResistanceOhms;
  final double? medianRecoverySeconds;

  /// The hottest battery probe reading of the test. Battery probes only.
  final double? maxTemperature;

  /// The step that hottest reading was taken in, so the sentence about it
  /// can say when. Null on runs saved before it was recorded.
  final InspectionStep? maxTemperatureStep;

  /// Fault names active at any point during the test, deduplicated.
  final List<String> faultsSeen;

  final List<InspectionCaveat> caveats;
  final ReportedFigures reported;
  final int durationSeconds;
  final int readings;

  /// Whether the pack under test was the app's own simulator.
  ///
  /// Null on runs, and certificates, made before it was recorded: unknown,
  /// not "real". A rehearsal against the demo pack produces a perfectly
  /// ordinary looking result, and before this was carried a signed
  /// certificate of the simulator verified exactly like one of a battery.
  final bool? simulated;

  bool get hasHeavyLoad => !caveats.contains(InspectionCaveat.noHeavyLoad);

  /// The hard pull was a charger, so the cells rose instead of falling.
  bool get heavyWasCharge => caveats.contains(InspectionCaveat.heavyWasCharge);

  /// The worst cell's extra sag over the median, as a resistance: the extra
  /// sag divided by the current it was pulled at. The same figure means the
  /// same fault whatever the pull was, which millivolts do not.
  double? get worstExcessOhms {
    final excess = worstSagExcess;
    if (excess == null || currentStepAmps <= 0) return null;
    return excess / currentStepAmps;
  }

  /// The least extra resistance a cell could have had and still stood out
  /// from noise at the current this test pulled.
  double? detectionFloorOhms(double resolutionVolts) =>
      currentStepAmps <= 0 || !hasHeavyLoad
      ? null
      : resolutionVolts / currentStepAmps;

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
    if (maxTemperatureStep != null) 'maxTStep': maxTemperatureStep!.name,
    'faults': faultsSeen,
    'caveats': [for (final c in caveats) c.name],
    'reported': reported.toJson(),
    'seconds': durationSeconds,
    'readings': readings,
    if (simulated != null) 'demo': simulated,
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
    maxTemperatureStep: InspectionStep.values
        .where((s) => s.name == m['maxTStep'])
        .firstOrNull,
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
    simulated: m['demo'] as bool?,
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
    bool? simulated,
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
        simulated: simulated,
      );
    }

    final cellCount = samples.map((s) => s.cells.length).reduce(math.max);
    final consistent = samples
        .where((s) => s.cells.length == cellCount)
        .toList();
    if (consistent.length < 10) caveats.add(InspectionCaveat.fewReadings);

    final gaps = _gapsBetween(consistent, 0, consistent.length - 1, th);
    if (gaps > 0) caveats.add(InspectionCaveat.linkGaps);

    // --- Rest: the quiet readings of the rest step ---
    var rest = consistent
        .where(
          (s) =>
              s.step == InspectionStep.rest &&
              s.current.abs() < th.restCurrentAmps,
        )
        .toList();
    if (rest.length < th.minimumStepReadings) {
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
              s.current.abs() >= session.lightLoadAmps,
        )
        .toList();
    List<double>? lightSag;
    double? lightAmps;
    if (light.length >= th.minimumStepReadings &&
        !session.skippedSteps.contains(InspectionStep.lightLoad)) {
      final lightCells = _medianPerCell(light, cellCount);
      lightSag = [
        for (var i = 0; i < cellCount; i++) restCells[i] - lightCells[i],
      ];
      lightAmps = _mean(light.map((s) => s.current.abs()));
    } else {
      caveats.add(InspectionCaveat.noLightLoad);
    }

    // --- Heavy load: the held window, and only the held window ---
    //
    // The tail of the heavy step over which the current stayed above the bar
    // without a break and without a hole in the link: the readings the step
    // actually completed on. Every reading above the bar used to count, so
    // the two readings of a wheel spinning down on a stand at 14 A sat in
    // the same window as the pull itself.
    final window = session.skippedSteps.contains(InspectionStep.heavyLoad)
        ? null
        : _heldWindow(consistent, session.heavyLoadAmps, th);
    List<double>? heavySag;
    List<double?>? resistance;
    var stepAmps = 0.0;
    double? medianSag;
    double? medianIr;
    var heavyWasCharge = false;
    if (window != null) {
      final held = consistent.sublist(window.$1, window.$2 + 1);
      // Which way the current was flowing. The PRD offers a charger as the
      // load for a vendor with no room to ride, and a charge moves a cell the
      // other way for the same reason a discharge moves it: current through
      // the same internal resistance. So the measurement is the size of the
      // excursion, taken on the side the current puts it.
      heavyWasCharge = _median([for (final s in held) s.current]) > 0;
      if (heavyWasCharge) caveats.add(InspectionCaveat.heavyWasCharge);
      double sagOf(InspectionSample s, int i) => heavyWasCharge
          ? s.cells[i] - restCells[i]
          : restCells[i] - s.cells[i];

      // Each cell's sag is the median of its own sag reading by reading, not
      // its single lowest reading. The lowest of each cell came from whichever
      // frame happened to catch it lowest, so twenty cells were compared at
      // twenty different instants and one glitched frame set a cell's figure
      // by itself.
      heavySag = [
        for (var i = 0; i < cellCount; i++)
          _median([for (final s in held) sagOf(s, i)]),
      ];
      medianSag = _median(heavySag);
      stepAmps = _median([for (final s in held) s.current.abs() - restAmps]);

      if (stepAmps >= th.minimumStepAmps) {
        // Resistance is worked out frame by frame, each frame's sag over that
        // frame's own current, and only on frames whose current is fresh. The
        // BMS repeats a current value across consecutive frames while the
        // cell voltages move on, so a repeated current is often an old figure
        // paired with new voltages: the current and the cells in one snapshot
        // are not always the same instant. When the current never changes at
        // all (a charger holding its setpoint) the repeat is the load holding
        // steady, and every frame counts.
        var paired = [
          for (var k = window.$1; k <= window.$2; k++)
            if (k == 0 || consistent[k].current != consistent[k - 1].current)
              consistent[k],
        ];
        if (paired.length < 3) paired = held;
        resistance = [
          for (var i = 0; i < cellCount; i++)
            math.max(
              0.0,
              _median([
                for (final s in paired)
                  if (s.current.abs() - restAmps > 0)
                    sagOf(s, i) / (s.current.abs() - restAmps),
              ]),
            ),
        ];
        medianIr = _median(resistance.whereType<double>().toList());
      } else {
        caveats.add(InspectionCaveat.currentStepTooSmall);
      }
    } else {
      caveats.add(InspectionCaveat.noHeavyLoad);
    }

    // Ended by the rider before the load: one sentence that says so, instead
    // of "the load was never released" about a load that never came.
    final endedIn = session.endedEarlyIn;
    final endedBeforeLoad =
        heavySag == null &&
        (endedIn == InspectionStep.rest ||
            endedIn == InspectionStep.lightLoad ||
            endedIn == InspectionStep.heavyLoad);
    if (endedBeforeLoad) caveats.add(InspectionCaveat.endedBeforeLoad);

    // --- Recovery: time for each cell to climb back after release ---
    //
    // Only after a hard pull that was actually measured. Without one the
    // cells are timed climbing back to where they already are, every one of
    // them makes it in 0 s, and the verdict praised an even recovery from a
    // load nobody applied.
    List<double?>? recovery;
    List<bool>? recovered;
    double? medianRecovery;
    if (heavySag == null) {
      if (!endedBeforeLoad) caveats.add(InspectionCaveat.recoveryNoLoad);
    } else if (session.skippedSteps.contains(InspectionStep.recovery)) {
      caveats.add(
        endedIn == InspectionStep.recovery
            ? InspectionCaveat.endedBeforeRecovery
            : InspectionCaveat.noRecovery,
      );
    } else {
      final (outcome, times, back) = _recovery(
        consistent,
        restCells,
        heavyWasCharge,
        th,
      );
      switch (outcome) {
        case _Recovery.tooFew:
          caveats.add(InspectionCaveat.noRecovery);
        case _Recovery.linkGap:
          caveats.add(InspectionCaveat.recoveryLinkGap);
        case _Recovery.measured:
          recovery = times;
          recovered = back;
          medianRecovery = _median(times!.whereType<double>().toList());
      }
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

    InspectionSample? hottest;
    for (final s in consistent) {
      final t = s.maxTemperature;
      if (t != null && (hottest == null || t > hottest.maxTemperature!)) {
        hottest = s;
      }
    }
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
      maxTemperature: hottest?.maxTemperature,
      maxTemperatureStep: hottest?.step,
      faultsSeen: faults,
      caveats: caveats,
      reported: reported,
      durationSeconds: samples.last.at.difference(samples.first.at).inSeconds,
      readings: samples.length,
      simulated: simulated,
    );
  }

  /// The held window of the hard pull, as first and last index into
  /// [rows], or null when there is none worth measuring.
  ///
  /// The last unbroken run of heavy-step readings at or above the bar: the
  /// run the step completed on. A hole in the link breaks a run the same way
  /// a dip below the bar does, because nothing was seen in between.
  (int, int)? _heldWindow(
    List<InspectionSample> rows,
    double bar,
    InspectionThresholds th,
  ) {
    (int, int)? last;
    int? start;
    for (var k = 0; k < rows.length; k++) {
      final s = rows[k];
      final above =
          s.step == InspectionStep.heavyLoad && s.current.abs() >= bar;
      final broken = start != null && _isGap(rows[k - 1], s, th);
      if (start != null && (!above || broken)) {
        last = (start, k - 1);
        start = null;
      }
      if (above) start ??= k;
    }
    if (start != null) last = (start, rows.length - 1);
    if (last == null || last.$2 - last.$1 + 1 < th.minimumStepReadings) {
      return null;
    }
    return last;
  }

  /// Times each cell back to its resting voltage after the load let go.
  (_Recovery, List<double?>?, List<bool>?) _recovery(
    List<InspectionSample> rows,
    List<double> restCells,
    bool heavyWasCharge,
    InspectionThresholds th,
  ) {
    // The release is the first quiet reading after the last time the load
    // was on. Load coming back during recovery restarts it, as the session's
    // own clock does.
    var first = -1;
    var last = -1;
    for (var k = 0; k < rows.length; k++) {
      final s = rows[k];
      if (s.step != InspectionStep.recovery) continue;
      last = k;
      if (s.current.abs() >= th.restCurrentAmps) {
        first = -1;
      } else if (first < 0) {
        first = k;
      }
    }
    if (first < 0 || last - first + 1 < th.minimumStepReadings) {
      return (_Recovery.tooFew, null, null);
    }
    // A hole right at the release hides when the load let go, and every time
    // measured from the first reading back is short by however long it was.
    if (first > 0 && _isGap(rows[first - 1], rows[first], th)) {
      return (_Recovery.linkGap, null, null);
    }

    final release = rows[first].at;
    final cellCount = restCells.length;
    final times = List<double?>.filled(cellCount, null);
    final back = List<bool>.filled(cellCount, false);
    var settledAt = first;
    for (var i = 0; i < cellCount; i++) {
      // Back to within a whisker of where it rested, from whichever side the
      // load pushed it. One-sided on purpose: a cell that overshoots past
      // rest has plainly recovered. Under a charge that side is the other
      // one, and testing the discharge side there would call every cell
      // recovered on the first reading, since they are all still above rest
      // at that point.
      final target = heavyWasCharge
          ? restCells[i] + th.recoverySettleVolts
          : restCells[i] - th.recoverySettleVolts;
      for (var k = first; k <= last; k++) {
        final v = rows[k].cells[i];
        if (heavyWasCharge ? v <= target : v >= target) {
          times[i] = rows[k].at.difference(release).inMilliseconds / 1000;
          back[i] = true;
          if (k > settledAt) settledAt = k;
          break;
        }
      }
      if (!back[i]) {
        // Never got there: time it at the end of the window, flagged.
        times[i] = rows[last].at.difference(release).inMilliseconds / 1000;
        settledAt = last;
      }
    }
    // A hole before the slowest cell was back means at least one time is the
    // length of the outage. After it, nothing measured was affected.
    if (_gapsBetween(rows, first, settledAt, th) > 0) {
      return (_Recovery.linkGap, null, null);
    }
    return (_Recovery.measured, times, back);
  }

  static bool _isGap(
    InspectionSample a,
    InspectionSample b,
    InspectionThresholds th,
  ) => b.at.difference(a.at).inMilliseconds > th.linkGapSeconds * 1000;

  static int _gapsBetween(
    List<InspectionSample> rows,
    int from,
    int to,
    InspectionThresholds th,
  ) {
    var n = 0;
    for (var k = from + 1; k <= to && k < rows.length; k++) {
      if (_isGap(rows[k - 1], rows[k], th)) n++;
    }
    return n;
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

enum _Recovery {
  measured,

  /// Too few quiet readings after release to time anything.
  tooFew,

  /// The link dropped where it mattered.
  linkGap,
}

double _r(double v, int digits) => double.parse(v.toStringAsFixed(digits));
