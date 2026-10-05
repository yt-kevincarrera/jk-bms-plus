import 'dart:math' as math;

/// What the cells in a pack are made of.
///
/// The app asks rather than guesses, because every safe range in the
/// configuration audit hangs off this one answer and the two chemistries
/// disagree by a volt per cell. A pack told it is LFP and charged to 4.2 V a
/// cell is a fire; the same setting on NMC is normal. Unknown is a real
/// answer and stays available: an audit that cannot say which chemistry it is
/// looking at should say less, not guess.
enum CellChemistry {
  unknown,

  /// Lithium iron phosphate. Flat curve around 3.2 V, full at about 3.55.
  lfp,

  /// The nickel-manganese-cobalt family, and near enough anything else
  /// selling as "lithium ion" at 3.7 V nominal, full at 4.2.
  nmc;

  bool get isKnown => this != CellChemistry.unknown;

  /// Stored by name, so reordering this enum cannot rewrite history.
  static CellChemistry byName(String? name) => switch (name) {
    'lfp' => CellChemistry.lfp,
    'nmc' => CellChemistry.nmc,
    _ => CellChemistry.unknown,
  };
}

/// Where a suggested chemistry came from.
///
/// Shown next to the suggestion, because a guess a rider cannot check is
/// worse than no guess: they are the one who knows what they bought.
enum ChemistryEvidence {
  /// Nothing to go on.
  none,

  /// The BMS's own per-cell overvoltage setting. Whoever built the pack set
  /// it, and it is the single most telling number: nobody configures 3.6 V
  /// on NMC or 4.2 V on LFP by accident.
  overvoltageSetting,

  /// The highest cell voltage actually seen. Weaker, because a half-charged
  /// NMC cell and a full LFP cell read almost the same, but it settles the
  /// question in one direction: nothing above 3.8 V is LFP.
  observedCellVoltage,
}

/// A suggestion, with the reason attached.
class ChemistryHint {
  const ChemistryHint(this.chemistry, this.evidence, {this.value});

  static const ChemistryHint none = ChemistryHint(
    CellChemistry.unknown,
    ChemistryEvidence.none,
  );

  final CellChemistry chemistry;
  final ChemistryEvidence evidence;

  /// The figure the suggestion rests on, in volts per cell.
  final double? value;

  bool get hasSuggestion => chemistry.isKnown;

  /// Reads the chemistry off what the pack says about itself.
  ///
  /// Deliberately conservative: between 3.8 and 4.0 V of configured
  /// overvoltage sits nothing anybody sells, so a reading in the middle
  /// returns no suggestion rather than a coin toss.
  static ChemistryHint from({double? cellOvp, double? highestCellVolts}) {
    if (cellOvp != null && cellOvp > 0) {
      if (cellOvp <= 3.80) {
        return ChemistryHint(
          CellChemistry.lfp,
          ChemistryEvidence.overvoltageSetting,
          value: cellOvp,
        );
      }
      if (cellOvp >= 4.00) {
        return ChemistryHint(
          CellChemistry.nmc,
          ChemistryEvidence.overvoltageSetting,
          value: cellOvp,
        );
      }
    }
    // A cell that has been above 3.8 V is not LFP, whatever anything else
    // says. The other direction proves nothing: a discharged NMC cell sits
    // right where a full LFP one does.
    if (highestCellVolts != null && highestCellVolts >= 3.80) {
      return ChemistryHint(
        CellChemistry.nmc,
        ChemistryEvidence.observedCellVoltage,
        value: highestCellVolts,
      );
    }
    return none;
  }
}

/// The voltages and temperatures a chemistry is happy inside.
///
/// One table, used by the configuration audit, and by the cell cutoff warning
/// only when the BMS has not stated its own cutoff. The numbers are the
/// conservative end of what cell datasheets and pack builders agree on,
/// because the cost of the two errors is not
/// symmetric: calling a safe setting risky wastes a minute of the rider's
/// time, and calling a risky setting safe is how a pack ends up alight.
class ChemistryLimits {
  const ChemistryLimits({
    required this.nominalVolts,
    required this.hardMaxVolts,
    required this.comfortableMaxVolts,
    required this.hardMinVolts,
    required this.comfortableMinVolts,
    required this.typicalBalanceStartVolts,
    required this.typicalCutoffVolts,
    required this.fullChargeVolts,
  });

  /// Nothing is known, so the audit says nothing about voltages.
  static const ChemistryLimits? unknown = null;

  static const ChemistryLimits lfp = ChemistryLimits(
    nominalVolts: 3.2,
    // Above this the cell is being damaged on every charge. LFP is full at
    // 3.55 and gains almost nothing between there and 3.65.
    hardMaxVolts: 3.65,
    comfortableMaxVolts: 3.55,
    hardMinVolts: 2.50,
    comfortableMinVolts: 2.80,
    typicalBalanceStartVolts: 3.40,
    typicalCutoffVolts: 2.80,
    fullChargeVolts: 3.45,
  );

  static const ChemistryLimits nmc = ChemistryLimits(
    nominalVolts: 3.7,
    hardMaxVolts: 4.25,
    comfortableMaxVolts: 4.20,
    hardMinVolts: 3.00,
    comfortableMinVolts: 3.20,
    typicalBalanceStartVolts: 4.00,
    typicalCutoffVolts: 3.00,
    fullChargeVolts: 4.15,
  );

  static ChemistryLimits? of(CellChemistry chemistry) => switch (chemistry) {
    CellChemistry.lfp => lfp,
    CellChemistry.nmc => nmc,
    CellChemistry.unknown => unknown,
  };

  final double nominalVolts;

  /// Past this, every charge costs cycle life and the risk stops being
  /// theoretical.
  final double hardMaxVolts;

  /// Past this, the pack ages faster for almost no extra range.
  final double comfortableMaxVolts;

  final double hardMinVolts;
  final double comfortableMinVolts;
  final double typicalBalanceStartVolts;

  /// Where a BMS set up for this chemistry usually cuts a cell off, for when
  /// the BMS has not said where it does (an ANT never does; a JK until its
  /// settings frame arrives). The cautious end of what pack builders set:
  /// an LFP pack cut at 2.5 V would be warned about at 2.6, deep in the
  /// cliff, so 2.8 is used. Always shown as assumed, never as the BMS's.
  final double typicalCutoffVolts;

  /// The same, when the chemistry is not known either: the NMC figure, the
  /// higher of the two, so on a pack of unknown chemistry the warning errs
  /// early (if it is LFP) rather than late (if it is NMC).
  static const double unknownCutoffVolts = 3.0;

  /// The highest cell at or above which a charge has reached the top, while
  /// the charger is still tapering or has just let go.
  ///
  /// A little under where a charger for this chemistry stops, so one that
  /// ends a few millivolts short still counts, and well above anything a
  /// half-charged cell reads. This is what the capacity test opens on and
  /// what "charge finished" waits for, instead of the BMS's percentage: the
  /// percentage is remaining amp-hours over the configured capacity, so a
  /// test that started and stopped on it could only ever hand back the
  /// configured capacity it was scaled against.
  final double fullChargeVolts;

  /// [fullChargeVolts] for this pack, allowing for how its BMS asks to be
  /// charged.
  ///
  /// A pack whose BMS requests charge to 4.10 V a cell is full at 4.10 and
  /// would never reach 4.15. So a configured request voltage can lower the
  /// mark to 30 mV under itself, but only by up to 0.10 V: a request set far
  /// below the chemistry's top is a typo or a storage setting, and taking it
  /// at its word would call a half-charged pack full. It never raises it.
  /// With the chemistry unknown the request alone decides, when it is a
  /// plausible lithium figure; with neither there is no mark, and callers
  /// say less rather than guess one.
  static double? fullCellVoltsFor(
    CellChemistry chemistry, {
    double? requestChargeVolts,
  }) {
    final base = of(chemistry)?.fullChargeVolts;
    final request = requestChargeVolts;
    final fromSetting = request == null || request <= 0 ? null : request - 0.03;
    if (base == null) {
      return fromSetting != null && fromSetting >= 3.3 && fromSetting <= 4.35
          ? fromSetting
          : null;
    }
    if (fromSetting != null &&
        fromSetting < base &&
        fromSetting >= base - 0.10) {
      return fromSetting;
    }
    return base;
  }

  /// Temperature limits are the same for both, because they are about
  /// lithium plating and electrolyte breakdown rather than about the cathode.
  ///
  /// Charging below freezing plates metallic lithium on the anode. It is
  /// permanent, it is invisible on any figure the BMS reports, and it is the
  /// single most common way a winter rider ruins a pack.
  static const double freezingChargeLimitCelsius = 0;

  /// The cold cutoff the audit asks for: a margin above freezing, because
  /// the probe reads the outside of the pack and the cells inside it lag
  /// behind. A cutoff between the two stops above zero, but only just.
  static const double comfortableChargeMinCelsius = 2;

  /// Above this, charging is doing damage.
  static const double hotChargeLimitCelsius = 45;

  /// Above this, even discharging is.
  static const double hotDischargeLimitCelsius = 60;
}

/// Resting cell voltage against state of charge, for turning amp-hours into
/// watt-hours and cell voltages into charge.
///
/// Typical curves for the chemistry, read off published datasheets and the
/// usual pack-builder tables, not measured on any particular pack. Good to a
/// few percent in energy, which is the job: the figure these replace took
/// the pack voltage of the moment as the voltage of the whole remaining
/// discharge. On a full 20S NMC pack that is about 83 V against a real mean
/// near 75, so every "Wh remaining" read some 12% high at the top, higher
/// still with a charger pushing the cells up, and jumped with every twist of
/// the throttle as the voltage sagged.
///
/// Eleven points, one every ten percent, interpolated linearly. The curve's
/// 0% is the chemistry's usual cutoff.
class OcvCurve {
  const OcvCurve._(this.volts);

  /// Volts per cell at 0, 10, ... 100 % charge.
  final List<double> volts;

  static const OcvCurve nmc = OcvCurve._([
    3.00, 3.45, 3.55, 3.62, 3.68, 3.73, 3.80, 3.88, 3.96, 4.06, 4.18, //
  ]);

  /// Flat between about 20 and 90 %, with a knee at each end. On the flat
  /// part a resting voltage says almost nothing about charge; see [resolves].
  static const OcvCurve lfp = OcvCurve._([
    2.80, 3.15, 3.22, 3.25, 3.27, 3.28, 3.29, 3.30, 3.31, 3.33, 3.45, //
  ]);

  /// Null for an unknown chemistry: the two curves differ by half a volt, and
  /// picking one would be a guess dressed as a figure.
  static OcvCurve? of(CellChemistry chemistry) => switch (chemistry) {
    CellChemistry.nmc => nmc,
    CellChemistry.lfp => lfp,
    CellChemistry.unknown => null,
  };

  static const double _step = 10;

  /// Resting volts per cell at [soc] percent.
  double voltsAt(double soc) {
    final s = soc.clamp(0.0, 100.0);
    final i = (s / _step).floor().clamp(0, volts.length - 2);
    final f = (s - i * _step) / _step;
    return volts[i] + (volts[i + 1] - volts[i]) * f;
  }

  /// Charge in percent that a resting cell at [cellVolts] sits at.
  double socAt(double cellVolts) {
    if (cellVolts <= volts.first) return 0;
    if (cellVolts >= volts.last) return 100;
    for (var i = 0; i < volts.length - 1; i++) {
      final lo = volts[i];
      final hi = volts[i + 1];
      if (cellVolts <= hi) {
        return (i + (cellVolts - lo) / (hi - lo)) * _step;
      }
    }
    return 100;
  }

  /// Millivolts per percent of charge around [soc].
  double slopeAt(double soc) {
    final s = soc.clamp(0.0, 100.0);
    final i = (s / _step).floor().clamp(0, volts.length - 2);
    return (volts[i + 1] - volts[i]) / _step * 1000;
  }

  /// Below this slope, a few millivolts of measurement is ten points of
  /// charge, and a voltage cannot be turned into a charge level honestly.
  static const double minResolvableSlopeMvPerPercent = 2.0;

  /// Whether a resting voltage at [cellVolts] says where the cell is.
  bool resolves(double cellVolts) =>
      slopeAt(socAt(cellVolts)) >= minResolvableSlopeMvPerPercent;

  /// Area under the curve from 0 to [soc], in volt-percent: energy per
  /// amp-hour-percent, the quantity whose ratio is an energy ratio.
  double areaTo(double soc) {
    final s = soc.clamp(0.0, 100.0);
    var area = 0.0;
    var at = 0.0;
    while (at < s) {
      final next = math.min(s, (at / _step).floor() * _step + _step);
      area += (voltsAt(at) + voltsAt(next)) / 2 * (next - at);
      at = next;
    }
    return area;
  }

  /// Mean resting volts per cell over a discharge from [soc] down to empty.
  ///
  /// The voltage an amp-hour is actually delivered at, on average, from here
  /// to the bottom: what turns remaining amp-hours into remaining
  /// watt-hours. At [soc] 0 it is the cutoff itself.
  double meanVoltsBelow(double soc) {
    final s = soc.clamp(0.0, 100.0);
    if (s <= 0) return volts.first;
    return areaTo(s) / s;
  }
}
