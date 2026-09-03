import '../model/bms_snapshot.dart';

/// Where the guided test is.
///
/// The connection step of the PRD is implicit: a session only exists once
/// readings are arriving. Everything after that is driven by the current the
/// BMS reports, never by a "next" button.
enum InspectionStep {
  /// "Don't touch anything." Cells settle; the resting picture is taken.
  rest,

  /// "Turn the lights on." A small, steady draw: does the BMS report current
  /// at all, and does any cell fall over with almost nothing asked of it.
  lightLoad,

  /// "Now pull hard": rear wheel in the air and throttle, fifty metres down
  /// the road, or the charger for half a minute. Per-cell sag is where the
  /// truth comes out.
  heavyLoad,

  /// "Let go and wait." How fast each cell climbs back to where it rested.
  recovery,

  /// Enough has been seen. The result is ready to compute.
  done,
}

/// Every number the guided test keys off, named and in one place.
///
/// Starting points, not findings. The PRD says these get calibrated against
/// the author's own bike and packs known to be good and bad, and marks the
/// lights current, the free-wheel current and the sag outlier as VERIFY.
/// Until then they are deliberately generous about what counts as load and
/// conservative about what counts as a fault.
class InspectionThresholds {
  const InspectionThresholds({
    this.restSeconds = 30,
    this.restCurrentAmps = 1.0,
    this.lightLoadMinAmps = 1.0,
    this.lightLoadSeconds = 15,
    this.heavyLoadMinAmps = 15.0,
    this.heavyLoadSeconds = 5,
    this.recoverySeconds = 45,
    this.recoverySettleVolts = 0.005,
    this.stepTimeoutSeconds = 120,
    this.minimumStepAmps = 3.0,
    this.sagWatchVolts = 0.040,
    this.sagProblemVolts = 0.080,
    this.lightSagWatchVolts = 0.030,
    this.restDeltaWatchVolts = 0.030,
    this.restDeltaProblemVolts = 0.060,
    this.recoverySlowSeconds = 15,
    this.hotCelsius = 45,
  });

  static const InspectionThresholds defaults = InspectionThresholds();

  /// How long the pack has to sit quiet before the resting picture counts.
  final int restSeconds;

  /// Below this, in either direction, the pack is at rest.
  final double restCurrentAmps;

  /// A draw at least this big counts as the lights being on. 72 V lights
  /// pull one to two amps; VERIFY on the Yoazaky.
  final double lightLoadMinAmps;
  final int lightLoadSeconds;

  /// A draw at least this big counts as the hard pull. Free-wheel on the
  /// stand is expected to land here; VERIFY.
  final double heavyLoadMinAmps;
  final int heavyLoadSeconds;

  /// How long to watch the cells climb back after the load is released.
  final int recoverySeconds;

  /// A cell is back once it is within this of where it rested.
  final double recoverySettleVolts;

  /// A step that waits this long for its load is skipped, and the result
  /// says so. Better an honest gap than a test that never ends in the
  /// street.
  final int stepTimeoutSeconds;

  /// The current step between rest and load below which a resistance figure
  /// is noise rather than a measurement.
  final double minimumStepAmps;

  /// A cell sagging this much more than the median under the hard pull is
  /// worth a look, and this much more is a problem. VERIFY against real
  /// packs before trusting either.
  final double sagWatchVolts;
  final double sagProblemVolts;

  /// A cell that falls this far behind the median with only the lights on
  /// has almost nothing asked of it and is already giving up.
  final double lightSagWatchVolts;

  /// Spread between cells with no current flowing.
  final double restDeltaWatchVolts;
  final double restDeltaProblemVolts;

  /// A cell taking this much longer than the median to climb back is tired.
  final int recoverySlowSeconds;

  final double hotCelsius;
}

/// What the screen shows about the step in progress.
class InspectionPrompt {
  const InspectionPrompt({
    required this.step,
    required this.currentAmps,
    required this.loadDetected,
    required this.secondsLeft,
    required this.progress,
    required this.elapsedInStep,
  });

  final InspectionStep step;

  /// Discharge current as a positive number, the way a person reads it.
  final double currentAmps;

  /// Whether the load the step asks for is present right now.
  final bool loadDetected;

  /// Seconds still needed with the condition held, when it is being held.
  final int secondsLeft;

  /// 0..1 through the current step.
  final double progress;

  /// How long the step has been open, for the timeout hint.
  final Duration elapsedInStep;
}

/// One captured reading, with only what the analysis needs.
///
/// The full snapshot is kept in the buffer as well; this is the row the
/// result stores so an inspection can be re-read months later without
/// keeping 300-byte frames for a pack that is not the rider's.
class InspectionSample {
  const InspectionSample({
    required this.at,
    required this.step,
    required this.current,
    required this.cells,
    required this.maxTemperature,
    required this.faults,
  });

  final DateTime at;
  final InspectionStep step;
  final double current;
  final List<double> cells;
  final double? maxTemperature;

  /// Fault bits active on this reading, by name.
  final List<String> faults;

  Map<String, Object?> toJson() => {
    't': at.toIso8601String(),
    's': step.name,
    'i': double.parse(current.toStringAsFixed(2)),
    'c': [for (final v in cells) double.parse(v.toStringAsFixed(3))],
    if (maxTemperature != null)
      'T': double.parse(maxTemperature!.toStringAsFixed(1)),
    if (faults.isNotEmpty) 'f': faults,
  };

  static InspectionSample fromJson(Map<String, Object?> m) => InspectionSample(
    at: DateTime.parse(m['t'] as String),
    step: InspectionStep.values.firstWhere(
      (s) => s.name == m['s'],
      orElse: () => InspectionStep.rest,
    ),
    current: (m['i'] as num).toDouble(),
    cells: [for (final v in m['c'] as List<dynamic>) (v as num).toDouble()],
    maxTemperature: (m['T'] as num?)?.toDouble(),
    faults: [
      for (final f in (m['f'] as List<dynamic>?) ?? const []) f as String,
    ],
  );
}

/// The guided quick test, as a state machine over readings.
///
/// The user only executes: the screen shows one instruction in large letters
/// and this advances by itself when the BMS reports that the step happened.
/// Everything is buffered and the analysis runs at the end, because a
/// one-hertz stream is too thin to judge as it goes and a stranger's pack
/// deserves the same arithmetic every time.
///
/// Pure Dart, no timers. Time is read off the snapshots' phone timestamps,
/// so the whole flow can be tested with synthetic readings and so a link
/// that stalls does not silently advance a step nothing was measured in.
class InspectionSession {
  InspectionSession({this.thresholds = InspectionThresholds.defaults});

  final InspectionThresholds thresholds;

  final List<InspectionSample> _samples = [];
  final List<InspectionStep> _skipped = [];

  InspectionStep _step = InspectionStep.rest;
  DateTime? _startedAt;
  DateTime? _stepStartedAt;

  /// When the step's condition began being met continuously, or null.
  DateTime? _heldSince;

  /// When the hard pull was released, for the recovery clock.
  DateTime? _releasedAt;

  double _peakDischargeAmps = 0;
  BmsSnapshot? _last;

  InspectionStep get step => _step;
  bool get isDone => _step == InspectionStep.done;
  DateTime? get startedAt => _startedAt;
  List<InspectionSample> get samples => List.unmodifiable(_samples);

  /// Steps that timed out waiting for their load. The result's fidelity
  /// caveats come from here.
  List<InspectionStep> get skippedSteps => List.unmodifiable(_skipped);

  double get peakDischargeAmps => _peakDischargeAmps;

  /// What the screen should say right now.
  InspectionPrompt? get prompt {
    final last = _last;
    final stepStart = _stepStartedAt;
    if (last == null || stepStart == null) return null;
    final th = thresholds;
    final amps = _dischargeAmps(last);
    final held = _heldSince;
    final needed = switch (_step) {
      InspectionStep.rest => th.restSeconds,
      InspectionStep.lightLoad => th.lightLoadSeconds,
      InspectionStep.heavyLoad => th.heavyLoadSeconds,
      InspectionStep.recovery => th.recoverySeconds,
      InspectionStep.done => 0,
    };
    final since = _step == InspectionStep.recovery ? _releasedAt : held;
    final heldFor = since == null
        ? 0.0
        : last.timestamp.difference(since).inMilliseconds / 1000;
    final left = (needed - heldFor).clamp(0, needed).ceil();
    return InspectionPrompt(
      step: _step,
      currentAmps: amps,
      loadDetected: _conditionMet(last),
      secondsLeft: left,
      progress: needed == 0 ? 1 : (heldFor / needed).clamp(0.0, 1.0),
      elapsedInStep: last.timestamp.difference(stepStart),
    );
  }

  /// Feeds one reading. Returns true when the test has just finished.
  bool feed(BmsSnapshot s) {
    if (_step == InspectionStep.done) return false;
    _startedAt ??= s.timestamp;
    _stepStartedAt ??= s.timestamp;
    _last = s;

    final amps = _dischargeAmps(s);
    if (amps > _peakDischargeAmps) _peakDischargeAmps = amps;

    _samples.add(
      InspectionSample(
        at: s.timestamp,
        step: _step,
        current: s.current,
        cells: List<double>.from(s.cellVoltages),
        maxTemperature: s.plausibleTemperatures.isEmpty
            ? null
            : s.plausibleTemperatures.reduce((a, b) => a > b ? a : b),
        faults: [for (final w in s.warnings.faults) w.name],
      ),
    );

    final th = thresholds;
    switch (_step) {
      case InspectionStep.rest:
        // Rest has to be continuous. A vendor revving the throttle while the
        // app asks for quiet restarts the clock rather than poisoning the
        // resting picture with a sagging cell.
        _track(s, met: amps < th.restCurrentAmps);
        if (_heldForSeconds(s) >= th.restSeconds) {
          _advance(s, InspectionStep.lightLoad);
        }
      case InspectionStep.lightLoad:
        // A hard pull straight away is not a failure of the light step: the
        // user went past it, and the heavy step takes over.
        if (amps >= th.heavyLoadMinAmps) {
          _advance(s, InspectionStep.heavyLoad);
          _track(s, met: true);
          break;
        }
        _track(s, met: amps >= th.lightLoadMinAmps);
        if (_heldForSeconds(s) >= th.lightLoadSeconds) {
          _advance(s, InspectionStep.heavyLoad);
        } else if (_timedOut(s)) {
          _skip(s, InspectionStep.heavyLoad);
        }
      case InspectionStep.heavyLoad:
        _track(s, met: amps >= th.heavyLoadMinAmps);
        if (_heldForSeconds(s) >= th.heavyLoadSeconds) {
          _advance(s, InspectionStep.recovery);
        } else if (_timedOut(s)) {
          _skip(s, InspectionStep.recovery);
        }
      case InspectionStep.recovery:
        // The recovery clock runs from the moment the load is gone. Load
        // coming back restarts it: a cell cannot be timed climbing while
        // somebody is still pulling on it.
        if (amps < th.restCurrentAmps) {
          _releasedAt ??= s.timestamp;
        } else {
          _releasedAt = null;
        }
        final released = _releasedAt;
        if (released != null &&
            s.timestamp.difference(released).inSeconds >= th.recoverySeconds) {
          _advance(s, InspectionStep.done);
          return true;
        }
        // A pack that never goes quiet again is still worth a verdict.
        if (_timedOut(s) && released == null) {
          _skip(s, InspectionStep.done);
          return true;
        }
      case InspectionStep.done:
        break;
    }
    return false;
  }

  /// Gives up on the current step's load and moves on, recording the skip.
  ///
  /// For the vendor who cannot produce the load the step asks for: a bike
  /// whose controller cuts the throttle on the stand, a pack with no charger
  /// to hand. The verdict then says what was not measured.
  void skipStep() {
    final last = _last;
    if (_step == InspectionStep.done || last == null) return;
    _skip(last, _next(_step));
  }

  /// Ends the test where it is. Whatever was not measured is reported as
  /// such rather than guessed.
  void abortToDone() {
    if (_step == InspectionStep.done) return;
    for (var s = _step; s != InspectionStep.done; s = _next(s)) {
      _skipped.add(s);
    }
    _step = InspectionStep.done;
  }

  // --- internals ---

  bool _conditionMet(BmsSnapshot s) {
    final amps = _dischargeAmps(s);
    final th = thresholds;
    return switch (_step) {
      InspectionStep.rest => amps < th.restCurrentAmps,
      InspectionStep.lightLoad => amps >= th.lightLoadMinAmps,
      InspectionStep.heavyLoad => amps >= th.heavyLoadMinAmps,
      InspectionStep.recovery => amps < th.restCurrentAmps,
      InspectionStep.done => true,
    };
  }

  void _track(BmsSnapshot s, {required bool met}) {
    if (met) {
      _heldSince ??= s.timestamp;
    } else {
      _heldSince = null;
    }
  }

  double _heldForSeconds(BmsSnapshot s) {
    final since = _heldSince;
    if (since == null) return 0;
    return s.timestamp.difference(since).inMilliseconds / 1000;
  }

  bool _timedOut(BmsSnapshot s) {
    final start = _stepStartedAt;
    return start != null &&
        s.timestamp.difference(start).inSeconds >=
            thresholds.stepTimeoutSeconds;
  }

  void _advance(BmsSnapshot s, InspectionStep to) {
    _step = to;
    _stepStartedAt = s.timestamp;
    _heldSince = null;
    _releasedAt = null;
  }

  void _skip(BmsSnapshot s, InspectionStep to) {
    _skipped.add(_step);
    _advance(s, to);
  }

  static InspectionStep _next(InspectionStep s) => switch (s) {
    InspectionStep.rest => InspectionStep.lightLoad,
    InspectionStep.lightLoad => InspectionStep.heavyLoad,
    InspectionStep.heavyLoad => InspectionStep.recovery,
    InspectionStep.recovery => InspectionStep.done,
    InspectionStep.done => InspectionStep.done,
  };

  /// Discharge as a positive figure. The parser's sign convention has
  /// discharge negative; a charger plugged in for the hard-pull step reads
  /// positive, and the PRD accepts that as a load too, so the magnitude is
  /// what the steps key off.
  static double _dischargeAmps(BmsSnapshot s) => s.current.abs();
}
