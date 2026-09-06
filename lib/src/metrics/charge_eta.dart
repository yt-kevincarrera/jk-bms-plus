/// How long until the pack is full.
class ChargeEta {
  const ChargeEta({
    required this.remaining,
    required this.isTapering,
    this.socLooksOptimistic = false,
  });

  /// Time left, or null when it cannot honestly be worked out.
  final Duration? remaining;

  /// Whether the pack is in the constant-voltage tail, where the current falls
  /// away and the last few percent take far longer than the arithmetic
  /// suggests.
  final bool isTapering;

  /// The BMS's charge counter claims the pack is nearly full while something
  /// measured says it is not.
  ///
  /// When this is set [remaining] is null on purpose. The counter is the only
  /// input a time-to-full has, so once it is known to be wrong there is no
  /// number left to give — and "3 min" on a charge with an hour to run is
  /// worse than saying nothing, because the rider plans around it once and
  /// stops believing the screen afterwards.
  final bool socLooksOptimistic;

  static const ChargeEta unknown = ChargeEta(
    remaining: null,
    isTapering: false,
  );
}

/// Estimates time to full from what is charging into the pack right now.
///
/// The naive version, amp-hours left over amps going in, is right for most of
/// a charge and badly wrong at the end. Above roughly 90% a lithium charger
/// stops holding current and starts holding voltage, the current tails off
/// towards nothing, and the remaining time stretches: a pack that says twelve
/// minutes at 92% can genuinely take forty.
///
/// So the taper is modelled rather than ignored, and the result is flagged as
/// an estimate in the tail so the number is not read as a promise.
///
/// The state of charge this all hangs off is not a measurement. The BMS
/// integrates amps over time against the capacity somebody typed into it, so
/// it drifts: a counter working from a stale zero, or against a nominal
/// capacity smaller than the pack really holds, reaches 99% while the cells
/// are still a long way down. It then sits there until the pack finally
/// reaches the cutoff. Dividing by that number produces the app's worst kind
/// of answer — confident, precise, and wrong by an order of magnitude — so
/// before the arithmetic runs, the claim is checked against something nobody
/// typed in.
class ChargeEtaEstimator {
  const ChargeEtaEstimator({
    this.taperStartsAt = 0.90,
    this.minimumCurrent = 0.5,
    this.fullAt = 0.995,
    this.checkedAbove = 0.95,
    this.checkedAboveOnCurrentAlone = 0.97,
    this.disagreementVolts = 0.12,
    this.taperCurrentCRate = 0.10,
  });

  /// Charge fraction at which the charger stops giving full current.
  final double taperStartsAt;

  /// Below this many amps in, nothing useful can be said: the pack is either
  /// finished or not really charging.
  final double minimumCurrent;

  /// Where "full" is called.
  final double fullAt;

  /// Charge fraction above which a near-full reading stops being taken at
  /// face value and gets checked against something measured.
  final double checkedAbove;

  /// The same bar for the current-only fallback, set higher because it is the
  /// weaker test. A flat-curve chemistry can genuinely still be taking most
  /// of its charge current well into the nineties, so the fallback only calls
  /// a reading wrong once even that stops being plausible.
  final double checkedAboveOnCurrentAlone;

  /// How far the highest cell may sit below the configured per-cell cutoff
  /// while the counter claims nearly full.
  ///
  /// Not tight, deliberately. The cutoff read back here is the BMS's
  /// protection threshold, and pack builders normally leave it a little above
  /// where the charger actually stops, so a genuinely full pack can rest a
  /// few tens of millivolts short of it. Past this, though, no amount of
  /// headroom explains the gap: it is most of a volt across the pack.
  final double disagreementVolts;

  /// Fraction of C still going in that makes a near-full reading impossible
  /// to believe, when there is nothing configured to compare voltages
  /// against.
  ///
  /// Past the knee the charger holds voltage and the current decays away;
  /// chargers call a charge finished somewhere around a twentieth of C. A
  /// pack still swallowing a tenth of C is in constant current, and a pack in
  /// constant current is not at 99%.
  final double taperCurrentCRate;

  /// [current] is positive charging, in the app's convention.
  ///
  /// [highestCellVolts] and [cellFullVolts] — the per-cell charge cutoff the
  /// BMS is configured with — are what the counter gets checked against.
  /// Without them the check falls back to the current alone.
  ChargeEta estimate({
    required double current,
    required double soc,
    required double capacityAh,
    double? highestCellVolts,
    double? cellFullVolts,
  }) {
    if (current < minimumCurrent || capacityAh <= 0) return ChargeEta.unknown;

    final fraction = (soc / 100).clamp(0.0, 1.0);

    if (fraction >= checkedAbove &&
        _counterContradicted(
          fraction: fraction,
          current: current,
          capacityAh: capacityAh,
          highestCellVolts: highestCellVolts,
          cellFullVolts: cellFullVolts,
        )) {
      return const ChargeEta(
        remaining: null,
        isTapering: true,
        socLooksOptimistic: true,
      );
    }

    if (fraction >= fullAt) {
      return const ChargeEta(remaining: Duration.zero, isTapering: true);
    }

    // The flat part: amp-hours still to put in at the current rate.
    final toTaper = ((taperStartsAt - fraction).clamp(0.0, 1.0)) * capacityAh;
    final flatHours = toTaper / current;

    // The tail. Current falls roughly linearly to nothing across it, so the
    // average rate over that stretch is about half of what is flowing now,
    // which doubles the time the naive arithmetic would give.
    final inTaper = fraction > taperStartsAt;
    final taperAh =
        ((fullAt - (inTaper ? fraction : taperStartsAt)).clamp(0.0, 1.0)) *
        capacityAh;
    // In the tail the current already reflects the taper, so it is halved
    // relative to now rather than to the bulk rate.
    final averageTaperCurrent = (inTaper ? current : current) * 0.5;
    final taperHours = averageTaperCurrent <= 0
        ? 0.0
        : taperAh / averageTaperCurrent;

    final hours = flatHours + taperHours;
    if (!hours.isFinite || hours < 0) return ChargeEta.unknown;

    return ChargeEta(
      remaining: Duration(seconds: (hours * 3600).round()),
      isTapering: inTaper,
    );
  }

  /// Whether something measured disagrees with a near-full charge counter.
  bool _counterContradicted({
    required double fraction,
    required double current,
    required double capacityAh,
    required double? highestCellVolts,
    required double? cellFullVolts,
  }) {
    // A charge ends when the highest cell reaches the cutoff, so where that
    // cell sits settles the question in both directions. When it is known,
    // nothing else gets a vote: a cell at the cutoff is genuinely at the end
    // of a charge whatever the current is doing, and a cell well below it is
    // genuinely not.
    if (highestCellVolts != null && cellFullVolts != null && cellFullVolts > 0) {
      return cellFullVolts - highestCellVolts > disagreementVolts;
    }

    // Nothing configured to compare against — an unread settings frame, or a
    // pack whose cutoff the BMS never reported. The current is left, and it
    // needs no configuration to be believed because it is measured.
    return fraction >= checkedAboveOnCurrentAlone &&
        current > taperCurrentCRate * capacityAh;
  }
}
