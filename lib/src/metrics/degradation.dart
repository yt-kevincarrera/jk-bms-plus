import '../data/database.dart';

/// Where a capacity figure came from, because it changes what it is worth.
enum CapacitySource {
  /// A full discharge counted amp-hour by amp-hour. The only real measurement
  /// this app makes.
  measured,

  /// What the BMS is configured to hold.
  ///
  /// Not a measurement of anything and it never was. This used to be derived
  /// as remaining amp-hours over the charge the BMS reports, described as
  /// "arithmetic on what the BMS says about itself", which was too generous:
  /// the BMS computes remaining amp-hours *as* charge times configured
  /// capacity, so dividing one by the other returns the configured capacity
  /// and nothing else. Checked against a real pack at every charge level from
  /// 53% to 70%: 40.0 Ah every time, varying only by the rounding of a
  /// whole-number percentage.
  ///
  /// Which means health built on it read 40 over 40, or 100%, and would have
  /// read 100% on a ruined pack just as cheerfully.
  configured,
}

/// One capacity figure with its provenance and date.
class CapacityPointOfRecord {
  const CapacityPointOfRecord({
    required this.ah,
    required this.at,
    required this.source,
  });

  final double ah;
  final DateTime at;
  final CapacitySource source;
}

/// What a pack can actually be said to have lost.
///
/// This replaces measuring health against what the pack was advertised as,
/// which conflated two unrelated questions and answered neither well:
///
/// 1. **Has this battery degraded?** That is wear, and it can only be measured
///    against what this battery really held when it was new. Measuring it
///    against a marketing figure reports a pack sold as 45 Ah that was always
///    40 as permanently 89% healthy, on day one, before it has lost anything
///    at all. The number never described wear and never would.
///
/// 2. **Did I get what I paid for?** That is a fact about a purchase, decided
///    once, and it does not change as the pack ages. It belongs in a sentence,
///    not in a health gauge that is supposed to move.
///
/// So degradation is measured against the best this pack has ever actually
/// managed, and the advertised figure is kept only to answer the second
/// question, plainly, once.
class Degradation {
  const Degradation({
    required this.current,
    this.baseline,
    this.advertisedAh,
    this.configuredAh,
    this.observations = 0,
  });

  /// What the pack holds now.
  final CapacityPointOfRecord? current;

  /// The best it has ever held, which is the honest baseline for wear.
  ///
  /// Not what it was sold as, and not what the BMS is configured for. Both of
  /// those are claims; this is the high-water mark of what was observed.
  final CapacityPointOfRecord? baseline;

  /// What the seller said, when the rider has said so.
  final double? advertisedAh;

  /// What the BMS is configured to hold. A setting, not a measurement.
  final double? configuredAh;

  /// How many capacity figures the picture is built from.
  ///
  /// The gate on reporting any degradation at all. One observation is a
  /// capacity, not a decline; two or more can honestly report no loss, which
  /// is different from being unable to tell.
  final int observations;

  /// How much of the original capacity is gone, as a fraction.
  ///
  /// Null unless there is a baseline and a current figure that are genuinely
  /// different observations. One measurement is a capacity, not a
  /// degradation: with a single point there is nothing to have declined from,
  /// and reporting 0% would be a claim that the pack is provably as good as
  /// new.
  double? get lostFraction {
    final now = current;
    final was = baseline;
    if (now == null || was == null || was.ah <= 0) return null;
    // Two observations can report no loss. One cannot report anything.
    if (observations < 2) return null;
    final lost = 1 - now.ah / was.ah;
    // Capacity measurements wobble by a few percent, and a pack reading
    // slightly above its old best has not gained capacity.
    return lost <= 0 ? 0 : lost;
  }

  /// Whether the baseline is a real measurement rather than arithmetic.
  bool get baselineIsMeasured => baseline?.source == CapacitySource.measured;

  /// How far short of the advert the pack came, as a fraction.
  ///
  /// A fact about the purchase, not about wear. Uses the best the pack ever
  /// managed, because that is the fairest reading of what was delivered: what
  /// it holds today includes any ageing since, which the seller is not
  /// responsible for.
  double? get shortOfAdvertisedFraction {
    final advertised = advertisedAh;
    final was = baseline;
    if (advertised == null || advertised <= 0 || was == null) return null;
    final short = 1 - was.ah / advertised;
    return short <= 0 ? 0 : short;
  }

  /// Builds the picture from completed capacity tests, and nothing else.
  ///
  /// [readings] is still taken so callers need not change, and is used only to
  /// report what the BMS is configured for. It is deliberately not a source of
  /// capacity figures any more: see [CapacitySource.configured].
  static Degradation from({
    required List<CapacityTest> tests,
    required List<Snapshot> readings,
    double? advertisedAh,
  }) {
    final measured = [
      for (final t in tests)
        if (t.completed && t.measuredAh > 0)
          CapacityPointOfRecord(
            ah: t.measuredAh,
            at: t.endedAt ?? t.startedAt,
            source: CapacitySource.measured,
          ),
    ]..sort((a, b) => a.at.compareTo(b.at));

    if (measured.length >= 2) {
      final best = measured.reduce((a, b) => a.ah >= b.ah ? a : b);
      return Degradation(
        current: measured.last,
        baseline: best,
        advertisedAh: advertisedAh,
        observations: measured.length,
      );
    }

    // Fewer than two measurements, and there is no substitute. There used to
    // be one and it was a tautology, so the honest answer is a single point or
    // nothing at all.
    return Degradation(
      current: measured.isEmpty ? null : measured.single,
      baseline: measured.isEmpty ? null : measured.single,
      advertisedAh: advertisedAh,
      configuredAh: _configuredCapacity(readings),
      observations: measured.length,
    );
  }

  /// What the BMS is set to hold, read back off its own coulomb counter.
  ///
  /// Reported so the screen can show it plainly, labelled as a setting. It is
  /// worth showing: it is the number every percentage the BMS reports is
  /// scaled against, and if it disagrees with what the pack was sold as, that
  /// disagreement is worth seeing. It is not worth calling health.
  static double? _configuredCapacity(List<Snapshot> readings) {
    for (final r in readings.reversed) {
      final fraction = r.soc / 100.0;
      if (fraction < 0.25 || fraction > 0.9) continue;
      if (r.remainingAh <= 0) continue;
      return r.remainingAh / fraction;
    }
    return null;
  }
}
