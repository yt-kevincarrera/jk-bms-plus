import 'dart:math' as math;

import '../../model/bms_warning.dart';

/// What the simulated pack is doing. Pick one in demo mode to see how each
/// screen reacts.
enum DemoScenario {
  /// Stop-and-go riding: current swings with the throttle, voltage sags under
  /// load, SOC drains.
  riding('Riding', 'Throttle swings, sag under load, SOC draining'),

  /// Charging at a steady current, with the delta opening up above 4.0 V/cell
  /// the way it really does.
  charging('Charging', 'Steady charge, delta opening up near the top'),

  /// Parked. Cells relax to their open-circuit voltage.
  idle('Parked', 'No current, cells relaxed'),

  /// One cell dragging badly, balancer working, warnings firing.
  weakCell('Weak cell', 'Cell 7 sagging hard, balancer on, warnings raised'),

  /// A scripted rehearsal of the guided quick test: quiet, then the lights,
  /// then a hard pull, then released. Cell 7 is the weak one, so the verdict
  /// has something to find.
  inspection(
    'Inspection rehearsal',
    'Quiet 35 s, lights 20 s, hard pull 8 s, then released. Cell 7 weak',
  );

  const DemoScenario(this.label, this.description);
  final String label;
  final String description;
}

/// A plausible 72 V 20S Li-ion NMC pack, advanced one tick at a time.
///
/// The numbers here are modelled, not measured: NMC open-circuit voltage from a
/// coarse curve, sag from a per-cell internal resistance, delta widening at the
/// top of charge. They are meant to be realistic enough to lay out and judge a
/// screen against, not to be accurate.
class SimulatedPack {
  SimulatedPack({
    this.cellCount = 20,
    this.nominalCapacityAh = 45,
    DemoScenario scenario = DemoScenario.riding,
    int seed = 20250826,
  }) : _scenario = scenario,
       _random = math.Random(seed) {
    // A spread of internal resistances, with cell 7 the worst of them. Real
    // packs are never uniform, and a screen that only ever sees uniform cells
    // hides exactly the problem this app exists for.
    //
    // The spread is kept mild here so a healthy pack looks healthy: under 30 A
    // it produces a delta in the tens of millivolts, which is what a decent 20S
    // pack actually does. The weakCell scenario is what turns cell 7 into a
    // problem, via _sagGain.
    _resistances = List.generate(cellCount, (i) {
      final base = 0.0022 + _random.nextDouble() * 0.0004;
      return i == _weakCellIndex ? base * 1.3 : base;
    });
    _cellOffsets = List.generate(
      cellCount,
      (i) => (_random.nextDouble() - 0.5) * 0.008,
    );
  }

  static const int _weakCellIndex = 6; // cell 7, 1-based

  final int cellCount;
  final double nominalCapacityAh;
  final math.Random _random;

  late final List<double> _resistances;
  late final List<double> _cellOffsets;

  DemoScenario _scenario;
  DemoScenario get scenario => _scenario;

  set scenario(DemoScenario value) {
    _scenario = value;
    _scenarioTicks = 0;
    _throttle = 0;
  }

  double _soc = 0.78;

  /// How much faster than real time the pack ages.
  ///
  /// A capacity test is a full discharge, which on a real bike is hours. Demo
  /// mode exists to let the screens be judged without hardware, and a feature
  /// that takes an afternoon to reach cannot be judged at all.
  double timeScale = 1.0;
  double _throttle = 0;
  double _packTemp = 24.5;
  double _mosfetTemp = 27.0;
  int _ticks = 0;

  /// Ticks since the scenario was last set, for scripted scenarios.
  int _scenarioTicks = 0;
  int _cycleCount = 63;

  /// Simulated road speed, km/h. Demo mode needs a distance to feed the range
  /// estimator with; the real one will come from the phone's GPS in M3.
  double get speedKmh => _speedKmh;
  double _speedKmh = 0;

  /// Kilometres covered since the simulator started.
  double get distanceKm => _distanceKm;
  double _distanceKm = 0;

  double get soc => _soc * 100;
  double get soh => 97;
  int get cycleCount => _cycleCount;
  double get remainingCapacityAh => nominalCapacityAh * _soc;
  double get cycleCapacityAh => 2843.5;
  int get runtimeSeconds => 4 * 3600 + _ticks;

  /// Amps. Positive means charging, matching the convention the parser
  /// currently assumes.
  ///
  /// That convention is still unverified against the real pack (see
  /// docs/PROTOCOL.md). Demo mode therefore cannot confirm it — if the real BMS
  /// turns out to report the opposite sign, this simulator will need flipping
  /// along with the parser.
  double get current => _current;
  double _current = 0;

  double get packVoltage => cellVoltages.reduce((a, b) => a + b);

  double get mosfetTemp => _mosfetTemp;

  List<double> get temperatures => [_packTemp, _packTemp - 0.7];

  List<double> get cellResistances => List.unmodifiable(_resistances);

  bool get balancerActive =>
      _scenario == DemoScenario.weakCell ||
      (_scenario == DemoScenario.charging && _openCircuitVoltage > 4.02);

  int get balancingAction => balancerActive ? 0x01 : 0x00;

  double get balanceCurrent => balancerActive ? 0.58 : 0.0;

  bool get chargeMosfetOn => true;
  bool get dischargeMosfetOn => _scenario != DemoScenario.charging;
  bool get chargerPlugged => _scenario == DemoScenario.charging;

  int get errorBitmask {
    var mask = 0;
    if (_scenario == DemoScenario.weakCell) {
      mask |= 1 << BmsWarning.wireResistance.bit;
      if (cellVoltages.reduce(math.min) < 3.35) {
        mask |= 1 << BmsWarning.cellUndervoltage.bit;
      }
    }
    if (_scenario == DemoScenario.charging && _soc > 0.985) {
      mask |= 1 << BmsWarning.batteryFullyCharged.bit;
    }
    return mask;
  }

  /// Per-cell terminal voltage: open-circuit voltage, plus the cell's own
  /// offset, minus I x R sag.
  List<double> get cellVoltages {
    final ocv = _openCircuitVoltage;
    final spreadGain = _deltaSpreadGain;
    return [
      for (var i = 0; i < cellCount; i++)
        (ocv +
                _cellOffsets[i] * spreadGain +
                _current * _resistances[i] * _sagGain(i))
            .clamp(2.6, 4.25),
    ];
  }

  /// Cells drift further apart at both ends of the curve, and much further at
  /// the top. That widening is the whole reason the delta-versus-SOC graph is
  /// worth plotting.
  double get _deltaSpreadGain {
    if (_soc > 0.90) return 1.0 + (_soc - 0.90) * 55;
    if (_soc < 0.15) return 1.0 + (0.15 - _soc) * 20;
    return 1.0;
  }

  double _sagGain(int index) {
    if (_scenario != DemoScenario.weakCell &&
        _scenario != DemoScenario.inspection) {
      return 1.0;
    }
    return index == _weakCellIndex ? 3.4 : 1.0;
  }

  /// Coarse NMC open-circuit curve, 4.15 V at full down to 3.05 V at empty.
  /// Unlike LFP this has real slope everywhere, which is why voltage is
  /// informative about SOC on this pack.
  double get _openCircuitVoltage {
    // (state of charge, volts per cell), ascending.
    const curve = <(double, double)>[
      (0.00, 3.05),
      (0.10, 3.45),
      (0.20, 3.58),
      (0.40, 3.71),
      (0.60, 3.84),
      (0.80, 3.99),
      (0.90, 4.07),
      (1.00, 4.15),
    ];
    for (var i = 0; i < curve.length - 1; i++) {
      final (socA, vA) = curve[i];
      final (socB, vB) = curve[i + 1];
      if (_soc >= socA && _soc <= socB) {
        final t = (_soc - socA) / (socB - socA);
        return vA + (vB - vA) * t;
      }
    }
    return _soc < curve.first.$1 ? curve.first.$2 : curve.last.$2;
  }

  /// Puts the pack at a given charge, for reaching a state worth looking at
  /// without waiting for it.
  ///
  /// Demo only, and nothing like it exists for a real pack: this app never
  /// writes to a BMS, and a charge level is not something it could set anyway.
  void setCharge(double fraction) {
    final was = _soc;
    _soc = fraction.clamp(0.03, 1.0);
    // Filling it back up from the floor is a cycle, the same as a real charge
    // would be, so the cycle counter does not stand still through testing.
    if (was <= 0.05 && _soc > 0.9) _cycleCount++;
  }

  /// Advances the model by [dt].
  void tick(Duration dt) {
    _ticks++;
    _scenarioTicks++;
    final seconds = dt.inMilliseconds / 1000.0 * timeScale;

    switch (_scenario) {
      case DemoScenario.inspection:
        // The script the PRD describes, in wall-clock ticks so it lines up
        // with the session's own step timing. After the pull it stays quiet
        // for good: the test ends, the pack sits.
        final t = _scenarioTicks * dt.inMilliseconds / 1000.0;
        _throttle = 0;
        if (t < 35) {
          _current = 0;
        } else if (t < 55) {
          _current = -1.8;
        } else if (t < 63) {
          _current = -38;
          _throttle = 0.55;
        } else {
          _current = 0;
        }
      case DemoScenario.riding:
      case DemoScenario.weakCell:
        // Throttle wanders, with the occasional hard pull. The step changes are
        // deliberate: they are what the internal-resistance estimator will
        // eventually key off.
        if (_random.nextDouble() < 0.10) {
          _throttle = _random.nextDouble();
        } else {
          _throttle += (_random.nextDouble() - 0.5) * 0.18;
        }
        _throttle = _throttle.clamp(0.0, 1.0);
        _current = -(2 + _throttle * 68);
      case DemoScenario.charging:
        // Constant current until the top, then tapering.
        final taper = _soc > 0.90 ? (1.0 - _soc) / 0.10 : 1.0;
        _current = 12.0 * taper.clamp(0.06, 1.0);
      case DemoScenario.idle:
        _current = 0;
        _throttle = 0;
    }

    // Speed roughly tracks throttle, with a lag. Demo mode needs a distance to
    // feed the range estimator with; the real one arrives from GPS in M3.
    final targetSpeed = switch (_scenario) {
      DemoScenario.riding || DemoScenario.weakCell => 12 + _throttle * 58,
      // Wheel in the air on the stand: current without kilometres.
      _ => 0.0,
    };
    _speedKmh += (targetSpeed - _speedKmh) * 0.25;
    _distanceKm += _speedKmh * seconds / 3600.0;

    // Coulomb counting, same integration the app will do for real.
    final ah = _current * seconds / 3600.0;
    _soc = (_soc + ah / nominalCapacityAh).clamp(0.03, 1.0);

    // The pack used to jump back to 35% on reaching full and back to 95% on
    // reaching empty, so it looped forever and never arrived anywhere. That
    // made two things impossible to see: a charge finishing, and a discharge
    // reaching the cutoff -- which is the entire capacity test. Both are now
    // end states, which is also what a real pack does.
    if (_scenario == DemoScenario.charging && _soc >= 0.999) {
      _soc = 1.0;
      _current = 0.05;
    }
    if (_scenario != DemoScenario.charging && _soc <= 0.03) {
      // The BMS opening the discharge MOSFET. Nothing more comes out until it
      // is charged, which is exactly the end the capacity test waits for.
      _soc = 0.03;
      _current = 0;
      _throttle = 0;
      _speedKmh = 0;
    }

    // Temperature follows current with a long lag, and bleeds off to ambient.
    final heating = (_current.abs() / 70).clamp(0.0, 1.0) * 0.05;
    _packTemp += heating * seconds - (_packTemp - 24.0) * 0.004 * seconds;
    _mosfetTemp +=
        heating * 1.7 * seconds - (_mosfetTemp - 25.0) * 0.006 * seconds;
  }
}
