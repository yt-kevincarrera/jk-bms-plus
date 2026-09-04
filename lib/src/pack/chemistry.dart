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
/// One table, used by the configuration audit and by nothing else that makes
/// claims. The numbers are the conservative end of what cell datasheets and
/// pack builders agree on, because the cost of the two errors is not
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
  );

  static const ChemistryLimits nmc = ChemistryLimits(
    nominalVolts: 3.7,
    hardMaxVolts: 4.25,
    comfortableMaxVolts: 4.20,
    hardMinVolts: 3.00,
    comfortableMinVolts: 3.20,
    typicalBalanceStartVolts: 4.00,
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

  /// Temperature limits are the same for both, because they are about
  /// lithium plating and electrolyte breakdown rather than about the cathode.
  ///
  /// Charging below freezing plates metallic lithium on the anode. It is
  /// permanent, it is invisible on any figure the BMS reports, and it is the
  /// single most common way a winter rider ruins a pack.
  static const double freezingChargeLimitCelsius = 0;

  /// Above this, charging is doing damage.
  static const double hotChargeLimitCelsius = 45;

  /// Above this, even discharging is.
  static const double hotDischargeLimitCelsius = 60;
}
