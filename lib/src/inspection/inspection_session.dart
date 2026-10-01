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
    this.lightLoadStepAmps = 0.25,
    this.lightLoadSeconds = 15,
    this.heavyLoadCRate = 0.10,
    this.heavyLoadFloorAmps = 3.0,
    this.heavyLoadSeconds = 5,
    this.recoverySeconds = 45,
    this.recoverySettleVolts = 0.005,
    this.stepTimeoutSeconds = 120,
    this.minimumStepAmps = 3.0,
    this.sagWatchOhms = 0.0015,
    this.sagProblemOhms = 0.0030,
    this.sagResolutionVolts = 0.005,
    this.linkGapSeconds = 3.0,
    this.minimumStepReadings = 5,
    this.recoveryDiscriminatesCRate = 0.3,
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

  /// How far above rest the current has to step for the lights to count as
  /// on.
  ///
  /// Above rest, not an absolute figure, and this is the whole fix. It used to
  /// be a flat 1.0 A, guessed from "72 V lights pull one to two amps" and
  /// marked VERIFY. Verified at last, against the pack this app was written
  /// for: the lights draw **0.44 A**, flat, and rest is 0.00 A exactly. So the
  /// step timed out after two minutes with the lights plainly on, and the
  /// screen told the rider the pack needed more.
  ///
  /// 0.25 A sits comfortably under that 0.44 A and comfortably over the
  /// current's own resolution, which is a milliamp. And a step above rest
  /// cannot collide with [restCurrentAmps] the way an absolute bar did: at
  /// 1.0 A for both, a 0.44 A load was quiet enough to be rest and too small
  /// to be the lights at the same time.
  final double lightLoadStepAmps;
  final int lightLoadSeconds;

  /// The hard pull, as a fraction of the pack's own configured capacity.
  ///
  /// Also measured rather than guessed. It used to be a flat 15.0 A, which is
  /// 0.375C on a 40 Ah pack and 0.5C on a 30 Ah one: the same number meaning
  /// two different demands. A tenth of C is enough current to move a cell
  /// far enough to measure against a 1 mV reading, and little enough that a
  /// charger can produce it.
  final double heavyLoadCRate;

  /// The least the hard pull may ask for, whatever the C-rate works out to.
  ///
  /// Firmware that leaves the configured capacity at zero would otherwise let
  /// any twitch of current count as a hard pull.
  final double heavyLoadFloorAmps;

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

  /// A cell with this much more resistance than the median cell is worth a
  /// look, and this much more is a problem.
  ///
  /// In ohms, not volts, and that is the fix. These used to be 40 and 80 mV
  /// of extra sag, figures chosen when the hard pull was a flat 15 A. When the
  /// pull became a tenth of C, a 40 Ah pack passed on 4 A, and at 4 A a cell
  /// needs 10 mOhm of extra resistance before it sags 40 mV more than the
  /// others: three or four times what a healthy cell group of this kind has
  /// in total. So a plainly bad cell came out "all cells sag evenly", green.
  /// The same extra sag means four times the fault at a quarter of the
  /// current, and only a resistance says the same thing at any current.
  ///
  /// The measured pack sits near 3 mOhm per cell group (17 mV at 5.5 A on
  /// the real recording), so these are half again and double what a healthy
  /// group carries, on top of it.
  final double sagWatchOhms;
  final double sagProblemOhms;

  /// The smallest difference in sag between two cells this test can tell
  /// from noise.
  ///
  /// The real pack reports its cells in steps of about 2.5 mV, flickering
  /// between neighbouring values at rest, and the worst of twenty such cells
  /// sits a few millivolts above the median from noise alone. Divided by the
  /// current that was pulled, this is the detection floor in ohms: the least
  /// extra resistance a cell can have and still stand out at that load.
  final double sagResolutionVolts;

  /// Two readings further apart than this have a dropped link between them.
  ///
  /// The real link drops for long stretches, and the first reading back after
  /// a thirty-second hole is thirty seconds after the last one. Timing a step
  /// across that hole completes it on one or two readings, and times a
  /// cell's recovery as the length of the outage.
  final double linkGapSeconds;

  /// The fewest readings a step may complete on, whatever the clock says.
  final int minimumStepReadings;

  /// Recovery only tells cells apart when the load was at least this share
  /// of the pack's capacity. Below it every cell, good or tired, is back
  /// within a few millivolts almost at once.
  final double recoveryDiscriminatesCRate;

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
    required this.neededAmps,
    required this.loadDetected,
    required this.secondsLeft,
    required this.progress,
    required this.elapsedInStep,
  });

  final InspectionStep step;

  /// Discharge current as a positive number, the way a person reads it.
  final double currentAmps;

  /// What this step is waiting for, as a magnitude.
  ///
  /// On the screen because "give it more" is not an instruction. A rider told
  /// their 0.44 A was too small, with no idea what would have been big
  /// enough, spent two minutes revving a wheel in the air that was never
  /// going to get there. Zero while the step wants quiet instead of load.
  final double neededAmps;

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
/// so the whole flow can be tested with synthetic readings. A link that
/// stalls does not advance a step nothing was measured in: a hole longer
/// than [InspectionThresholds.linkGapSeconds] between two readings restarts
/// whatever clock was running, and every step also needs a minimum number
/// of readings, not only a minimum time.
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

  /// Readings since [_heldSince], so a step cannot complete on the clock
  /// alone across two readings.
  int _heldFrames = 0;

  /// When the hard pull was released, for the recovery clock.
  DateTime? _releasedAt;
  int _releasedFrames = 0;

  /// How many times the link went quiet for longer than a gap.
  int _gaps = 0;

  /// The step the rider ended the test in, when they ended it early.
  InspectionStep? _endedEarlyIn;

  double _peakDischargeAmps = 0;
  BmsSnapshot? _last;

  /// What the pack was drawing while it sat quiet, as a magnitude.
  ///
  /// Learned rather than assumed, and it is what the light step is judged
  /// against. A bike whose alarm or dash sits on the pack rests at something
  /// other than zero, and "the lights are on" means the current went up from
  /// wherever that was.
  double _restLevelAmps = 0;

  double get restLevelAmps => _restLevelAmps;

  /// The current this pack's hard pull has to reach, worked out from its own
  /// configured capacity once a reading has arrived.
  ///
  /// Exposed so the analysis filters the heavy window on the same figure the
  /// steps advanced on. Two copies of that arithmetic is how a step passes on
  /// screen and then reports nothing measured.
  double get heavyLoadAmps {
    final capacity = _last?.nominalCapacityAh ?? 0;
    final byRate = capacity * thresholds.heavyLoadCRate;
    return byRate > thresholds.heavyLoadFloorAmps
        ? byRate
        : thresholds.heavyLoadFloorAmps;
  }

  /// The current the light step has to reach: a step above where this pack
  /// actually rests.
  double get lightLoadAmps => _restLevelAmps + thresholds.lightLoadStepAmps;

  InspectionStep get step => _step;
  bool get isDone => _step == InspectionStep.done;
  DateTime? get startedAt => _startedAt;
  List<InspectionSample> get samples => List.unmodifiable(_samples);

  /// Steps that timed out waiting for their load. The result's fidelity
  /// caveats come from here.
  List<InspectionStep> get skippedSteps => List.unmodifiable(_skipped);

  double get peakDischargeAmps => _peakDischargeAmps;

  /// Holes in the link the session saw while it was running.
  int get linkGaps => _gaps;

  /// Where "end now" was tapped, or null when the test ran its course. The
  /// verdict says "the test ended before the load" rather than "the load was
  /// never released" about a load that never came.
  InspectionStep? get endedEarlyIn => _endedEarlyIn;

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
      neededAmps: switch (_step) {
        InspectionStep.lightLoad => lightLoadAmps,
        InspectionStep.heavyLoad => heavyLoadAmps,
        InspectionStep.rest ||
        InspectionStep.recovery ||
        InspectionStep.done => 0,
      },
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
    final previous = _last;
    _last = s;

    // A hole in the link. Whatever was being held was not seen being held,
    // so its clock starts again from this reading: the first frame back after
    // a forty-second drop used to complete a five-second step on its own, and
    // stand in for forty seconds of a recovery nobody watched.
    if (previous != null &&
        s.timestamp.difference(previous.timestamp).inMilliseconds >
            thresholds.linkGapSeconds * 1000) {
      _gaps++;
      _heldSince = null;
      _heldFrames = 0;
      _releasedAt = null;
      _releasedFrames = 0;
    }

    final amps = _dischargeAmps(s);
    if (amps > _peakDischargeAmps) _peakDischargeAmps = amps;

    _samples.add(
      InspectionSample(
        at: s.timestamp,
        step: _step,
        current: s.current,
        cells: List<double>.from(s.cellVoltages),
        // Battery probes only: "the pack was hot at rest" must not be the
        // MOSFET talking.
        maxTemperature: s.hottestBatteryTemp,
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
        // Whatever it settled at is what the light step gets measured
        // against, so a bike with something already on the pack is not asked
        // for a load on top of a rest of zero it never had.
        if (amps < th.restCurrentAmps) _restLevelAmps = amps;
        if (_held(s, th.restSeconds)) {
          _advance(s, InspectionStep.lightLoad);
        }
      case InspectionStep.lightLoad:
        // A hard pull straight away is not a failure of the light step: the
        // user went past it, and the heavy step takes over.
        if (amps >= heavyLoadAmps) {
          _advance(s, InspectionStep.heavyLoad);
          _track(s, met: true);
          break;
        }
        _track(s, met: amps >= lightLoadAmps);
        if (_held(s, th.lightLoadSeconds)) {
          _advance(s, InspectionStep.heavyLoad);
        } else if (_timedOut(s)) {
          _skip(s, InspectionStep.heavyLoad);
        }
      case InspectionStep.heavyLoad:
        _track(s, met: amps >= heavyLoadAmps);
        if (_held(s, th.heavyLoadSeconds)) {
          _advance(s, InspectionStep.recovery);
        } else if (_timedOut(s)) {
          // No hard pull means nothing to recover from. Walking on into the
          // recovery step anyway timed the cells "climbing back" from a load
          // they never had, and the verdict praised a recovery of 0 s.
          _skipHeavy(s);
          return true;
        }
      case InspectionStep.recovery:
        // The recovery clock runs from the moment the load is gone. Load
        // coming back restarts it: a cell cannot be timed climbing while
        // somebody is still pulling on it.
        if (amps < th.restCurrentAmps) {
          _releasedAt ??= s.timestamp;
          _releasedFrames++;
        } else {
          _releasedAt = null;
          _releasedFrames = 0;
        }
        final released = _releasedAt;
        if (released != null &&
            _releasedFrames >= th.minimumStepReadings &&
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
    if (_step == InspectionStep.heavyLoad) {
      _skipHeavy(last);
      return;
    }
    _skip(last, _next(_step));
  }

  /// Ends the test where it is. Whatever was not measured is reported as
  /// such rather than guessed.
  void abortToDone() {
    if (_step == InspectionStep.done) return;
    _endedEarlyIn = _step;
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
      InspectionStep.lightLoad => amps >= lightLoadAmps,
      InspectionStep.heavyLoad => amps >= heavyLoadAmps,
      InspectionStep.recovery => amps < th.restCurrentAmps,
      InspectionStep.done => true,
    };
  }

  void _track(BmsSnapshot s, {required bool met}) {
    if (met) {
      _heldSince ??= s.timestamp;
      _heldFrames++;
    } else {
      _heldSince = null;
      _heldFrames = 0;
    }
  }

  /// Whether the step's condition has been held for [seconds] and over
  /// enough readings to have been seen being held.
  bool _held(BmsSnapshot s, int seconds) {
    final since = _heldSince;
    if (since == null) return false;
    return _heldFrames >= thresholds.minimumStepReadings &&
        s.timestamp.difference(since).inMilliseconds / 1000 >= seconds;
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
    _heldFrames = 0;
    _releasedAt = null;
    _releasedFrames = 0;
  }

  void _skip(BmsSnapshot s, InspectionStep to) {
    _skipped.add(_step);
    _advance(s, to);
  }

  /// The hard pull never happened: the recovery after it cannot happen
  /// either, so both are recorded as not measured and the test ends.
  void _skipHeavy(BmsSnapshot s) {
    _skipped
      ..add(InspectionStep.heavyLoad)
      ..add(InspectionStep.recovery);
    _advance(s, InspectionStep.done);
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
